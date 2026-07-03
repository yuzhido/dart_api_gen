/// processSwagger.json 加载器
/// 读取处理后的 Swagger 数据，提供结构化的领域模型和分组计算方法
library;

import 'dart:convert';
import 'dart:io';

import '../utils/naming.dart';
import '../utils/type_mapper.dart';
import '../generator/types_gen.dart';

// ─── 领域模型 ─────────────────────────────────────────────────

/// 类型位置信息
class TypeLocation {
  final String area; // 如 "admin"、"basic"、"common"
  final String? tagDir; // 如 "announcement"，common 时为 null
  final bool isCommon;

  TypeLocation({required this.area, this.tagDir, this.isCommon = false});

  /// 位置键（用于分组）
  String get key => isCommon ? 'common' : '$area/$tagDir';
}

/// Controller 位置信息
class ControllerLocation {
  final String area; // 如 "admin"
  final String fileName; // 如 "announcement"

  ControllerLocation({required this.area, required this.fileName});
}

/// 处理后的 API 条目（apiPath 数组中的一个元素）
class ProcessedApiEntry {
  final String tagName;
  final String description;
  final String? xArea;
  final List<ProcessedApi> apis;

  ProcessedApiEntry({required this.tagName, this.description = '', this.xArea, required this.apis});
}

/// 单个 API 端点
class ProcessedApi {
  final String apiPath;
  final String method;
  final String summary;
  final String operationId;
  final String? xArea;
  final Map<String, dynamic>? parameters;
  final Map<String, dynamic>? requestBody;
  final Map<String, dynamic>? responses;

  ProcessedApi({required this.apiPath, required this.method, this.summary = '', this.operationId = '', this.xArea, this.parameters, this.requestBody, this.responses});

  // ─── 适配 EndpointInfo 的属性 ───

  /// 提取 query 参数列表（从处理后的 parameters 结构中）
  List<_ParamData> get queryParams {
    if (parameters == null) return [];
    final content = parameters!['content'] as Map<String, dynamic>?;
    if (content == null) return [];
    // 处理后的 parameters 是 $ref 指向 typesInfo 中的 schema
    // 需要返回空列表（controller 会使用 $ref 名称）
    return [];
  }

  /// 获取 parameters 的 $ref schema 名称
  String? get parametersRef {
    if (parameters == null) return null;
    final content = parameters!['content'] as Map<String, dynamic>?;
    if (content == null) return null;
    // 从任一 media type 中取 $ref
    for (final mt in content.values) {
      final schema = (mt as Map<String, dynamic>)['schema'] as Map<String, dynamic>?;
      final ref = schema?['\$ref'] as String?;
      if (ref != null) return ref.split('/').last;
    }
    return null;
  }

  /// 获取 requestBody 的 $ref schema 名称
  String? get requestBodyRef {
    if (requestBody == null) return null;
    final content = requestBody!['content'] as Map<String, dynamic>?;
    if (content == null) return null;
    for (final mt in content.values) {
      final schema = (mt as Map<String, dynamic>)['schema'] as Map<String, dynamic>?;
      final ref = schema?['\$ref'] as String?;
      if (ref != null) return ref.split('/').last;
    }
    return null;
  }

  /// 是否为 form-data 请求
  bool get isFormData {
    if (requestBody == null) return false;
    final content = requestBody!['content'] as Map<String, dynamic>?;
    return content != null && content.containsKey('multipart/form-data');
  }

  /// 获取 response 的 $ref schema 名称
  String? get responseRef {
    if (responses == null) return null;
    final content = responses!['content'] as Map<String, dynamic>?;
    if (content == null) return null;
    // 优先 application/json
    final jsonContent = content['application/json'] as Map<String, dynamic>?;
    if (jsonContent != null) {
      final schema = jsonContent['schema'] as Map<String, dynamic>?;
      final ref = schema?['\$ref'] as String?;
      if (ref != null) return ref.split('/').last;
    }
    // 尝试第一个 content type
    for (final mt in content.values) {
      final schema = (mt as Map<String, dynamic>)['schema'] as Map<String, dynamic>?;
      final ref = schema?['\$ref'] as String?;
      if (ref != null) return ref.split('/').last;
    }
    return null;
  }
}

/// 参数数据（内部用）
class _ParamData {
  final String name;
  final String type;
  _ParamData({required this.name, required this.type});
}

/// 处理后的类型信息
class ProcessedTypeInfo {
  final String name;
  final Map<String, dynamic> schema;
  final bool isEnum;
  final List<String> tags;
  final List<String> xArea;

  ProcessedTypeInfo({required this.name, required this.schema, required this.isEnum, this.tags = const [], this.xArea = const []});
}

// ─── 加载器 ───────────────────────────────────────────────────

class ProcessedSwaggerLoader {
  late List<ProcessedApiEntry> _apiEntries;
  late Map<String, ProcessedTypeInfo> _typesInfo;
  late Map<String, Map<String, dynamic>> _schemas;

