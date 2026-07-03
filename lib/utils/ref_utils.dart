/// $ref 路径提取和 Dto/Enum 后缀处理工具
library;

/// 从 $ref 路径提取 schema 名称
/// 例: '#/components/schemas/UserDto' → 'UserDto'
String extractSchemaName(String ref) {
  if (ref.isEmpty) return '';
  return ref.split('/').last;
}

/// 确保 Dto 后缀
String ensureDtoSuffix(String name) => name.endsWith('Dto') ? name : '${name}Dto';

/// 确保 Enum 后缀
String ensureEnumSuffix(String name) => name.endsWith('Enum') ? name : '${name}Enum';
