/// 数据模型文件生成器
library;

import '../utils/naming.dart';
import '../utils/type_mapper.dart';
import '../utils/ref_utils.dart';
import '../utils/header_utils.dart';
import '../utils/path_utils.dart';

/// Inline DTO 信息
class InlineDtoInfo {
  final String className;
  final List<InlineFieldInfo> fields;
  final bool isTypedef;
  final String typedefType;

  InlineDtoInfo({required this.className, required this.fields, this.isTypedef = false, this.typedefType = ''});
}

/// Inline DTO 字段信息
class InlineFieldInfo {
  final String name;
  final String type;
  final bool isRequired;
  final String description;
  final String jsonName;

  InlineFieldInfo({required this.name, required this.type, required this.isRequired, required this.description, required this.jsonName});
}

class TypesGenerator {
  final Map<String, Map<String, dynamic>> allSchemas;
  final TypeMapper typeMapper;

  TypesGenerator(this.allSchemas, this.typeMapper);

  /// 为指定位置生成 types 文件
  /// [schemaLocationMap] schemaName → 其 types 文件的相对路径
  /// [enumLocationMap] enumName → 其 enum 文件的相对路径
  String generateForLocation(
    String area,
    String tagDir,
    Set<String> schemaNames,
    Set<String> locationEnums,
    List<InlineDtoInfo> inlineDtos, {
    Map<String, String> schemaLocationMap = const {},
    Map<String, String> enumLocationMap = const {},
  }) {
    final filePath = '$area/$tagDir/index.dart';
    final buf = StringBuffer();

    _writeFileHeader(buf, 'xArea: $area 服务下相关数据模型类型定义', tagDir);
    _writeImports(buf, schemaNames, filePath, locationEnums, enumLocationMap, schemaLocationMap);

    // 生成每个 schema 对应的 class
    var isFirst = true;
    for (final schemaName in schemaNames) {
      final schema = allSchemas[schemaName];
      if (schema == null) continue;
      if (schema.containsKey('enum')) continue;

      if (!isFirst) buf.writeln();
      _generateClass(buf, schemaName, schema);
      isFirst = false;
    }

    // 生成 inline DTOs
    for (final dto in inlineDtos) {
      buf.writeln();
      if (dto.isTypedef) {
        buf.writeln('typedef ${dto.className} = ${dto.typedefType};');
      } else {
        _generateInlineDto(buf, dto);
      }
    }

    return buf.toString();
  }

  /// 生成 common types 文件
  String generateCommon(Set<String> objectNames, Set<String> commonEnums, {Map<String, String> schemaLocationMap = const {}, Map<String, String> enumLocationMap = const {}}) {
    const filePath = 'common/index.dart';
    final buf = StringBuffer();

    _writeFileHeader(buf, '通用数据模型类型定义', null);
    _writeImports(buf, objectNames, filePath, commonEnums, enumLocationMap, schemaLocationMap);

    var isFirst = true;
    for (final schemaName in objectNames) {
      final schema = allSchemas[schemaName];
      if (schema == null) continue;
      if (schema.containsKey('enum')) continue;

      if (!isFirst) buf.writeln();
      _generateClass(buf, schemaName, schema);
      isFirst = false;
    }

    return buf.toString();
  }

  // ─── 文件结构生成 ───────────────────────────────────────────

  void _writeFileHeader(StringBuffer buf, String description, String? tagDir) {
    if (tagDir != null) {
      writeFileHeader(buf, description, extraDocLines: ['tags: $tagDir 相关的模型类型定义']);
    } else {
      writeFileHeader(buf, description);
    }
    buf.writeln();
  }

  void _writeImports(
    StringBuffer buf,
    Set<String> schemaNames,
    String filePath,
    Set<String> locationEnums,
    Map<String, String> enumLocationMap,
    Map<String, String> schemaLocationMap,
  ) {
    buf.writeln("import 'package:json_annotation/json_annotation.dart';");

    for (final imp in _collectEnumImports(schemaNames, locationEnums, enumLocationMap, filePath)) {
      buf.writeln("import '$imp';");
    }
    for (final imp in _collectTypeImports(schemaNames, schemaLocationMap, filePath)) {
      buf.writeln("import '$imp';");
    }

    buf.writeln("part 'index.g.dart';");
    buf.writeln();
  }

  // ─── Class 生成（统一 schema-based 和 inline DTO）─────────────

  /// 生成 @JsonSerializable class 的完整内容（字段、构造函数、fromJson/toJson）
  void _writeClassBody(StringBuffer buf, String className, List<InlineFieldInfo> fields) {
    buf.writeln('@JsonSerializable(explicitToJson: true)');
    buf.writeln('class $className {');

    final requiredFields = <String>[];
    final optionalFields = <String>[];

    for (var i = 0; i < fields.length; i++) {
      final field = fields[i];
      final safeName = dartObjectProperties.contains(field.name) ? '${field.name}Filed' : field.name;

      buf.writeln('  /// - ${field.description.isNotEmpty ? field.description : '未定义'}');
      buf.writeln("  @JsonKey(name: '${field.jsonName}')");

      if (field.isRequired) {
        buf.writeln('  late ${field.type} $safeName;');
        requiredFields.add(safeName);
      } else {
        final nullableType = field.type == 'dynamic' ? field.type : '${field.type}?';
        buf.writeln('  $nullableType $safeName;');
        optionalFields.add(safeName);
      }

      if (i < fields.length - 1) buf.writeln();
    }

    buf.writeln();
    _writeConstructor(buf, className, requiredFields, optionalFields);
    buf.writeln();
    _writeJsonMethods(buf, className);
    buf.writeln('}');
  }

