/// Swagger type → Dart type 映射器

class TypeMapper {
  final Map<String, Map<String, dynamic>> schemas;

  TypeMapper(this.schemas);

  /// 将 Swagger schema 映射为 Dart 类型
  String mapType(Map<String, dynamic> schema) {
    // 处理 $ref
    if (schema.containsKey('\$ref')) {
      final ref = schema['\$ref'] as String;
      final refName = ref.split('/').last;

      // JToken 自引用降级为 dynamic（避免编译错误）
      if (refName == 'JToken') {
        return 'dynamic';
      }

      // 判断是否为枚举类型
      if (_isEnumSchema(refName)) {
        return refName.endsWith('Enum') ? refName : '${refName}Enum';
      }
      return refName.endsWith('Dto') ? refName : '${refName}Dto';
    }

    // 处理 array
    if (schema['type'] == 'array') {
      final items = schema['items'] as Map<String, dynamic>?;
      if (items != null) {
        // JToken 数组项降级
        if (items.containsKey('\$ref')) {
          final itemRef = items['\$ref'] as String;
          final itemRefName = itemRef.split('/').last;
          if (itemRefName == 'JToken') {
            return 'List<dynamic>';
          }
        }
        final itemType = mapType(items);
        return 'List<$itemType>';
      }
      return 'List<dynamic>';
    }

    // 处理基本类型
    final type = schema['type'] as String? ?? 'dynamic';

    switch (type) {
      case 'string':
        return 'String';
      case 'integer':
        return 'int';
      case 'number':
        return 'double';
      case 'boolean':
        return 'bool';
      case 'object':
        // additionalProperties → Map<String, valueType>
        final additionalProps = schema['additionalProperties'] as Map<String, dynamic>?;
        if (additionalProps != null && additionalProps.isNotEmpty) {
          final valueType = mapType(additionalProps);
          return 'Map<String, $valueType>';
        }
        return 'Map<String, dynamic>';
      default:
        return 'dynamic';
    }
  }

  /// 判断字段是否 nullable
  bool isNullable(Map<String, dynamic> propSchema, String fieldName, List<String>? required) {
    // 如果 explicitly nullable
    if (propSchema['nullable'] == true) return true;
    // 如果不在 required 列表中
    if (required != null && !required.contains(fieldName)) return true;
    return false;
  }

  /// 判断引用的 schema 是否为枚举
  bool _isEnumSchema(String schemaName) {
    final schema = schemas[schemaName];
    if (schema == null) return false;
    return schema.containsKey('enum');
  }
}

/// 字段信息
class FieldInfo {
  final String name;
  final String type;
  final bool isRequired;
  final String description;
  final String jsonName;

  FieldInfo({
    required this.name,
    required this.type,
    required this.isRequired,
    required this.description,
    required this.jsonName,
  });

  /// 是否为枚举类型字段
  bool get isEnum => type.endsWith('Enum');

  /// 获取引用的枚举 schema 名 (去掉末尾 Enum 后缀)
  String? get enumSchemaName {
    if (!isEnum) return null;
    if (type.endsWith('Enum')) return type.substring(0, type.length - 4);
    return type;
  }
}
