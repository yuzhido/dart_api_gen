/// 枚举文件生成器
library;

import '../utils/naming.dart';
import '../utils/header_utils.dart';
import '../constants/generator_constants.dart';

class EnumGenerator {
  final Map<String, Map<String, dynamic>> enumSchemas;

  EnumGenerator(this.enumSchemas);

  /// 为指定位置生成枚举文件
  /// 返回: Map<相对路径, 文件内容>
  Map<String, String> generateForLocation(String area, String tagDir, Set<String> enumNames) {
    final content = _buildEnumFile('$tagDir 相关枚举定义', enumNames);
    if (content == null) return {};
    return {'$area/$tagDir.dart': content};
  }

  /// 生成 common 枚举文件
  /// 返回: Map<相对路径, 文件内容>
  Map<String, String> generateCommon(Set<String> enumNames) {
    final content = _buildEnumFile('通用枚举定义', enumNames);
    if (content == null) return {};
    return {'common.dart': content};
  }

  /// 构建枚举文件内容，若无有效枚举则返回 null
  String? _buildEnumFile(String headerDesc, Set<String> enumNames) {
    final buf = StringBuffer();
    writeFileHeader(buf, headerDesc);
    buf.writeln();
    buf.writeln("import 'package:flutter/material.dart';");
    buf.writeln("import 'package:json_annotation/json_annotation.dart';");

    var hasContent = false;
    for (final enumName in enumNames) {
      final schema = enumSchemas[enumName];
      if (schema == null) continue;
      if (!schema.containsKey('enum')) continue;

      buf.writeln();
      _generateEnum(buf, enumName, schema);
      hasContent = true;
    }

    return hasContent ? buf.toString() : null;
  }

  void _generateEnum(StringBuffer buf, String schemaName, Map<String, dynamic> schema) {
    final description = schema['description'] as String? ?? '';
    final enumValues = schema['enum'] as List<dynamic>;
    final className = enumSchemaToClassName(schemaName);

    // 解析枚举值描述
    final valueMap = parseEnumDescription(description);

    // 注释
    if (description.isNotEmpty) {
      buf.writeln('/// $description');
    }

    buf.writeln('enum $className {');

    // 生成每个枚举值
    for (var i = 0; i < enumValues.length; i++) {
      final value = enumValues[i] is int ? enumValues[i] as int : int.tryParse(enumValues[i].toString()) ?? i;
      final info = valueMap[value];
      // 使用 camelCase (首字母小写，其余不变)，和 TS 版本一致
      final rawName = info != null ? (info.name[0].toLowerCase() + info.name.substring(1)) : 'value$value';
      final name = safeEnumName(rawName);
      final text = info?.text ?? '$value';
      final colorIndex = i % enumColors.length;
      final color = enumColors[colorIndex].$1;
      final bgColor = enumColors[colorIndex].$2;

      final colorHex = color.toRadixString(16).substring(2).padLeft(6, '0');
      final bgColorHex = bgColor.toRadixString(16).substring(2).padLeft(6, '0');

      buf.writeln('  @JsonValue($value)');
      // 转义 name 中的 $ 符号，避免 Dart 字符串插值
      final escapedName = name.replaceAll(r'$', r'\$');
      buf.writeln("  $name(name: '$escapedName', value: $value, text: '$text', color: Color(0xff${colorHex.toUpperCase()}), bgColor: Color(0xff${bgColorHex})),");
      buf.writeln();
    }

    // customUnknown 兜底值
    buf.writeln('  @JsonValue($customUnknownValue)');
    buf.writeln(
      "  $customUnknownName(name: '$customUnknownName', value: $customUnknownValue, text: '$customUnknownText', color: Color(0x${customUnknownColor.toRadixString(16).toUpperCase()}), bgColor: Color(0x${customUnknownBgColor.toRadixString(16).toUpperCase()}));",
    );
    buf.writeln();

    // 字段声明
    buf.writeln('  final String name;');
    buf.writeln('  final int value;');
    buf.writeln('  final String text;');
    buf.writeln('  final Color color;');
    buf.writeln('  final Color bgColor;');
    buf.writeln();

    // 构造函数
    buf.writeln('  const $className({required this.name, required this.value, required this.text, required this.color, required this.bgColor});');
    buf.writeln();

    // 静态方法 list()
    buf.writeln('  // 添加静态方法获取枚举列表');
    buf.writeln('  static List<$className> list() {');
    final names = <String>[];
    for (final value in enumValues) {
      final v = value is int ? value : int.tryParse(value.toString()) ?? 0;
      final info = valueMap[v];
      final rawName = info != null ? (info.name[0].toLowerCase() + info.name.substring(1)) : 'value$v';
      names.add(safeEnumName(rawName));
    }
    buf.writeln('    return [${names.map((n) => '$className.$n').join(', ')}];');
    buf.writeln('  }');
    buf.writeln('}');
  }
}
