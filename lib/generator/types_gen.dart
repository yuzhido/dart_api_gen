/// 数据模型文件生成器
import '../utils/naming.dart';
import '../utils/type_mapper.dart';

/// Inline DTO 信息
class InlineDtoInfo {
  final String className;
  final List<InlineFieldInfo> fields;
  final bool isTypedef;
  final String typedefType;

  InlineDtoInfo({
    required this.className,
    required this.fields,
    this.isTypedef = false,
    this.typedefType = '',
  });
}

/// Inline DTO 字段信息
class InlineFieldInfo {
  final String name;
  final String type;
  final bool isRequired;
  final String description;
  final String jsonName;

  InlineFieldInfo({
    required this.name,
    required this.type,
    required this.isRequired,
    required this.description,
    required this.jsonName,
  });
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
    final buf = StringBuffer();

    // 文件头注释
    buf.writeln('/// xArea: $area 服务下相关数据模型类型定义');
    buf.writeln('/// tags: $tagDir 相关的模型类型定义');
    buf.writeln('/// 此文件由 codeGen 工具自动生成');
    buf.writeln('/// 请勿手动修改');
    buf.writeln('library;');
    buf.writeln();
    buf.writeln("import 'package:json_annotation/json_annotation.dart';");

    // 收集枚举 import
    final typesFilePath = '$area/$tagDir/index.dart';
    final enumImports = _collectEnumImports(schemaNames, locationEnums, enumLocationMap, typesFilePath);
    for (final imp in enumImports) {
      buf.writeln("import '$imp';");
    }

    // 收集跨位置的类型引用 import
    final typeImports = _collectTypeImports(schemaNames, schemaLocationMap, typesFilePath);
    for (final imp in typeImports) {
      buf.writeln("import '$imp';");
    }

    buf.writeln("part 'index.g.dart';");
    buf.writeln();