  void _writeConstructor(StringBuffer buf, String className, List<String> requiredFields, List<String> optionalFields) {
    final params = <String>[for (final f in requiredFields) 'required this.$f', for (final f in optionalFields) 'this.$f'];

    if (params.isEmpty) {
      buf.writeln('  $className();');
    } else {
      buf.writeln('  $className({${params.join(', ')}});');
    }
  }

  void _writeJsonMethods(StringBuffer buf, String className) {
    buf.writeln('  // 从JSON创建');
    buf.writeln('  factory $className.fromJson(Map<String, dynamic> json) => _\$${className}FromJson(json);');
    buf.writeln('  // 转换为JSON');
    buf.writeln('  Map<String, dynamic> toJson() => _\$${className}ToJson(this);');
  }

  /// 从 schema 生成 class（处理 typedef 和 object class）
  void _generateClass(StringBuffer buf, String schemaName, Map<String, dynamic> schema) {
    final className = schemaToClassName(schemaName);

    // 数组类型 schema → 生成 typedef
    if (schema['type'] == 'array') {
      final items = schema['items'] as Map<String, dynamic>?;
      final itemType = items != null ? typeMapper.mapType(items) : 'dynamic';
      buf.writeln('typedef $className = List<$itemType>;');
      return;
    }

    // 简单类型 schema → 生成 typedef
    final simpleType = schema['type'] as String?;
    if (simpleType == 'integer' || simpleType == 'number' || simpleType == 'string' || simpleType == 'boolean') {
      buf.writeln('typedef $className = ${typeMapper.mapType(schema)};');
      return;
    }

    // 对象类型 → 生成 class
    final properties = schema['properties'] as Map<String, dynamic>? ?? {};
    final required = (schema['required'] as List<dynamic>?)?.cast<String>() ?? [];

    final fields = properties.entries.map((e) {
      final jsonName = e.key;
      final propSchema = e.value as Map<String, dynamic>;
      return InlineFieldInfo(
        name: jsonName,
        type: typeMapper.mapType(propSchema),
        isRequired: required.contains(jsonName),
        description: propSchema['description'] as String? ?? '',
        jsonName: jsonName,
      );
    }).toList();

    _writeClassBody(buf, className, fields);
  }

  /// 从 InlineDtoInfo 生成 class
  void _generateInlineDto(StringBuffer buf, InlineDtoInfo dto) {
    _writeClassBody(buf, dto.className, dto.fields);
  }

  // ─── Import 收集 ──────────────────────────────────────────────

  /// 收集枚举 import 路径
  List<String> _collectEnumImports(Set<String> schemaNames, Set<String> locationEnums, Map<String, String> enumLocationMap, String currentFilePath) {
    final imports = <String>{};

    for (final schemaName in schemaNames) {
      final schema = allSchemas[schemaName];
      if (schema == null) continue;

      final refs = <String>{};
      _collectRefs(schema, refs, (s) => s.containsKey('enum'));

      for (final ref in refs) {
        final enumPath = enumLocationMap[ref];
        if (enumPath != null) {
          final depth = '../' * currentFilePath.split('/').length;
          imports.add('${depth}enum/$enumPath');
        }
      }
    }

    return imports.toList()..sort();
  }

  /// 收集跨位置的类型引用 import
  List<String> _collectTypeImports(Set<String> schemaNames, Map<String, String> schemaLocationMap, String currentFilePath) {
    final imports = <String>{};

    for (final schemaName in schemaNames) {
      final schema = allSchemas[schemaName];
      if (schema == null) continue;

      final refs = <String>{};
      _collectRefs(schema, refs, (s) => !s.containsKey('enum'));

      for (final ref in refs) {
        final refLocation = schemaLocationMap[ref];
        if (refLocation == null) continue;
        if (refLocation == currentFilePath) continue;

        imports.add(computeRelativePath(currentFilePath, refLocation));
      }
    }

    return imports.toList()..sort();
  }

  /// 递归收集 schema 中的 $ref 引用
  /// [filter] 用于过滤目标 schema（如只收集枚举或只收集对象）
  void _collectRefs(dynamic node, Set<String> refs, bool Function(Map<String, dynamic>) filter) {
    if (node is Map<String, dynamic>) {
      final ref = node['\$ref'] as String?;
      if (ref != null) {
        final schemaName = extractSchemaName(ref);
        final schema = allSchemas[schemaName];
        if (schema != null && filter(schema)) {
          refs.add(schemaName);
        }
      }
      for (final value in node.values) {
        _collectRefs(value, refs, filter);
      }
    } else if (node is List) {
      for (final item in node) {
        _collectRefs(item, refs, filter);
      }
    }
  }
}
