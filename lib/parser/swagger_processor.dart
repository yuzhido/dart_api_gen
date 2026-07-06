/// Swagger JSON 预处理器
/// 参考 TS 版本 swaggerProcess，将原始 Swagger JSON 处理为 processSwagger.json
/// 核心处理：
///   1. 遍历 paths，按 tag 分组 API，标准化 parameters/requestBody/responses
///   2. 内联 schema（query 参数、request body）提升到 typesInfo
///   3. 追踪 typeUsage（哪个 tag 用了哪个类型）
///   4. 传播 tags 到引用链上的类型
///   5. 输出 = 原始 swagger + apiPath + typesInfo
library;

import 'dart:convert';

import '../constants/swagger_constants.dart';
import '../utils/ref_utils.dart';
import '../utils/media_type_utils.dart';

class SwaggerProcessor {
  /// 处理原始 Swagger JSON，返回处理后的 processSwagger 数据结构
  Map<String, dynamic> process(Map<String, dynamic> swaggerDoc) {
    final paths = swaggerDoc['paths'] as Map<String, dynamic>? ?? {};
    final components = swaggerDoc['components'] as Map<String, dynamic>? ?? {};
    final schemas = components['schemas'] as Map<String, dynamic>? ?? {};

    // 提取 tag 描述映射
    final tagDescriptions = <String, String>{};
    final tagsList = swaggerDoc['tags'] as List<dynamic>?;
    if (tagsList != null) {
      for (final tag in tagsList) {
        final t = tag as Map<String, dynamic>;
        final name = t['name'] as String?;
        final desc = t['description'] as String?;
        if (name != null && desc != null) {
          tagDescriptions[name] = desc;
        }
      }
    }

    // Phase 1: 深拷贝 schemas → typesInfo
    final typesInfo = jsonDecode(jsonEncode(schemas)) as Map<String, dynamic>;

    // Phase 2: 遍历 paths，提取 API 信息并按 tag 分组
    final typeUsageMap = <String, Set<String>>{};
    final tagMap = <String, List<Map<String, dynamic>>>{};

    const methods = httpMethods;

    for (final pathEntry in paths.entries) {
      final apiPath = pathEntry.key;
      final pathItem = pathEntry.value as Map<String, dynamic>;

      for (final method in methods) {
        final operation = pathItem[method] as Map<String, dynamic>?;
        if (operation == null) continue;

        final tags = (operation['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        final primaryTag = tags.isNotEmpty ? tags.first : 'Default';
        final xArea = operation['x-area'] as String?;

        // 收集 requestBody 中的类型引用
        _collectRefsFromRequestBody(operation, primaryTag, typeUsageMap);

        // 收集 response 中的类型引用
        _collectRefsFromResponse(operation, primaryTag, typeUsageMap);

        // 收集 parameters 中的类型引用
        _collectRefsFromParameters(operation, primaryTag, typeUsageMap);

        // 处理 query 参数（内联 schema 提升到 typesInfo）
        Map<String, dynamic>? processedParameters;
        final queryParams = _getQueryParams(operation);
        final hasInlineQuery = queryParams.isNotEmpty && queryParams.any((p) => p['schema'] is Map && !(p['schema'] as Map).containsKey('\$ref'));
        final hasInlineBody = _hasInlineBody(operation);
        final needsSuffix = hasInlineQuery && hasInlineBody;

        if (queryParams.isNotEmpty) {
          processedParameters = _processInlineQueryParams(
            queryParams,
            apiPath,
            primaryTag,
            typesInfo,
            operation['summary'] as String? ?? '',
            tagDescriptions,
            typeUsageMap,
            needsSuffix ? 'Query' : null,
          );
        }

        // 处理 requestBody（内联 schema 提升到 typesInfo）
        Map<String, dynamic>? processedRequestBody;
        final rawRequestBody = operation['requestBody'] as Map<String, dynamic>?;
        if (rawRequestBody != null) {
          processedRequestBody = _processRequestBody(
            rawRequestBody,
            apiPath,
            primaryTag,
            typesInfo,
            operation['summary'] as String? ?? '',
            xArea,
            typeUsageMap,
            needsSuffix ? 'Body' : null,
          );
        }

        // 检查 requestBody 是否为数组类型或简单类型（需要提升为 typedef）
        final rawRb = operation['requestBody'] as Map<String, dynamic>?;
        final rawRbContent = rawRb?['content'] as Map<String, dynamic>?;
        final rawRbSchema = rawRbContent != null ? (selectMediaType(rawRbContent)?['schema'] as Map<String, dynamic>?) : null;
        final isArrayBody = rawRbSchema != null && (rawRbSchema['type'] == 'array' || _isSimpleTypeSchema(rawRbSchema));

        // 简单类型 body 提升到 typesInfo 作为 typedef
        if (rawRbSchema != null && _isSimpleTypeSchema(rawRbSchema) && processedRequestBody != null) {
          final checkContent = processedRequestBody['content'] as Map<String, dynamic>?;
          final checkSchema = checkContent != null ? (selectMediaType(checkContent)?['schema'] as Map<String, dynamic>?) : null;
          if (checkSchema != null && !checkSchema.containsKey('\$ref')) {
            final schemaName = '${_generateInlineSchemaName(apiPath)}${needsSuffix ? 'Body' : ''}';
            typesInfo[schemaName] = {
              ...checkSchema,
              'description': rawRb?['description'] as String? ?? 'Generated from $apiPath',
              if ((operation['summary'] as String? ?? '').isNotEmpty) 'summary': '${operation['summary']} - 请求体',
              'tags': [primaryTag],
            };
            _recordTypeUsage(schemaName, primaryTag, typeUsageMap);
            final refPath = '$refPathPrefix$schemaName';
            processedRequestBody['content'] = {
              'application/json': {
                'schema': {'\$ref': refPath},
              },
            };
          }
        }

        // 构建处理后的 API 对象
        final processedApi = <String, dynamic>{
          'apiPath': apiPath,
          'method': method,
          'summary': (operation['summary'] as String?) ?? (operation['description'] as String?) ?? '',
          'operationId': operation['operationId'] as String? ?? '',
          if (isArrayBody) 'isArrayBody': true,
        };
        if (xArea != null) processedApi['xArea'] = xArea;
        if (processedParameters != null) processedApi['parameters'] = processedParameters;
        if (processedRequestBody != null) processedApi['requestBody'] = processedRequestBody;

        final resp200 = (operation['responses'] as Map<String, dynamic>?)?['200'] as Map<String, dynamic>?;
        if (resp200 != null) {
          processedApi['responses'] = {'description': resp200['description'] as String? ?? '', 'content': resp200['content']};
        }

        // 按 tag 分组
        tagMap.putIfAbsent(primaryTag, () => []).add(processedApi);
      }
    }

    // Phase 3: 为 typesInfo 补充引用字段描述
    for (final typeDef in typesInfo.values) {
      _enrichRefDescriptions(typeDef, schemas);
    }

    // Phase 4: 传播 tags 到引用链上的类型
    _propagateTagsToTypes(typesInfo, typeUsageMap);

    // Phase 5: 为 typesInfo 添加 xArea 信息
    final tagToXAreaMap = <String, String>{};
    for (final entry in tagMap.entries) {
      final apis = entry.value;
      if (apis.isNotEmpty && apis.first['xArea'] != null) {
        tagToXAreaMap[entry.key] = apis.first['xArea'] as String;
      }
    }
    for (final typeDef in typesInfo.values) {
      final td = typeDef as Map<String, dynamic>;
      final typeTags = td['tags'] as List<dynamic>?;
      if (typeTags != null && typeTags.isNotEmpty) {
        final xAreas = <String>{};
        for (final tagName in typeTags) {
          final xArea = tagToXAreaMap[tagName.toString()];
          if (xArea != null) xAreas.add(xArea);
        }
        if (xAreas.isNotEmpty) {
          td['xArea'] = xAreas.toList()..sort();
        }
      }
    }

    // Phase 6: 构建 apiPath 数组
    final apiPathList = <Map<String, dynamic>>[];
    for (final entry in tagMap.entries) {
      final tagName = entry.key;
      final apis = entry.value;
      final tagEntry = <String, dynamic>{'tagName': tagName};
      final desc = tagDescriptions[tagName];
      if (desc != null) tagEntry['description'] = desc;
      if (apis.isNotEmpty && apis.first['xArea'] != null) {
        tagEntry['xArea'] = apis.first['xArea'];
      }
      tagEntry['apis'] = apis;
      apiPathList.add(tagEntry);
    }

    // Phase 7: 构建最终输出
    final processedSwagger = <String, dynamic>{};
    for (final key in ['openapi', 'info', 'servers', 'paths', 'security', 'tags']) {
      if (swaggerDoc.containsKey(key)) {
        processedSwagger[key] = swaggerDoc[key];
      }
    }
    processedSwagger['components'] = jsonDecode(jsonEncode(components));
    processedSwagger['apiPath'] = apiPathList;
    processedSwagger['typesInfo'] = typesInfo;

    return processedSwagger;
  }

  // ─── 类型引用收集 ───────────────────────────────────────────

  void _collectRefsFromRequestBody(Map<String, dynamic> operation, String tag, Map<String, Set<String>> usageMap) {
    final rb = operation['requestBody'] as Map<String, dynamic>?;
    if (rb == null) return;
    final content = rb['content'] as Map<String, dynamic>?;
    if (content == null) return;
    final mediaType = selectMediaType(content);
    if (mediaType == null) return;
    final schema = mediaType['schema'] as Map<String, dynamic>?;
    if (schema == null) return;
    _recordSchemaRefs(schema, tag, usageMap);
  }

  void _collectRefsFromResponse(Map<String, dynamic> operation, String tag, Map<String, Set<String>> usageMap) {
    final responses = operation['responses'] as Map<String, dynamic>?;
    if (responses == null) return;
    final resp200 = responses['200'] as Map<String, dynamic>?;
    if (resp200 == null) return;
    final content = resp200['content'] as Map<String, dynamic>?;
    if (content == null) return;
    final mediaType = selectMediaType(content);
    if (mediaType == null) return;
    final schema = mediaType['schema'] as Map<String, dynamic>?;
    if (schema == null) return;
    _recordSchemaRefs(schema, tag, usageMap);
  }

  void _collectRefsFromParameters(Map<String, dynamic> operation, String tag, Map<String, Set<String>> usageMap) {
    final params = operation['parameters'] as List<dynamic>?;
    if (params == null) return;
    for (final param in params) {
      final p = param as Map<String, dynamic>;
      final schema = p['schema'] as Map<String, dynamic>?;
      if (schema == null) continue;
      final ref = schema['\$ref'] as String?;
      if (ref != null) {
        _recordTypeUsage(_extractSchemaName(ref), tag, usageMap);
      }
    }
  }

  void _recordSchemaRefs(Map<String, dynamic> schema, String tag, Map<String, Set<String>> usageMap) {
    final ref = schema['\$ref'] as String?;
    if (ref != null) {
      _recordTypeUsage(_extractSchemaName(ref), tag, usageMap);
      return;
    }
    // 处理数组类型 items
    final items = schema['items'] as Map<String, dynamic>?;
    if (items != null) {
      _recordSchemaRefs(items, tag, usageMap);
    }
  }

  void _recordTypeUsage(String typeName, String tag, Map<String, Set<String>> usageMap) {
    if (typeName.isEmpty) return;
    usageMap.putIfAbsent(typeName, () => {}).add(tag);
  }

  // ─── Query 参数处理 ─────────────────────────────────────────

  List<Map<String, dynamic>> _getQueryParams(Map<String, dynamic> operation) {
    final params = operation['parameters'] as List<dynamic>?;
    if (params == null) return [];
    return params.where((p) => (p as Map<String, dynamic>)['in'] == 'query').cast<Map<String, dynamic>>().toList();
  }

  bool _hasInlineBody(Map<String, dynamic> operation) {
    final rb = operation['requestBody'] as Map<String, dynamic>?;
    if (rb == null) return false;
    final content = rb['content'] as Map<String, dynamic>?;
    if (content == null) return false;
    return !content.values.any((m) {
          final mt = m as Map<String, dynamic>;
          final schema = mt['schema'] as Map<String, dynamic>?;
          return schema != null && schema.containsKey('\$ref');
        }) &&
        !content.values.any((m) {
          // 简单类型 body（integer/string/boolean/number）不需要提升为 DTO
          final mt = m as Map<String, dynamic>;
          final schema = mt['schema'] as Map<String, dynamic>?;
          return schema != null && _isSimpleTypeSchema(schema);
        });
  }

  Map<String, dynamic>? _processInlineQueryParams(
    List<Map<String, dynamic>> queryParams,
    String apiPath,
    String tag,
    Map<String, dynamic> typesInfo,
    String summary,
    Map<String, String> tagDescriptions,
    Map<String, Set<String>> typeUsageMap,
    String? suffix,
  ) {
    final schemaName = '${_generateInlineSchemaName(apiPath)}${suffix ?? ''}';

    // 构建 properties
    final properties = <String, dynamic>{};
    for (final param in queryParams) {
      final paramName = param['name'] as String;
      final paramSchema = param['schema'] as Map<String, dynamic>? ?? {};
      properties[paramName] = {
        'type': paramSchema['type'] ?? 'string',
        if (paramSchema.containsKey('format')) 'format': paramSchema['format'],
        if (param.containsKey('description')) 'description': param['description'],
        if (param['required'] == true) 'required': true,
        'in': 'query',
      };
    }

    // 生成类型描述
    final tagDesc = tagDescriptions[tag] ?? '';
    var typeDescription = '';
    if (tagDesc.isNotEmpty && summary.isNotEmpty) {
      typeDescription = '$tagDesc$summary请求参数';
    } else if (tagDesc.isNotEmpty) {
      typeDescription = '$tagDesc请求参数';
    } else if (summary.isNotEmpty) {
      typeDescription = '$summary请求参数';
    }

    // 添加到 typesInfo
    typesInfo[schemaName] = {
      'type': 'object',
      if (typeDescription.isNotEmpty) 'description': typeDescription,
      'properties': properties,
      'tags': [tag],
    };

    _recordTypeUsage(schemaName, tag, typeUsageMap);

    return {
      'description': '',
      'content': {
        'text/plain': {
          'schema': {'\$ref': '$refPathPrefix$schemaName'},
        },
        'application/json': {
          'schema': {'\$ref': '$refPathPrefix$schemaName'},
        },
        'text/json': {
          'schema': {'\$ref': '$refPathPrefix$schemaName'},
        },
      },
    };
  }

  // ─── RequestBody 处理 ────────────────────────────────────────

  Map<String, dynamic>? _processRequestBody(
    Map<String, dynamic> requestBody,
    String apiPath,
    String tag,
    Map<String, dynamic> typesInfo,
    String summary,
    String? xArea,
    Map<String, Set<String>> typeUsageMap,
    String? suffix,
  ) {
    final content = requestBody['content'] as Map<String, dynamic>?;
    if (content == null) return null;

    final isMultipart = content.containsKey('multipart/form-data');
    final hasRef = content.values.any((m) {
      final mt = m as Map<String, dynamic>;
      final schema = mt['schema'] as Map<String, dynamic>?;
      return schema != null && schema.containsKey('\$ref');
    });

    if (hasRef) {
      // 有 $ref 引用，标准化输出
      return _normalizeRequestBodyWithRef(requestBody, isMultipart);
    }

    // 简单类型 body（integer/string/boolean/number）不提升到 typesInfo，保持原始结构
    final firstMediaType = isMultipart ? content['multipart/form-data'] as Map<String, dynamic>? : selectMediaType(content);
    final schema = firstMediaType?['schema'] as Map<String, dynamic>?;
    if (schema != null && _isSimpleTypeSchema(schema)) {
      // 保留原始 body 结构，controller_gen 会通过 TypeMapper 映射为简单 Dart 类型
      return _normalizeSimpleBody(requestBody, content);
    }

    // 内联 schema：提升到 typesInfo
    final schemaName = '${_generateInlineSchemaName(apiPath)}${suffix ?? ''}';

    if (schema != null) {
      typesInfo[schemaName] = {
        ...schema,
        'description': requestBody['description'] as String? ?? 'Generated from $apiPath',
        if (summary.isNotEmpty) 'summary': '$summary - 请求体',
        'tags': [tag],
        if (isMultipart) 'x-multipart': true, // 标记为 multipart/form-data 请求体
      };
      _recordTypeUsage(schemaName, tag, typeUsageMap);
    }

    final refPath = '$refPathPrefix$schemaName';
    if (isMultipart) {
      return {
        'description': requestBody['description'] as String? ?? '',
        'content': {
          'multipart/form-data': {
            'schema': {'\$ref': refPath},
          },
        },
      };
    }
    return {
      'description': requestBody['description'] as String? ?? '',
      'content': {
        'text/plain': {
          'schema': {'\$ref': refPath},
        },
        'application/json': {
          'schema': {'\$ref': refPath},
        },
        'text/json': {
          'schema': {'\$ref': refPath},
        },
      },
    };
  }

  Map<String, dynamic> _normalizeRequestBodyWithRef(Map<String, dynamic> requestBody, bool isMultipart) {
    final content = requestBody['content'] as Map<String, dynamic>;
    final description = requestBody['description'] as String? ?? '';

    if (isMultipart) {
      final formData = content['multipart/form-data'] as Map<String, dynamic>?;
      final ref = formData?['schema']?['\$ref'] as String?;
      final schemaName = ref != null ? _extractSchemaName(ref) : '';
      return {
        'description': description,
        'content': {
          'multipart/form-data': {
            'schema': {'\$ref': '$refPathPrefix$schemaName'},
          },
        },
      };
    }

    // 查找第一个有 $ref 的 media type
    String? schemaName;
    for (final entry in content.entries) {
      final mt = entry.value as Map<String, dynamic>;
      final ref = mt['schema']?['\$ref'] as String?;
      if (ref != null) {
        schemaName = _extractSchemaName(ref);
        break;
      }
    }

    return {
      'description': description,
      'content': {
        'text/plain': {
          'schema': {'\$ref': '$refPathPrefix$schemaName'},
        },
        'application/json': {
          'schema': {'\$ref': '$refPathPrefix$schemaName'},
        },
        'text/json': {
          'schema': {'\$ref': '$refPathPrefix$schemaName'},
        },
      },
    };
  }

  // ─── 引用描述补充 ────────────────────────────────────────────

  void _enrichRefDescriptions(dynamic node, Map<String, dynamic> allSchemas) {
    if (node is! Map<String, dynamic>) return;

    final properties = node['properties'] as Map<String, dynamic>?;
    if (properties != null) {
      for (final prop in properties.values) {
        if (prop is! Map<String, dynamic>) continue;

        if (prop.containsKey('\$ref')) {
          final refName = _extractSchemaName(prop['\$ref'] as String);
          final refSchema = allSchemas[refName] as Map<String, dynamic>?;
          if (refSchema != null) {
            if (!prop.containsKey('description') && refSchema.containsKey('description')) {
              prop['description'] = refSchema['description'];
            }
            prop['_isEnum'] = refSchema.containsKey('enum');
            prop['_refType'] = refSchema.containsKey('enum') ? 'enum' : 'interface';
          }
        }

        if (prop.containsKey('properties')) {
          _enrichRefDescriptions(prop, allSchemas);
        }

        final items = prop['items'];
        if (items is Map<String, dynamic>) {
          if (items.containsKey('\$ref')) {
            final refName = _extractSchemaName(items['\$ref'] as String);
            final refSchema = allSchemas[refName] as Map<String, dynamic>?;
            if (refSchema != null) {
              items['_isEnum'] = refSchema.containsKey('enum');
              items['_refType'] = refSchema.containsKey('enum') ? 'enum' : 'interface';
            }
          }
          _enrichRefDescriptions(items, allSchemas);
        }
      }
    }

    // 处理顶层 items
    final topItems = node['items'];
    if (topItems is Map<String, dynamic>) {
      if (topItems.containsKey('\$ref')) {
        final refName = _extractSchemaName(topItems['\$ref'] as String);
        final refSchema = allSchemas[refName] as Map<String, dynamic>?;
        if (refSchema != null) {
          topItems['_isEnum'] = refSchema.containsKey('enum');
          topItems['_refType'] = refSchema.containsKey('enum') ? 'enum' : 'interface';
        }
      }
      _enrichRefDescriptions(topItems, allSchemas);
    }

    // 处理 allOf / anyOf / oneOf
    for (final key in ['allOf', 'anyOf', 'oneOf']) {
      final combo = node[key];
      if (combo is List) {
        for (final item in combo) {
          _enrichRefDescriptions(item, allSchemas);
        }
      }
    }
  }

  // ─── Tags 传播 ──────────────────────────────────────────────

  void _propagateTagsToTypes(Map<String, dynamic> typesInfo, Map<String, Set<String>> usageMap) {
    // 先为直接引用的类型设置 tags
    for (final entry in typesInfo.entries) {
      final tags = usageMap[entry.key];
      if (tags != null && tags.isNotEmpty) {
        (entry.value as Map<String, dynamic>)['tags'] = tags.toList()..sort();
      }
    }

    // 递归传播：如果类型 A 有 tag X，且 A 引用了 B，则 B 也应有 tag X
    var changed = true;
    var iterations = 0;
    const maxIterations = 10;

    while (changed && iterations < maxIterations) {
      changed = false;
      iterations++;

      for (final entry in typesInfo.entries) {
        final typeDef = entry.value as Map<String, dynamic>;
        final currentTags = (typeDef['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        if (currentTags.isEmpty) continue;

        final referencedTypes = _extractRefsFromType(typeDef);
        for (final refTypeName in referencedTypes) {
          final refTypeDef = typesInfo[refTypeName] as Map<String, dynamic>?;
          if (refTypeDef == null) continue;

          final existingTags = (refTypeDef['tags'] as List<dynamic>?)?.cast<String>() ?? [];
          final newTags = <String>{...existingTags, ...currentTags};
          if (newTags.length > existingTags.length) {
            refTypeDef['tags'] = newTags.toList()..sort();
            changed = true;
          }
        }
      }
    }
  }

  List<String> _extractRefsFromType(dynamic typeDef) {
    final refs = <String>[];
    if (typeDef is! Map<String, dynamic>) return refs;

    final ref = typeDef['\$ref'] as String?;
    if (ref != null) {
      final name = _extractSchemaName(ref);
      if (name.isNotEmpty) refs.add(name);
    }

    final properties = typeDef['properties'] as Map<String, dynamic>?;
    if (properties != null) {
      for (final prop in properties.values) {
        refs.addAll(_extractRefsFromType(prop));
      }
    }

    final items = typeDef['items'];
    if (items != null) refs.addAll(_extractRefsFromType(items));

    for (final key in ['allOf', 'anyOf', 'oneOf']) {
      final combo = typeDef[key];
      if (combo is List) {
        for (final item in combo) {
          refs.addAll(_extractRefsFromType(item));
        }
      }
    }

    return refs;
  }

  // ─── 工具方法 ────────────────────────────────────────────────

  String _extractSchemaName(String ref) => extractSchemaName(ref);

  /// 从 API 路径生成内联 schema 名称（取最后两段转 PascalCase）
  String _generateInlineSchemaName(String apiPath) {
    final segments = apiPath.split('/').where((s) => s.isNotEmpty).toList();
    final count = segments.length >= 2 ? 2 : 1;
    final selected = segments.sublist(segments.length - count);
    return selected
        .map((s) {
          return s
              .split('-')
              .map((part) {
                if (part.isEmpty) return '';
                return part[0].toUpperCase() + part.substring(1);
              })
              .join('');
        })
        .join('');
  }

  /// 判断 schema 是否为简单类型（非对象、非数组、无 properties、无 $ref）
  bool _isSimpleTypeSchema(Map<String, dynamic> schema) {
    if (schema.containsKey('\$ref')) return false;
    if (schema.containsKey('properties')) return false;
    if (schema['type'] == 'array') return false;
    final type = schema['type'] as String?;
    return type == 'integer' || type == 'number' || type == 'string' || type == 'boolean';
  }

  /// 简单类型 body 标准化输出（不提升到 typesInfo，保留原始 schema）
  Map<String, dynamic> _normalizeSimpleBody(Map<String, dynamic> requestBody, Map<String, dynamic> content) {
    final description = requestBody['description'] as String? ?? '';
    // 优先选择 application/json，否则取第一个 media type
    final selectedKey = content.containsKey('application/json') ? 'application/json' : content.keys.first;
    final selectedContent = content[selectedKey] as Map<String, dynamic>;
    final schema = selectedContent['schema'];
    return {
      'description': description,
      'content': {
        'application/json': {'schema': schema},
      },
    };
  }
}