    // 生成每个 schema 对应的 class
    var isFirst = true;
    for (final schemaName in schemaNames) {
      final schema = allSchemas[schemaName];
      if (schema == null) continue;
      if (schema.containsKey('enum')) continue;

      if (!isFirst) {
        buf.writeln();
      }
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
  String generateCommon(Set<String> objectNames, Set<String> commonEnums, {
    Map<String, String> schemaLocationMap = const {},
    Map<String, String> enumLocationMap = const {},
  }) {
    final buf = StringBuffer();

    buf.writeln('/// 通用数据模型类型定义');
    buf.writeln('/// 此文件由 codeGen 工具自动生成');
    buf.writeln('/// 请勿手动修改');
    buf.writeln('library;');
    buf.writeln();
    buf.writeln("import 'package:json_annotation/json_annotation.dart';");

    // 收集 common 对象引用的所有枚举 import
    final enumImports = _collectEnumImports(objectNames, commonEnums, enumLocationMap, 'common/index.dart');
    for (final imp in enumImports) {
      buf.writeln("import '$imp';");
    }

    // 收集跨位置的类型引用 import
    final typeImports = _collectTypeImports(objectNames, schemaLocationMap, 'common/index.dart');
    for (final imp in typeImports) {
      buf.writeln("import '$imp';");
    }

    buf.writeln("part 'index.g.dart';");
    buf.writeln();

    for (final schemaName in objectNames) {
      final schema = allSchemas[schemaName];
      if (schema == null) continue;
      if (schema.containsKey('enum')) continue;

      if (schemaName != objectNames.first) {
        buf.writeln();
      }
      _generateClass(buf, schemaName, schema);
    }

    return buf.toString();
  }

  void _generateClass(StringBuffer buf, String schemaName, Map<String, dynamic> schema) {
    final className = schemaToClassName(schemaName);
    final properties = schema['properties'] as Map<String, dynamic>? ?? {};
    final required = (schema['required'] as List<dynamic>?)?.cast<String>() ?? [];

    buf.writeln('@JsonSerializable(explicitToJson: true)');
    buf.writeln('class $className {');

    // 字段
    final fieldNames = <String>[];
    final requiredFields = <String>[];
    final optionalFields = <String>[];
    final propEntries = properties.entries.toList();

    for (var i = 0; i < propEntries.length; i++) {
      final propEntry = propEntries[i];
      final jsonFieldName = propEntry.key;
      final propSchema = propEntry.value as Map<String, dynamic>;
      final isRequired = required.contains(jsonFieldName);
      final propDescription = propSchema['description'] as String? ?? '';
      final type = typeMapper.mapType(propSchema);

      // 检查字段名是否与 Dart Object 内置属性冲突
      final safeFieldName = dartObjectProperties.contains(jsonFieldName) ? '${jsonFieldName}Filed' : jsonFieldName;

      buf.writeln('  /// - ${propDescription.isNotEmpty ? propDescription : '未定义'}');
      buf.writeln("  @JsonKey(name: '$jsonFieldName')");

      if (isRequired) {
        buf.writeln('  late $type $safeFieldName;');
        requiredFields.add(safeFieldName);
      } else {
        // dynamic 类型不加 ?
        final nullableType = type == 'dynamic' ? type : '$type?';
        buf.writeln('  $nullableType $safeFieldName;');
        optionalFields.add(safeFieldName);
      }

      fieldNames.add(safeFieldName);
      // 只在非最后一个字段后添加空行
      if (i < propEntries.length - 1) {
        buf.writeln();
      }
    }

    // 构造函数前空行
    buf.writeln();

    // 构造函数
    final constructorParams = <String>[];
    for (final f in requiredFields) {
      constructorParams.add('required this.$f');
    }
    for (final f in optionalFields) {
      constructorParams.add('this.$f');
    }

    if (constructorParams.isEmpty) {
      buf.writeln('  $className();');
    } else {
      buf.writeln('  $className({${constructorParams.join(', ')}});');
    }
    buf.writeln();

    // fromJson / toJson
    buf.writeln('  // 从JSON创建');
    buf.writeln('  factory $className.fromJson(Map<String, dynamic> json) => _\$${className}FromJson(json);');
    buf.writeln('  // 转换为JSON');
    buf.writeln('  Map<String, dynamic> toJson() => _\$${className}ToJson(this);');

    buf.writeln('}');
  }

  void _generateInlineDto(StringBuffer buf, InlineDtoInfo dto) {
    final className = dto.className;

    buf.writeln('@JsonSerializable(explicitToJson: true)');
    buf.writeln('class $className {');

    final requiredFields = <String>[];
    final optionalFields = <String>[];

    for (var i = 0; i < dto.fields.length; i++) {
      final field = dto.fields[i];
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
      if (i < dto.fields.length - 1) {
        buf.writeln();
      }
    }

    buf.writeln();

    final constructorParams = <String>[];
    for (final f in requiredFields) {
      constructorParams.add('required this.$f');
    }
    for (final f in optionalFields) {
      constructorParams.add('this.$f');
    }

    if (constructorParams.isEmpty) {
      buf.writeln('  $className();');
    } else {
      buf.writeln('  $className({${constructorParams.join(', ')}});');
    }
    buf.writeln();

    buf.writeln('  // 从JSON创建');
    buf.writeln('  factory $className.fromJson(Map<String, dynamic> json) => _\$${className}FromJson(json);');
    buf.writeln('  // 转换为JSON');
    buf.writeln('  Map<String, dynamic> toJson() => _\$${className}ToJson(this);');

    buf.write('}');
  }

  /// 收集枚举 import 路径
  /// [currentFilePath] 当前 types 文件相对于 types/ 目录的路径
  List<String> _collectEnumImports(
    Set<String> schemaNames,
    Set<String> locationEnums,
    Map<String, String> enumLocationMap,
    String currentFilePath,
  ) {
    final imports = <String>{};

    for (final schemaName in schemaNames) {
      final schema = allSchemas[schemaName];
      if (schema == null) continue;

      final refs = <String>{};
      _collectEnumRefs(schema, refs);

      for (final ref in refs) {
        final enumPath = enumLocationMap[ref];
        if (enumPath != null) {
          // 计算从当前 types 文件到 enum 文件的相对路径
          final depth = '../' * currentFilePath.split('/').length;
          imports.add('${depth}enum/$enumPath');
        }
      }
    }

    return imports.toList()..sort();
  }

  /// 收集跨位置的类型引用 import
  /// [currentFilePath] 当前 types 文件相对于 types/ 目录的路径
  List<String> _collectTypeImports(
    Set<String> schemaNames,
    Map<String, String> schemaLocationMap,
    String currentFilePath,
  ) {
    final imports = <String>{};

    for (final schemaName in schemaNames) {
      final schema = allSchemas[schemaName];
      if (schema == null) continue;

      final refs = <String>{};
      _collectObjectRefs(schema, refs);

      for (final ref in refs) {
        final refLocation = schemaLocationMap[ref];
        if (refLocation == null) continue;
        if (refLocation == currentFilePath) continue;

        // 计算相对路径: 从当前 types 文件到目标 types 文件
        final currentParts = currentFilePath.split('/');
        final refParts = refLocation.split('/');
        // 找到共同前缀长度
        var commonLen = 0;
        while (commonLen < currentParts.length - 1 &&
            commonLen < refParts.length - 1 &&
            currentParts[commonLen] == refParts[commonLen]) {
          commonLen++;
        }
        final upCount = currentParts.length - 1 - commonLen; // -1 因为最后是文件名
        final upPath = upCount > 0 ? '../' * upCount : '';
        final downPath = refParts.skip(commonLen).join('/');
        imports.add('$upPath$downPath');
      }
    }

    return imports.toList()..sort();
  }

  /// 递归收集 schema 中的对象引用 (非枚举)
  void _collectObjectRefs(dynamic node, Set<String> refs) {
    if (node is Map<String, dynamic>) {
      final ref = node['\$ref'] as String?;
      if (ref != null) {
        final schemaName = ref.split('/').last;
        final schema = allSchemas[schemaName];
        if (schema != null && !schema.containsKey('enum')) {
          refs.add(schemaName);
        }
      }
      for (final value in node.values) {
        _collectObjectRefs(value, refs);
      }
    } else if (node is List) {
      for (final item in node) {
        _collectObjectRefs(item, refs);
      }
    }
  }

  /// 递归收集 schema 中的枚举引用
  void _collectEnumRefs(dynamic node, Set<String> refs) {
    if (node is Map<String, dynamic>) {
      final ref = node['\$ref'] as String?;
      if (ref != null) {
        final schemaName = ref.split('/').last;
        final schema = allSchemas[schemaName];
        if (schema != null && schema.containsKey('enum')) {
          refs.add(schemaName);
        }
      }
      for (final value in node.values) {
        _collectEnumRefs(value, refs);
      }
    } else if (node is List) {
      for (final item in node) {
        _collectEnumRefs(item, refs);
      }
    }
  }
}
