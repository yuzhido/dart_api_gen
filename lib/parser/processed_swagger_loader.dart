/// processSwagger.json 加载器
/// 读取处理后的 Swagger 数据，提供结构化的领域模型和分组计算方法
library;

import 'dart:io';
import 'dart:convert';

import '../utils/naming.dart';
import '../utils/ref_utils.dart';

// ─── 领域模型 ─────────────────────────────────────────────────

/// 类型位置信息
class TypeLocation {
  final String area; // 如 "admin"、"basic"
  final String? tagDir; // 如 "announcement"，共用时为 null
  final bool isCrossAreaCommon; // 跨 area 共用
  final bool isAreaCommon; // 单 area 内多 tag 共用

  TypeLocation({
    required this.area,
    this.tagDir,
    this.isCrossAreaCommon = false,
    this.isAreaCommon = false,
  });

  /// 位置键（用于分组）
  /// - 单 area 单 tag: 'admin/announcement'
  /// - 单 area 多 tag 共用: 'admin/__common__'
  /// - 跨 area 共用: '__common__'
  String get key {
    if (isCrossAreaCommon) return '__common__';
    if (isAreaCommon) return '$area/__common__';
    return '$area/$tagDir';
  }
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
  final bool isArrayBody;

  ProcessedApi({
    required this.apiPath,
    required this.method,
    this.summary = '',
    this.operationId = '',
    this.xArea,
    this.parameters,
    this.requestBody,
    this.responses,
    this.isArrayBody = false,
  });

  /// 获取 parameters 的 $ref schema 名称
  String? get parametersRef {
    if (parameters == null) return null;
    final content = parameters!['content'] as Map<String, dynamic>?;
    if (content == null) return null;
    // 从任一 media type 中取 $ref
    for (final mt in content.values) {
      final schema = (mt as Map<String, dynamic>)['schema'] as Map<String, dynamic>?;
      final ref = schema?['\$ref'] as String?;
      if (ref != null) return extractSchemaName(ref);
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
      if (ref != null) return extractSchemaName(ref);
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
      if (ref != null) return extractSchemaName(ref);
    }
    // 尝试第一个 content type
    for (final mt in content.values) {
      final schema = (mt as Map<String, dynamic>)['schema'] as Map<String, dynamic>?;
      final ref = schema?['\$ref'] as String?;
      if (ref != null) return extractSchemaName(ref);
    }
    return null;
  }
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
            isArrayBody: a['isArrayBody'] == true,
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
      final areas = info.xArea.map((a) => a.toLowerCase()).toSet();
      if (areas.length == 1 && info.tags.length == 1) {
        // 单 area + 单 tag → 具体目录
        result[entry.key] = TypeLocation(area: areas.first, tagDir: tagToFileName(info.tags.first));
      } else if (areas.length == 1) {
        // 单 area + 多 tag → area 内共用目录
        result[entry.key] = TypeLocation(area: areas.first, isAreaCommon: true);
      } else {
        // 多 area → 跨 area 共用目录
        result[entry.key] = TypeLocation(area: 'common', isCrossAreaCommon: true);
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

  /// 判断 schema 是否为枚举
  bool isEnumSchema(String schemaName) {
    return _typesInfo[schemaName]?.isEnum ?? false;
  }
}
