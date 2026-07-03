/// 相对路径计算工具
library;

/// 计算从 [fromFile] 到 [toFile] 的相对路径
/// [fromFile] 和 [toFile] 均为相对于同一根目录的路径（如 'admin/api_group/index.dart'）
String computeRelativePath(String fromFile, String toFile) {
  final fromParts = fromFile.split('/');
  final toParts = toFile.split('/');

  // 找到共同前缀长度（-1 因为最后是文件名）
  var commonLen = 0;
  while (commonLen < fromParts.length - 1 && commonLen < toParts.length - 1 && fromParts[commonLen] == toParts[commonLen]) {
    commonLen++;
  }

  final upCount = fromParts.length - 1 - commonLen;
  final upPath = upCount > 0 ? '../' * upCount : '';
  final downPath = toParts.skip(commonLen).join('/');
  return '$upPath$downPath';
}
