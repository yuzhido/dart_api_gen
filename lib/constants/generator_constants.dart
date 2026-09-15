/// 代码生成器相关常量
library;

/// Dto 后缀
const dtoSuffix = 'Dto';

/// Enum 后缀
const enumSuffix = 'Enum';

/// 强制可空的审计字段，按原始 JSON 属性名匹配。
const alwaysNullableFields = <String>[
  'createdTime',
  'createdUserId',
  'createdUserName',
  'deleter',
  'deleterId',
  'isDeleted',
  'modifiedTime',
  'modifiedUserId',
  'modifiedUserName',
];

/// 枚举兜底值
const customUnknownValue = -9999;
const customUnknownName = 'customUnknown';
const customUnknownText = '--';
const customUnknownColor = 0xff6B7280;
const customUnknownBgColor = 0xfff3f4f6;

/// Dart 保留字集合
const reservedDartKeywords = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'type',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

/// 预设颜色循环 (8种)
const enumColors = [
  (0xff4F46E5, 0xffe8e5ff), // indigo
  (0xff10B981, 0xffc6f6d5), // green
  (0xffC2410C, 0xfffff3c7), // orange
  (0xffDC2626, 0xfffee2e2), // red
  (0xff0284C7, 0xffe0f2fe), // sky
  (0xff7C3AED, 0xffede9fe), // violet
  (0xffDB2777, 0xfffce7f3), // pink
  (0xff059669, 0xffd1fae5), // emerald
];
