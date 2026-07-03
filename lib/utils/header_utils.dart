/// 文件头注释生成工具
library;

/// 写入标准文件头注释
/// [extraDocLines] 追加在 description 之后、library 指令之前的额外文档注释行
void writeFileHeader(StringBuffer buf, String description, {List<String> extraDocLines = const []}) {
  buf.writeln('/// $description');
  for (final line in extraDocLines) {
    buf.writeln('/// $line');
  }
  buf.writeln('/// 此文件由 dart_api_gen 工具自动生成');
  buf.writeln('/// 请勿手动修改');
  buf.writeln('library;');
}
