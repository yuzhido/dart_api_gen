/// 代码生成器配置类
/// 支持从 YAML 配置文件加载，CLI 参数可覆盖配置
library;

import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

import '../constants/swagger_constants.dart' as swagger_constants;
import '../constants/config_template.dart';

/// 配置文件名
const String configFileName = swagger_constants.configFileName;

/// 代码生成器配置
class CodeGenConfig {
  /// Swagger JSON 来源 URL
  final String? sourceUrl;

  /// Swagger JSON 本地文件路径
  final String? sourceFile;

  /// 输出目录
  final String outputDir;

  /// 是否保存原始 swagger JSON
  final bool saveSwaggerJson;

  /// 是否生成 controller 文件
  final bool generateControllers;

  /// 是否生成 enum 文件
  final bool generateEnums;

  /// 是否生成 types 类型模型文件
  final bool generateTypes;

  /// 是否生成 index 导出文件
  final bool generateIndex;

  /// 是否覆盖已存在的生成文件
  /// true: 每次生成时先删除已有文件再重新生成
  /// false: 已有文件则跳过不覆盖
  final bool overwrite;

  /// 是否在生成完成后自动执行 build_runner
  /// true: 生成完成后执行 dart run build_runner build --delete-conflicting-outputs
  /// false: 仅生成代码，不执行 build_runner（需手动运行）
  final bool runBuildRunner;

  const CodeGenConfig({
    this.sourceUrl,
    this.sourceFile,
    this.outputDir = swagger_constants.defaultOutputDir,
    this.saveSwaggerJson = true,
    this.generateControllers = true,
    this.generateEnums = true,
    this.generateTypes = true,
    this.generateIndex = true,
    this.overwrite = true,
    this.runBuildRunner = true,
  });

  /// 从 YAML 文件加载配置
  /// 返回 null 如果文件不存在
  static CodeGenConfig? fromFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final content = file.readAsStringSync();
    final yaml = loadYaml(content);
    if (yaml == null) return const CodeGenConfig();

    return fromYaml(yaml);
  }

  /// 从 YAML 内容解析配置
  static CodeGenConfig fromYaml(dynamic yaml) {
    if (yaml is! YamlMap) return const CodeGenConfig();

    // 解析 source 部分
    String? sourceUrl;
    String? sourceFile;
    final source = yaml['source'];
    if (source is YamlMap) {
      sourceUrl = source['url'] as String?;
      sourceFile = source['file'] as String?;
    } else if (source is String) {
      // 简写形式: source: "http://..." 或 source: "./swagger.json"
      if (source.startsWith('http://') || source.startsWith('https://')) {
        sourceUrl = source;
      } else {
        sourceFile = source;
      }
    }

    // 解析 output 部分
    String outputDir = swagger_constants.defaultOutputDir;
    final output = yaml['output'];
    if (output is YamlMap) {
      outputDir = output['dir'] as String? ?? swagger_constants.defaultOutputDir;
    } else if (output is String) {
      outputDir = output;
    }

    // 解析 options 部分
    bool saveSwaggerJson = true;
    bool generateControllers = true;
    bool generateEnums = true;
    bool generateTypes = true;
    bool generateIndex = true;
    bool overwrite = true;
    bool runBuildRunner = true;
    final options = yaml['options'];
    if (options is YamlMap) {
      saveSwaggerJson = options['save_swagger_json'] as bool? ?? true;
      generateControllers = options['generate_controllers'] as bool? ?? true;
      generateEnums = options['generate_enums'] as bool? ?? true;
      generateTypes = options['generate_types'] as bool? ?? true;
      generateIndex = options['generate_index'] as bool? ?? true;
      overwrite = options['overwrite'] as bool? ?? true;
      runBuildRunner = options['run_build_runner'] as bool? ?? true;
    }

    return CodeGenConfig(
      sourceUrl: sourceUrl,
      sourceFile: sourceFile,
      outputDir: outputDir,
      saveSwaggerJson: saveSwaggerJson,
      generateControllers: generateControllers,
      generateEnums: generateEnums,
      generateTypes: generateTypes,
      generateIndex: generateIndex,
      overwrite: overwrite,
      runBuildRunner: runBuildRunner,
    );
  }

  /// 用 CLI 参数覆盖配置（CLI 优先级更高）
  /// 当指定 url 时清除 file，指定 file 时清除 url
  CodeGenConfig mergeWithCli({String? url, String? file, String? output}) {
    return CodeGenConfig(
      sourceUrl: url ?? (file != null ? null : sourceUrl),
      sourceFile: file ?? (url != null ? null : sourceFile),
      outputDir: output ?? outputDir,
      saveSwaggerJson: saveSwaggerJson,
      generateControllers: generateControllers,
      generateEnums: generateEnums,
      generateTypes: generateTypes,
      generateIndex: generateIndex,
      overwrite: overwrite,
      runBuildRunner: runBuildRunner,
    );
  }

  /// 在当前目录查找配置文件
  static String? findConfigFile() {
    // 从当前工作目录查找
    final cwd = Directory.current.path;
    final configPath = p.join(cwd, configFileName);
    if (File(configPath).existsSync()) return configPath;
    return null;
  }

  /// 验证配置是否有效
  bool get isValid => sourceUrl != null || sourceFile != null;

  /// 获取错误信息
  String? get error {
    if (!isValid) {
      return '请指定 Swagger JSON 来源：在配置文件中设置 source.url 或 source.file，或使用 --url/--file 参数';
    }
    if (sourceUrl != null && sourceFile != null) {
      return 'source.url 和 source.file 不能同时指定，请只保留一个';
    }
    return null;
  }

  /// 生成带有完整注释的默认配置文件内容
  static String generateDefaultConfigContent() => defaultConfigTemplate;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('CodeGenConfig:');
    if (sourceUrl != null) buffer.writeln('  source.url: $sourceUrl');
    if (sourceFile != null) buffer.writeln('  source.file: $sourceFile');
    buffer.writeln('  output.dir: $outputDir');
    buffer.writeln('  options.save_swagger_json: $saveSwaggerJson');
    buffer.writeln('  options.generate_controllers: $generateControllers');
    buffer.writeln('  options.generate_enums: $generateEnums');
    buffer.writeln('  options.generate_types: $generateTypes');
    buffer.writeln('  options.generate_index: $generateIndex');
    buffer.writeln('  options.overwrite: $overwrite');
    buffer.writeln('  options.run_build_runner: $runBuildRunner');
    return buffer.toString();
  }
}
