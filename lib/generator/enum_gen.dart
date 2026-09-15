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
    return {'common_enum.dart': content};
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
    // 名称 → info 映射（小写），用于字符串枚举按名称查找真实数值
    final nameMap = <String, EnumValueInfo>{};
    for (final info in valueMap.values) {
      nameMap[info.name.toLowerCase()] = info;
    }

    // 注释
    if (description.isNotEmpty) {
      buf.writeln('/// ${toSingleLine(description)}');
    }

    buf.writeln('enum $className {');

    // 生成每个枚举值
    for (var i = 0; i < enumValues.length; i++) {
      final rawValue = enumValues[i];
      // 字符串枚举先按名称匹配，获取 description 中定义的真实数值
      EnumValueInfo? nameMatch;
      if (rawValue is String) {
        nameMatch = nameMap[rawValue.toLowerCase()];
      }
      final value = nameMatch?.value ?? _resolveEnumValue(rawValue, i);
      final info = valueMap[value];
      // 名称优先使用枚举值字符串本身保持原始大小写风格
      final rawName = nameMatch != null
          ? (nameMatch.name[0].toLowerCase() + nameMatch.name.substring(1))
          : (info != null ? (info.name[0].toLowerCase() + info.name.substring(1)) : 'value$value');
      final name = safeEnumName(rawName);
      final text = info?.text ?? nameMatch?.text ?? '$value';
      final colorIndex = i % enumColors.length;
      final color = enumColors[colorIndex].$1;
      final bgColor = enumColors[colorIndex].$2;

      final colorHex = color.toRadixString(16).substring(2).padLeft(6, '0');
      final bgColorHex = bgColor.toRadixString(16).substring(2).padLeft(6, '0');

      buf.writeln('  @JsonValue($value)');
      // 转义字符串中的特殊字符，避免破坏生成的 Dart 字面量
      final escapedName = _escapeDartString(name);
      final escapedText = _escapeDartString(toSingleLine(text));
      buf.writeln("  $name(name: '$escapedName', value: $value, text: '$escapedText', color: Color(0xff${colorHex.toUpperCase()}), bgColor: Color(0xff$bgColorHex)),");
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
    for (var i = 0; i < enumValues.length; i++) {
      final rawValue = enumValues[i];
      EnumValueInfo? nameMatch;
      if (rawValue is String) {
        nameMatch = nameMap[rawValue.toLowerCase()];
      }
      final v = nameMatch?.value ?? _resolveEnumValue(rawValue, i);
      final info = valueMap[v];
      final rawName = nameMatch != null
          ? (nameMatch.name[0].toLowerCase() + nameMatch.name.substring(1))
          : (info != null ? (info.name[0].toLowerCase() + info.name.substring(1)) : 'value$v');
      names.add(safeEnumName(rawName));
    }
    buf.writeln('    return [${names.map((n) => '$className.$n').join(', ')}];');
    buf.writeln('  }');
    buf.writeln('}');
  }

  /// 解析枚举元素对应的整数值：数字字面量直接使用，否则回退为元素索引
  int _resolveEnumValue(dynamic raw, int index) {
    return raw is int ? raw : int.tryParse(raw.toString()) ?? index;
  }

  /// 转义 Dart 单引号字符串中的反斜杠、单引号和 $ 符号
  String _escapeDartString(String text) {
    return text.replaceAll('\\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$');
  }
}
