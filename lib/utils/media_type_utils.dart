/// 媒体类型选择工具
library;

/// 从 content 对象中选择最合适的媒体类型
/// 优先级: application/json > application/json-patch+json > text/json > 含json的 > 第一个
Map<String, dynamic>? selectMediaType(Map<String, dynamic> content) {
  final json = content['application/json'] as Map<String, dynamic>?;
  if (json != null) return json;
  final jsonPatch = content['application/json-patch+json'] as Map<String, dynamic>?;
  if (jsonPatch != null) return jsonPatch;
  final textJson = content['text/json'] as Map<String, dynamic>?;
  if (textJson != null) return textJson;
  // 匹配 application/*+json
  for (final entry in content.entries) {
    if (entry.key.contains('json')) return entry.value as Map<String, dynamic>?;
  }
  if (content.isNotEmpty) return content.values.first as Map<String, dynamic>?;
  return null;
}

/// 判断 content 是否包含 form-data
bool isFormDataContent(Map<String, dynamic> content) => content.containsKey('multipart/form-data');
