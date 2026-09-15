/// 文件头注释生成工具
library;

/// 将多行文本折叠为单行
/// 换行符（\r\n、\r、\n）统一替换为空格并合并连续空白，
/// 避免 description 中的换行符破坏生成代码的注释语法
String toSingleLine(String text) {
  return text.replaceAll(RegExp(r'[\r\n]+'), ' ').replaceAll(RegExp(r'[ \t]+'), ' ').trim();
}

/// 写入标准文件头注释
/// [extraDocLines] 追加在 description 之后、library 指令之前的额外文档注释行
void writeFileHeader(StringBuffer buf, String description, {List<String> extraDocLines = const []}) {
  buf.writeln('/// ${toSingleLine(description)}');
  for (final line in extraDocLines) {
    buf.writeln('/// ${toSingleLine(line)}');
  }
  buf.writeln('/// 此文件由 dart_api_gen 工具自动生成');
  buf.writeln('/// 请勿手动修改');
  buf.writeln('library;');
}
