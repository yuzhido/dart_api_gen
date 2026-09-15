/// $ref 路径提取和 Dto/Enum 后缀处理工具
library;

/// 从 $ref 路径提取 schema 名称
/// 例: '#/components/schemas/UserDto' → 'UserDto'
String extractSchemaName(String ref) {
  if (ref.isEmpty) return '';
  return ref.split('/').last;
}

/// 统一追加 Dto 后缀（即使已以 Dto 结尾也继续追加，与 schemaToClassName 保持一致）
String ensureDtoSuffix(String name) => '${name}Dto';

/// 确保 Enum 后缀
String ensureEnumSuffix(String name) => name.endsWith('Enum') ? name : '${name}Enum';
