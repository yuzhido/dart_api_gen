/// Swagger type → Dart type 映射器
library;

import '../constants/generator_constants.dart';
import 'ref_utils.dart';

class TypeMapper {
  final Map<String, Map<String, dynamic>> schemas;

  TypeMapper(this.schemas);

  /// 判断 schema 是否为 binary 字段（文件上传）
  static bool isBinaryField(Map<String, dynamic> schema) {
    return schema['type'] == 'string' && schema['format'] == 'binary';
  }

  /// 将 Swagger schema 映射为 Dart 类型
  /// [forRequestBody] 是否为请求体，只有请求体中的 binary 字段才映射为 MultipartFile
  String mapType(Map<String, dynamic> schema, {bool forRequestBody = false}) {
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

    // string + binary → MultipartFile（仅请求体中的文件上传字段）
    if (forRequestBody && type == 'string' && schema['format'] == 'binary') {
      return 'MultipartFile';
    }

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

  /// 审计字段强制可空，其他字段仅在显式声明 nullable: true 时可空。
  /// [required] 仅为兼容原有调用保留，不再参与可空判断。
  bool isNullable(Map<String, dynamic> propSchema, String fieldName, [List<String>? required]) {
    return alwaysNullableFields.contains(fieldName) || propSchema['nullable'] == true;
  }

  /// 判断引用的 schema 是否为枚举
  bool _isEnumSchema(String schemaName) {
    final schema = schemas[schemaName];
    if (schema == null) return false;
    return schema.containsKey('enum');
  }
}
