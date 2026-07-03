/// Swagger type → Dart type 映射器
library;

import 'ref_utils.dart';

class TypeMapper {
  final Map<String, Map<String, dynamic>> schemas;

  TypeMapper(this.schemas);

  /// 将 Swagger schema 映射为 Dart 类型
  String mapType(Map<String, dynamic> schema) {
    // 处理 $ref
    if (schema.containsKey('\$ref')) {
      final ref = schema['\$ref'] as String;
      final refName = extractSchemaName(ref);

      // JToken 自引用降级为 dynamic（避免编译错误）
      if (refName == 'JToken') {
        return 'dynamic';
      }

      // 判断是否为枚举类型
      if (_isEnumSchema(refName)) {
        return ensureEnumSuffix(refName);
      }
      return ensureDtoSuffix(refName);
    }

    // 处理 array
    if (schema['type'] == 'array') {
      final items = schema['items'] as Map<String, dynamic>?;
      if (items != null) {
        // JToken 数组项降级
        if (items.containsKey('\$ref')) {
          final itemRef = items['\$ref'] as String;
          final itemRefName = extractSchemaName(itemRef);
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
