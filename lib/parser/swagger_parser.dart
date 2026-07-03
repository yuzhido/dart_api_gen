/// Swagger/OpenAPI JSON 解析器
library;

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class SwaggerParser {
  Map<String, dynamic> _doc = {};

  /// 所有 schemas (components/schemas)
  Map<String, Map<String, dynamic>> get schemas => (_doc['components']?['schemas'] as Map<String, dynamic>?)?.cast<String, Map<String, dynamic>>() ?? {};

  /// 所有 paths
  Map<String, dynamic> get paths => (_doc['paths'] as Map<String, dynamic>?) ?? {};

  /// 获取 tags 列表中的 name → description 映射
  Map<String, String> get tagDescriptions {
    final result = <String, String>{};
    final tags = _doc['tags'] as List<dynamic>?;
    if (tags == null) return result;
    for (final tag in tags) {
      final t = tag as Map<String, dynamic>;
      final name = t['name'] as String?;
      final desc = t['description'] as String?;
      if (name != null && desc != null) {
        result[name] = desc;
      }
    }
    return result;
  }

  /// 获取原始文档数据
  Map<String, dynamic> get rawDoc => _doc;

  /// 从 URL 加载 Swagger JSON
  Future<void> loadFromUrl(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load Swagger JSON from $url: ${response.statusCode}');
    }
    _doc = json.decode(response.body) as Map<String, dynamic>;
  }

  /// 从文件加载 Swagger JSON
  Future<void> loadFromFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('File not found: $filePath');
    }
    final content = file.readAsStringSync();
    _doc = json.decode(content) as Map<String, dynamic>;
  }

  /// 分类所有 schemas: enum vs object
  Map<String, SchemaInfo> classifySchemas() {
    final result = <String, SchemaInfo>{};
    for (final entry in schemas.entries) {
      final name = entry.key;
      final schema = entry.value;
      result[name] = SchemaInfo(name: name, schema: schema, isEnum: isEnumSchema(schema));
    }
    return result;
  }

  /// 按 tag 分组 endpoints
  Map<String, List<EndpointInfo>> groupEndpointsByTag() {
    final result = <String, List<EndpointInfo>>{};

    for (final pathEntry in paths.entries) {
      final path = pathEntry.key;
      final pathItem = pathEntry.value as Map<String, dynamic>;

      for (final method in ['get', 'post', 'put', 'delete', 'patch']) {
        if (!pathItem.containsKey(method)) continue;
        final operation = pathItem[method] as Map<String, dynamic>;
        final tags = (operation['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        final tag = tags.isNotEmpty ? tags.first : 'default';

        final endpoint = EndpointInfo(path: path, method: method, operation: operation, tags: tags);

        result.putIfAbsent(tag, () => []).add(endpoint);
      }
    }

    return result;
  }

  /// 获取 tag → area (x-area) 映射
  Map<String, String> getTagAreaMap() {
    final result = <String, String>{};

    for (final pathEntry in paths.entries) {
      final pathItem = pathEntry.value as Map<String, dynamic>;

      for (final method in ['get', 'post', 'put', 'delete', 'patch']) {
        if (!pathItem.containsKey(method)) continue;
        final operation = pathItem[method] as Map<String, dynamic>;
        final tags = (operation['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        final area = operation['x-area'] as String? ?? 'common';

        for (final tag in tags) {
          result.putIfAbsent(tag, () => area);
        }
      }
    }

    return result;
  }

  /// 获取 tag → 该 tag 引用的 schema 名称集合
  Map<String, Set<String>> getTagSchemaMap() {
    final result = <String, Set<String>>{};

    for (final pathEntry in paths.entries) {
      final pathItem = pathEntry.value as Map<String, dynamic>;

      for (final method in ['get', 'post', 'put', 'delete', 'patch']) {
        if (!pathItem.containsKey(method)) continue;
        final operation = pathItem[method] as Map<String, dynamic>;
        final tags = (operation['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        final tag = tags.isNotEmpty ? tags.first : 'default';

        // 收集该 endpoint 引用的所有 schemas
        final refs = <String>{};
        _collectSchemaRefs(operation, refs);

        result.putIfAbsent(tag, () => {}).addAll(refs);
      }
    }

    return result;
  }

  /// 递归收集 schema 中所有 $ref 引用
  void _collectSchemaRefs(dynamic node, Set<String> refs) {
    if (node is Map<String, dynamic>) {
      final ref = node['\$ref'] as String?;
      if (ref != null) {
        final schemaName = ref.split('/').last;
        if (!refs.contains(schemaName)) {
          refs.add(schemaName);
          // 递归收集被引用 schema 的内部引用
          final schema = schemas[schemaName];
          if (schema != null) {
            _collectSchemaRefs(schema, refs);
          }
        }
      }
      for (final value in node.values) {
        _collectSchemaRefs(value, refs);
      }
    } else if (node is List) {
      for (final item in node) {
        _collectSchemaRefs(item, refs);
      }
    }
  }

  /// 判断 schema 是否为枚举类型
  bool isEnumSchema(Map<String, dynamic> schema) {
    return schema.containsKey('enum') && schema['enum'] is List;
  }

  /// 从 schema 中提取 $ref
  String? extractRef(Map<String, dynamic> schema) {
    final ref = schema['\$ref'] as String?;
    if (ref == null) return null;
    return ref.split('/').last;
  }

  /// 递归为 $ref 字段补充 description（从被引用 schema 复制）
  /// 对齐 TS 版本 enrichRefDescriptions 逻辑
  void enrichRefDescriptions() {
    for (final schema in schemas.values) {
      _enrichNode(schema, schemas);
    }
  }

  /// 递归处理单个节点
  void _enrichNode(dynamic node, Map<String, Map<String, dynamic>> allSchemas) {
    if (node is! Map<String, dynamic>) return;

    // 处理 properties
    final properties = node['properties'] as Map<String, dynamic>?;
    if (properties != null) {
      for (final entry in properties.entries) {
        final prop = entry.value;
        if (prop is! Map<String, dynamic>) continue;

        // 如果字段有 $ref，补充 description
        if (prop.containsKey('\$ref')) {
          final refName = prop['\$ref'].toString().split('/').last;
          final refSchema = allSchemas[refName];
          if (refSchema != null) {
            // 补充描述（如果字段本身没有）
            if (!prop.containsKey('description') && refSchema.containsKey('description')) {
              prop['description'] = refSchema['description'];
            }
            // 标记枚举/接口类型
            if (refSchema.containsKey('enum')) {
              prop['_isEnum'] = true;
            } else {
              prop['_isEnum'] = false;
            }
          }
        }

        // 递归处理嵌套 properties
        if (prop.containsKey('properties')) {
          _enrichNode(prop, allSchemas);
        }

        // 处理数组 items
        if (prop.containsKey('items')) {
          final items = prop['items'];
          if (items is Map<String, dynamic>) {
            if (items.containsKey('\$ref')) {
              final refName = items['\$ref'].toString().split('/').last;
              final refSchema = allSchemas[refName];
              if (refSchema != null) {
                if (refSchema.containsKey('enum')) {
                  items['_isEnum'] = true;
                } else {
                  items['_isEnum'] = false;
                }
              }
            }
            _enrichNode(items, allSchemas);
          }
        }
      }
    }

    // 处理顶层 items（数组类型）
    if (node.containsKey('items')) {
      final items = node['items'];
      if (items is Map<String, dynamic>) {
        if (items.containsKey('\$ref')) {
          final refName = items['\$ref'].toString().split('/').last;
          final refSchema = allSchemas[refName];
          if (refSchema != null) {
            if (refSchema.containsKey('enum')) {
              items['_isEnum'] = true;
            } else {
              items['_isEnum'] = false;
            }
          }
        }
        _enrichNode(items, allSchemas);
      }
    }

    // 处理 allOf / anyOf / oneOf
    for (final key in ['allOf', 'anyOf', 'oneOf']) {
      final combo = node[key];
      if (combo is List) {
        for (final item in combo) {
          _enrichNode(item, allSchemas);
        }
      }
    }
  }
}

/// Schema 信息
class SchemaInfo {
  final String name;
  final Map<String, dynamic> schema;
  final bool isEnum;

  SchemaInfo({required this.name, required this.schema, required this.isEnum});
}

/// Endpoint 信息
class EndpointInfo {
  final String path;
  final String method;
  final Map<String, dynamic> operation;
  final List<String> tags;

  EndpointInfo({required this.path, required this.method, required this.operation, required this.tags});

  String get summary => operation['summary'] as String? ?? '';
  String get operationId => operation['operationId'] as String? ?? '';

  /// 请求参数列表 (仅 query 参数)
  List<ParamInfo> get params {
    final parameters = operation['parameters'] as List<dynamic>?;
    if (parameters == null) return [];
    return parameters
        .where((p) {
          final param = p as Map<String, dynamic>;
          return param['in'] == 'query';
        })
        .map((p) {
          final param = p as Map<String, dynamic>;
          return ParamInfo(
            name: param['name'] as String,
            in_: param['in'] as String,
            description: param['description'] as String? ?? '',
            required: param['required'] as bool? ?? false,
            schema: (param['schema'] as Map<String, dynamic>?) ?? {},
          );
        })
        .toList();
  }

  /// 请求体
  RequestBodyInfo? get requestBody {
    final rb = operation['requestBody'] as Map<String, dynamic>?;
    if (rb == null) return null;

    final content = rb['content'] as Map<String, dynamic>?;
    if (content == null) return null;

    // 检查是否为 form-data
    final isFormData = content.containsKey('multipart/form-data');
    Map<String, dynamic>? schema;

    if (isFormData) {
      final formData = content['multipart/form-data'] as Map<String, dynamic>?;
      schema = formData?['schema'] as Map<String, dynamic>?;
    } else {
      // application/json 或其他
      for (final entry in content.entries) {
        final mediaType = entry.value as Map<String, dynamic>;
        schema = mediaType['schema'] as Map<String, dynamic>?;
        if (schema != null) break;
      }
    }

    if (schema == null) return null;

    // 检查是否为数组
    final isArray = schema['type'] == 'array';
    Map<String, dynamic>? arrayItems;
    if (isArray) {
      arrayItems = schema['items'] as Map<String, dynamic>?;
    }

    // 检查是否为 $ref
    final ref = schema['\$ref'] as String?;

    return RequestBodyInfo(schema: schema, isFormData: isFormData, isArray: isArray, arrayItems: arrayItems, refName: ref?.split('/').last);
  }

  /// 是否为 form-data 请求
  bool get isFormData {
    final rb = operation['requestBody'] as Map<String, dynamic>?;
    if (rb == null) return false;
    final content = rb['content'] as Map<String, dynamic>?;
    if (content == null) return false;
    return content.containsKey('multipart/form-data');
  }

  /// 响应类型 (从 200 response 中提取 $ref)
  String? get responseRef {
    final responses = operation['responses'] as Map<String, dynamic>?;
    if (responses == null) return null;
    final ok = responses['200'] as Map<String, dynamic>?;
    if (ok == null) return null;
    final content = ok['content'] as Map<String, dynamic>?;
    if (content == null) return null;

    // 优先取 application/json
    Map<String, dynamic>? schema;
    final jsonContent = content['application/json'] as Map<String, dynamic>?;
    if (jsonContent != null) {
      schema = jsonContent['schema'] as Map<String, dynamic>?;
    }
    // 尝试其他 content type
    if (schema == null) {
      for (final entry in content.entries) {
        final mediaType = entry.value as Map<String, dynamic>;
        schema = mediaType['schema'] as Map<String, dynamic>?;
        if (schema != null) break;
      }
    }
    if (schema == null) return null;

    // 情况1: 直接引用
    final ref = schema['\$ref'] as String?;
    if (ref != null) return ref.split('/').last;

    // 情况2: 数组类型，提取 items 中的引用
    if (schema['type'] == 'array') {
      final items = schema['items'] as Map<String, dynamic>?;
      if (items != null) {
        final itemsRef = items['\$ref'] as String?;
        if (itemsRef != null) return itemsRef.split('/').last;
      }
    }

    return null;
  }
}

/// 参数信息
class ParamInfo {
  final String name;
  final String in_;
  final String description;
  final bool required;
  final Map<String, dynamic> schema;

  ParamInfo({required this.name, required this.in_, required this.description, required this.required, required this.schema});
}

/// 请求体信息
class RequestBodyInfo {
  final Map<String, dynamic> schema;
  final bool isFormData;
  final bool isArray;
  final Map<String, dynamic>? arrayItems;
  final String? refName;

  RequestBodyInfo({required this.schema, required this.isFormData, required this.isArray, this.arrayItems, this.refName});
}
