/// 枚举文件生成器
import '../utils/naming.dart';

/// 预设颜色循环 (8种)
const _colors = [
  (0xff4F46E5, 0xffe8e5ff), // indigo
  (0xff10B981, 0xffc6f6d5), // green
  (0xffC2410C, 0xfffff3c7), // orange
  (0xffDC2626, 0xfffee2e2), // red
  (0xff0284C7, 0xffe0f2fe), // sky
  (0xff7C3AED, 0xffede9fe), // violet
  (0xffDB2777, 0xfffce7f3), // pink
  (0xff059669, 0xffd1fae5), // emerald
];

class EnumGenerator {
  final Map<String, Map<String, dynamic>> enumSchemas;

  EnumGenerator(this.enumSchemas);

  /// 为指定位置生成枚举文件
  /// 返回: Map<相对路径, 文件内容>
  Map<String, String> generateForLocation(String area, String tagDir, Set<String> enumNames) {
    final result = <String, String>{};

    final buf = StringBuffer();
    buf.writeln('/// $tagDir 相关枚举定义');
    buf.writeln('/// 此文件由 genCode 工具自动生成');
    buf.writeln('/// 请勿手动修改');
    buf.writeln('library;');
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

    if (hasContent) {
      result['$area/$tagDir.dart'] = buf.toString();
    }
    return result;
  }

  /// 生成 common 枚举文件
  /// 返回: Map<相对路径, 文件内容>
  Map<String, String> generateCommon(Set<String> enumNames) {
    final result = <String, String>{};

    final buf = StringBuffer();
    buf.writeln('/// 通用枚举定义');
    buf.writeln('/// 此文件由 genCode 工具自动生成');
    buf.writeln('/// 请勿手动修改');
    buf.writeln('library;');
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

    if (hasContent) {
      result['common.dart'] = buf.toString();
    }
    return result;
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
      final colorIndex = i % _colors.length;
      final color = _colors[colorIndex].$1;
      final bgColor = _colors[colorIndex].$2;

      final colorHex = color.toRadixString(16).substring(2).padLeft(6, '0');
      final bgColorHex = bgColor.toRadixString(16).substring(2).padLeft(6, '0');

      buf.writeln('  @JsonValue($value)');
      // 转义 name 中的 $ 符号，避免 Dart 字符串插值
      final escapedName = name.replaceAll(r'$', r'\$');
      buf.writeln("  $name(name: '$escapedName', value: $value, text: '$text', color: Color(0xff${colorHex.toUpperCase()}), bgColor: Color(0xff${bgColorHex})),");
      buf.writeln();
    }

    // customUnknown 兜底值
    buf.writeln('  @JsonValue(-9999)');
    buf.writeln("  customUnknown(name: 'CustomUnknown', value: -9999, text: '--', color: Color(0xff6B7280), bgColor: Color(0xfff3f4f6));");
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
    buf.write('}');
  }
}
