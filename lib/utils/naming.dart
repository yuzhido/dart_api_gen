/// 命名转换工具
library;

import '../constants/generator_constants.dart';

/// Dart Object 内置属性集合（字段名冲突时需加后缀）
const dartObjectProperties = {'hashCode', 'runtimeType'};

/// 将枚举值名转为合法的 Dart 标识符
/// 处理: Dart 关键字、负数名、非法字符
/// 保留原始驼峰命名（如 IncorrectAccount → incorrectAccount）
String safeEnumName(String rawName) {
  var name = rawName;
  // 处理负数名: value-1 → valueNeg1
  name = name.replaceAll('-', 'Neg');
  // 处理非法字符（保留大小写字母、数字、下划线）
  name = name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
  // 不能以数字开头
  if (name.isNotEmpty && RegExp(r'^[0-9]').hasMatch(name)) {
    name = 'value$name';
  }
  // 如果是 Dart 关键字（全小写匹配），加 $ 前缀
  if (reservedDartKeywords.contains(name.toLowerCase())) {
    name = '\$$name';
  }
  // 空名兜底
  if (name.isEmpty) name = 'unknown';
  return name;
}

/// 转为 PascalCase
String toPascalCase(String input) {
  if (input.isEmpty) return input;
  // 处理 kebab-case, snake_case, 或空格分隔
  final parts = input.split(RegExp(r'[-_\s]+'));
  return parts
      .map((part) {
        if (part.isEmpty) return '';
        return part[0].toUpperCase() + part.substring(1);
      })
      .join('');
}

/// 转为 camelCase
String toCamelCase(String input) {
  final pascal = toPascalCase(input);
  if (pascal.isEmpty) return pascal;
  return pascal[0].toLowerCase() + pascal.substring(1);
}

/// 转为 snake_case
String toSnakeCase(String input) {
  if (input.isEmpty) return input;
  // 处理 PascalCase / camelCase → snake_case
  final result = input.replaceAllMapped(RegExp(r'([A-Z])'), (match) => '_${match.group(0)!.toLowerCase()}').replaceAll(RegExp(r'^_'), '').replaceAll(RegExp(r'-'), '_');
  return result.toLowerCase();
}

/// Tag 名转文件名: DemoUser → demo_user, ApiGroup → api_group
String tagToFileName(String tag) {
  return toSnakeCase(tag);
}

/// Tag 名转分组名: Basic → basic, Admin → admin
String tagToGroupName(String area) {
  return area.toLowerCase();
}

/// Schema 名转 Dart 类名: 统一追加 Dto 后缀（即使原名称已以 Dto 结尾也继续追加）
/// 避免 AssetConfigRetirement 与 AssetConfigRetirementDto 这类 schema 生成同名类
String schemaToClassName(String schemaName) {
  return '$schemaName$dtoSuffix';
}

/// 枚举 Schema 名转 Dart 枚举名: DemoUserType → DemoUserTypeEnum
/// 如果已经以 Enum 结尾则不再追加
String enumSchemaToClassName(String schemaName) {
  if (schemaName.endsWith(enumSuffix)) return schemaName;
  return '$schemaName$enumSuffix';
}

/// Tag 名转 API 类名: DemoUser → DemoUserAPI
String tagToApiClassName(String tag) => '${tag}API';

/// 解析枚举描述字符串
/// 兼容两种格式:
///   1. EnumName:Name1(Text1)=Value1,Name2(Text2)=Value2 (标准格式)
///   2. EnumName:Name1=Value1,Name2=Value2             (简易格式)
// ignore: unintended_html_in_doc_comment
/// 返回: Map<int, EnumValueInfo>
Map<int, EnumValueInfo> parseEnumDescription(String description) {
  final result = <int, EnumValueInfo>{};
  if (description.isEmpty) return result;

  // 找到第一个冒号，后面是枚举值列表
  final colonIndex = description.indexOf(':');
  if (colonIndex == -1) return result;

  var valuesPart = description.substring(colonIndex + 1);

  // 预处理: 把 Key=Value (无括号标签) 补全为 Key(Key)=Value
  // 例如: "Success=0,Fail=1" → "Success(Success)=0,Fail(Fail)=1"
  valuesPart = valuesPart.replaceAllMapped(RegExp(r'(\w+)=(-?\d+)'), (m) => '${m.group(1)}(${m.group(1)})=${m.group(2)}');

  final entries = valuesPart.split(',');

  for (final entry in entries) {
    // 格式: Name(Text)=Value
    final match = RegExp(r'^(\w+)\(([^)]*)\)=(-?\d+)$').firstMatch(entry.trim());
    if (match != null) {
      final name = match.group(1)!;
      final text = match.group(2)!;
      final value = int.parse(match.group(3)!);
      result[value] = EnumValueInfo(name: name, text: text, value: value);
    }
  }

  return result;
}

/// 枚举值信息
class EnumValueInfo {
  final String name;
  final String text;
  final int value;

  EnumValueInfo({required this.name, required this.text, required this.value});
}

/// 从 endpoint 路径生成 inline DTO 名称
/// 取路径最后两段，转大驼峰 + Dto
/// 如果最后两段已包含 tag 信息则不重复添加 tag
/// 例: /api/admin/document-group/batch-delete (tag=DocumentGroup) → DocumentGroupBatchDeleteDto
/// 例: /api/admin/captcha/generate (tag=Captcha) → CaptchaGenerateDto
String inlineDtoName(String tag, String path) {
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  // 取最后两段（如果只有一段就用一段）
  final count = segments.length >= 2 ? 2 : 1;
  final selected = segments.sublist(segments.length - count);
  // 将每段 kebab-case 转为 PascalCase 并拼接
  final operationName = selected.map((s) => toPascalCase(s)).join('');
  // 如果 operationName 已经以 tag 的 PascalCase 开头，不重复添加
  final pascalTag = toPascalCase(tag);
  if (operationName.startsWith(pascalTag)) {
    return '$operationName$dtoSuffix';
  }
  return '$pascalTag$operationName$dtoSuffix';
}
