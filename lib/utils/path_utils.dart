/// 相对路径计算工具
library;

/// 计算从 [fromFile] 到 [toFile] 的相对路径
/// [fromFile] 和 [toFile] 均为相对于同一根目录的路径（如 'admin/api_group/index.dart'）
String computeRelativePath(String fromFile, String toFile) {
  final fromParts = fromFile.split('/');
  final toParts = toFile.split('/');

  // 找到共同前缀长度（-1 因为最后是文件名）
  var commonLength = 0;
  while (commonLength < fromParts.length - 1 && commonLength < toParts.length - 1 && fromParts[commonLength] == toParts[commonLength]) {
    commonLength++;
  }

  final upCount = fromParts.length - 1 - commonLength;
  final upPath = upCount > 0 ? '../' * upCount : '';
  final downPath = toParts.skip(commonLength).join('/');
  return '$upPath$downPath';
}