  /// 从 Map 加载（已解析的 JSON）
  void loadFromMap(Map<String, dynamic> json) {
    // 解析 apiPath
    _apiEntries = [];
    final apiPathList = json['apiPath'] as List<dynamic>? ?? [];
    for (final entry in apiPathList) {
      final e = entry as Map<String, dynamic>;
      final apis = <ProcessedApi>[];
      for (final api in (e['apis'] as List<dynamic>? ?? [])) {
        final a = api as Map<String, dynamic>;
        apis.add(
          ProcessedApi(
            apiPath: a['apiPath'] as String? ?? '',
            method: a['method'] as String? ?? 'get',
            summary: a['summary'] as String? ?? '',
            operationId: a['operationId'] as String? ?? '',
            xArea: a['xArea'] as String?,
            parameters: a['parameters'] as Map<String, dynamic>?,
            requestBody: a['requestBody'] as Map<String, dynamic>?,
            responses: a['responses'] as Map<String, dynamic>?,
          ),
        );
      }
      _apiEntries.add(ProcessedApiEntry(tagName: e['tagName'] as String? ?? '', description: e['description'] as String? ?? '', xArea: e['xArea'] as String?, apis: apis));
    }

    // 解析 typesInfo
    _typesInfo = {};
    final typesInfoRaw = json['typesInfo'] as Map<String, dynamic>? ?? {};
    for (final entry in typesInfoRaw.entries) {
      final schema = entry.value as Map<String, dynamic>;
      _typesInfo[entry.key] = ProcessedTypeInfo(
        name: entry.key,
        schema: schema,
        isEnum: schema.containsKey('enum'),
        tags: (schema['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        xArea: (schema['xArea'] as List<dynamic>?)?.cast<String>() ?? [],
      );
    }

    // 解析原始 schemas（兼容 typesInfo 格式）
    _schemas = {};
    for (final entry in _typesInfo.entries) {
      _schemas[entry.key] = entry.value.schema;
    }
  }

  /// 从文件加载
  void loadFromFile(String filePath) {
    final content = File(filePath).readAsStringSync();
    loadFromMap(json.decode(content) as Map<String, dynamic>);
  }

  // ─── 数据访问 ───

  List<ProcessedApiEntry> get apiEntries => _apiEntries;
  Map<String, ProcessedTypeInfo> get typesInfo => _typesInfo;
  Map<String, Map<String, dynamic>> get schemas => _schemas;

  /// 用于 TypeMapper 构造的 schemas Map
  Map<String, Map<String, dynamic>> get schemasForTypeMapper => _schemas;

  /// tag 描述映射
  Map<String, String> get tagDescriptions {
    final result = <String, String>{};
    for (final entry in _apiEntries) {
      if (entry.description.isNotEmpty) {
        result[entry.tagName] = entry.description;
      }
    }
    return result;
  }

  // ─── 分组计算 ───

  /// 将 typesInfo 分为枚举和对象
  ({Set<String> enums, Set<String> objects}) classifyTypes() {
    final enums = <String>{};
    final objects = <String>{};
    for (final entry in _typesInfo.entries) {
      if (entry.value.isEnum) {
        enums.add(entry.key);
      } else {
        objects.add(entry.key);
      }
    }
    return (enums: enums, objects: objects);
  }

  /// 计算每个类型的目录归属
  Map<String, TypeLocation> computeTypeLocations() {
    final result = <String, TypeLocation>{};
    for (final entry in _typesInfo.entries) {
      final info = entry.value;
      if (info.xArea.length == 1 && info.tags.length == 1) {
        result[entry.key] = TypeLocation(area: info.xArea.first.toLowerCase(), tagDir: tagToFileName(info.tags.first));
      } else {
        result[entry.key] = TypeLocation(area: 'common', isCommon: true);
      }
    }
    return result;
  }

  /// 计算每个 tag 的 controller 路径
  Map<String, ControllerLocation> computeControllerLocations() {
    final result = <String, ControllerLocation>{};
    for (final entry in _apiEntries) {
      final area = (entry.xArea ?? 'common').toLowerCase();
      result[entry.tagName] = ControllerLocation(area: area, fileName: tagToFileName(entry.tagName));
    }
    return result;
  }

  /// 收集 inline DTOs（从 apiPath 的 parameters/requestBody）
  /// 在 processSwagger.json 中，内联 schema 已被提升到 typesInfo，
  /// 但 controller 生成器仍需知道参数签名结构
  Map<String, List<InlineDtoInfo>> collectInlineDtos(TypeMapper typeMapper) {
    final result = <String, List<InlineDtoInfo>>{};

    for (final tagEntry in _apiEntries) {
      final tag = tagEntry.tagName;
      // Inline DTOs 已在 processSwagger.json 的 typesInfo 中
      // 无需额外收集
      final dtos = <InlineDtoInfo>[];

      if (dtos.isNotEmpty) {
        result[tag] = dtos;
      }
    }
    return result;
  }

  /// 判断 schema 是否为枚举
  bool isEnumSchema(String schemaName) {
    return _typesInfo[schemaName]?.isEnum ?? false;
  }
}
