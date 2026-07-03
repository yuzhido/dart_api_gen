import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:dart_api_gen/config/code_gen_config.dart';

void main() {
  group('CodeGenConfig - YAML 配置加载', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dart_api_gen_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('从 YAML 文件加载完整配置', () {
      final yamlContent = '''
source:
  url: "http://example.com/swagger.json"
output:
  dir: "./generated/api"
options:
  save_swagger_json: false
  generate_enums: false
  generate_index: false
''';
      final file = File('${tempDir.path}/dart_api_gen.yaml');
      file.writeAsStringSync(yamlContent);

      final config = CodeGenConfig.fromFile(file.path);
      expect(config, isNotNull);
      expect(config!.sourceUrl, equals('http://example.com/swagger.json'));
      expect(config.sourceFile, isNull);
      expect(config.outputDir, equals('./generated/api'));
      expect(config.saveSwaggerJson, isFalse);
      expect(config.generateEnums, isFalse);
      expect(config.generateIndex, isFalse);
    });

    test('从 YAML 加载 source.file 配置', () {
      final yamlContent = '''
source:
  file: "./swagger.json"
output:
  dir: "./lib/api"
''';
      final file = File('${tempDir.path}/test.yaml');
      file.writeAsStringSync(yamlContent);

      final config = CodeGenConfig.fromFile(file.path);
      expect(config, isNotNull);
      expect(config!.sourceFile, equals('./swagger.json'));
      expect(config.sourceUrl, isNull);
      expect(config.outputDir, equals('./lib/api'));
      // 默认值
      expect(config.saveSwaggerJson, isTrue);
      expect(config.generateEnums, isTrue);
      expect(config.generateIndex, isTrue);
    });

    test('source 简写形式 - URL', () {
      final yamlContent = '''
source: "http://example.com/swagger.json"
output: "./lib/api"
''';
      final file = File('${tempDir.path}/test.yaml');
      file.writeAsStringSync(yamlContent);

      final config = CodeGenConfig.fromFile(file.path);
      expect(config, isNotNull);
      expect(config!.sourceUrl, equals('http://example.com/swagger.json'));
      expect(config.sourceFile, isNull);
      expect(config.outputDir, equals('./lib/api'));
    });

    test('source 简写形式 - 本地文件', () {
      final yamlContent = '''
source: "./swagger.json"
''';
      final file = File('${tempDir.path}/test.yaml');
      file.writeAsStringSync(yamlContent);

      final config = CodeGenConfig.fromFile(file.path);
      expect(config, isNotNull);
      expect(config!.sourceFile, equals('./swagger.json'));
      expect(config.sourceUrl, isNull);
    });

    test('空 YAML 文件返回默认配置', () {
      final file = File('${tempDir.path}/empty.yaml');
      file.writeAsStringSync('');

      final config = CodeGenConfig.fromFile(file.path);
      expect(config, isNotNull);
      expect(config!.sourceUrl, isNull);
      expect(config.sourceFile, isNull);
      expect(config.outputDir, equals('./lib/api'));
    });

    test('不存在的文件返回 null', () {
      final config = CodeGenConfig.fromFile('${tempDir.path}/not_exist.yaml');
      expect(config, isNull);
    });

    test('只有 options 的配置', () {
      final yamlContent = '''
source:
  url: "http://example.com/swagger.json"
options:
  save_swagger_json: true
  generate_enums: false
''';
      final file = File('${tempDir.path}/test.yaml');
      file.writeAsStringSync(yamlContent);

      final config = CodeGenConfig.fromFile(file.path);
      expect(config, isNotNull);
      expect(config!.saveSwaggerJson, isTrue);
      expect(config.generateEnums, isFalse);
      expect(config.generateIndex, isTrue); // 默认值
    });
  });

  group('CodeGenConfig - CLI 参数覆盖', () {
    test('CLI url 覆盖配置文件 url', () {
      const config = CodeGenConfig(sourceUrl: 'http://old.com/swagger.json');
      final merged = config.mergeWithCli(url: 'http://new.com/swagger.json');
      expect(merged.sourceUrl, equals('http://new.com/swagger.json'));
      expect(merged.sourceFile, isNull);
    });

    test('CLI file 覆盖并清除 url', () {
      const config = CodeGenConfig(sourceUrl: 'http://old.com/swagger.json');
      final merged = config.mergeWithCli(file: './local.json');
      expect(merged.sourceFile, equals('./local.json'));
      expect(merged.sourceUrl, isNull);
    });

    test('CLI url 覆盖并清除 file', () {
      const config = CodeGenConfig(sourceFile: './local.json');
      final merged = config.mergeWithCli(url: 'http://new.com/swagger.json');
      expect(merged.sourceUrl, equals('http://new.com/swagger.json'));
      expect(merged.sourceFile, isNull);
    });

    test('CLI output 覆盖配置', () {
      const config = CodeGenConfig(
        sourceUrl: 'http://example.com',
        outputDir: './old',
      );
      final merged = config.mergeWithCli(output: './new');
      expect(merged.outputDir, equals('./new'));
    });

    test('CLI 不传参数时保留原配置', () {
      const config = CodeGenConfig(
        sourceUrl: 'http://example.com',
        sourceFile: null,
        outputDir: './my_output',
        saveSwaggerJson: false,
        generateEnums: false,
      );
      final merged = config.mergeWithCli();
      expect(merged.sourceUrl, equals('http://example.com'));
      expect(merged.outputDir, equals('./my_output'));
      expect(merged.saveSwaggerJson, isFalse);
      expect(merged.generateEnums, isFalse);
    });
  });

  group('CodeGenConfig - 验证', () {
    test('有 sourceUrl 时配置有效', () {
      const config = CodeGenConfig(sourceUrl: 'http://example.com');
      expect(config.isValid, isTrue);
      expect(config.error, isNull);
    });

    test('有 sourceFile 时配置有效', () {
      const config = CodeGenConfig(sourceFile: './swagger.json');
      expect(config.isValid, isTrue);
      expect(config.error, isNull);
    });

    test('无 source 时配置无效', () {
      const config = CodeGenConfig();
      expect(config.isValid, isFalse);
      expect(config.error, isNotNull);
      expect(config.error, contains('source'));
    });

    test('同时有 url 和 file 时报错', () {
      const config = CodeGenConfig(
        sourceUrl: 'http://example.com',
        sourceFile: './swagger.json',
      );
      expect(config.isValid, isTrue); // isValid 只检查是否有 source
      expect(config.error, isNotNull);
      expect(config.error, contains('不能同时指定'));
    });
  });

  group('CodeGenConfig - findConfigFile', () {
    late Directory tempDir;
    late String originalDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dart_api_gen_config_test_');
      originalDir = Directory.current.path;
    });

    tearDown(() {
      Directory.current = originalDir;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('找到配置文件', () {
      final configFile = File('${tempDir.path}/$configFileName');
      configFile.writeAsStringSync('source: "http://example.com"');
      Directory.current = tempDir;

      final found = CodeGenConfig.findConfigFile();
      expect(found, isNotNull);
      // macOS 的 /var 是 /private/var 的符号链接，需统一解析后比较
      final resolvedTempDir = tempDir.resolveSymbolicLinksSync();
      expect(found, equals(p.join(resolvedTempDir, configFileName)));
    });

    test('未找到配置文件返回 null', () {
      Directory.current = tempDir;
      final found = CodeGenConfig.findConfigFile();
      expect(found, isNull);
    });
  });

  group('CodeGenConfig - toString', () {
    test('输出包含所有配置项', () {
      const config = CodeGenConfig(
        sourceUrl: 'http://example.com/swagger.json',
        outputDir: './lib/api',
        saveSwaggerJson: true,
        generateEnums: true,
        generateIndex: false,
      );
      final str = config.toString();
      expect(str, contains('source.url'));
      expect(str, contains('http://example.com/swagger.json'));
      expect(str, contains('./lib/api'));
      expect(str, contains('save_swagger_json'));
      expect(str, contains('generate_enums'));
      expect(str, contains('generate_index'));
    });

    test('sourceFile 时输出 file 信息', () {
      const config = CodeGenConfig(sourceFile: './swagger.json');
      final str = config.toString();
      expect(str, contains('source.file'));
      expect(str, contains('./swagger.json'));
      expect(str, isNot(contains('source.url')));
    });
  });

  group('CodeGenConfig - 完整 YAML 集成测试', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dart_api_gen_integration_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('加载项目根目录的 dart_api_gen.yaml 并合并 CLI', () {
      // 模拟真实使用场景：先加载 YAML，再用 CLI 覆盖
      final yamlContent = '''
source:
  file: "./example/swagger.json"
output:
  dir: "./output/api"
options:
  save_swagger_json: true
  generate_enums: true
  generate_index: true
''';
      final configFile = File('${tempDir.path}/dart_api_gen.yaml');
      configFile.writeAsStringSync(yamlContent);

      // 1. 从文件加载
      final loaded = CodeGenConfig.fromFile(configFile.path);
      expect(loaded, isNotNull);
      expect(loaded!.sourceFile, equals('./example/swagger.json'));
      expect(loaded.outputDir, equals('./output/api'));

      // 2. CLI 覆盖 url（模拟 --url 参数）
      final merged = loaded.mergeWithCli(url: 'http://override.com/swagger.json');
      expect(merged.sourceUrl, equals('http://override.com/swagger.json'));
      expect(merged.sourceFile, isNull); // url 覆盖后 file 应被清除
      expect(merged.outputDir, equals('./output/api')); // 保留 YAML 配置
      expect(merged.saveSwaggerJson, isTrue); // 保留 YAML 配置
    });

    test('各种 YAML 格式都能正确解析', () {
      // 测试 https URL
      final yaml1 = File('${tempDir.path}/t1.yaml');
      yaml1.writeAsStringSync('source: "https://api.example.com/v2/swagger"');
      final c1 = CodeGenConfig.fromFile(yaml1.path);
      expect(c1!.sourceUrl, equals('https://api.example.com/v2/swagger'));

      // 测试相对路径
      final yaml2 = File('${tempDir.path}/t2.yaml');
      yaml2.writeAsStringSync('source: "../shared/swagger.json"');
      final c2 = CodeGenConfig.fromFile(yaml2.path);
      expect(c2!.sourceFile, equals('../shared/swagger.json'));

      // 测试绝对路径
      final yaml3 = File('${tempDir.path}/t3.yaml');
      yaml3.writeAsStringSync('source: "C:/projects/swagger.json"');
      final c3 = CodeGenConfig.fromFile(yaml3.path);
      expect(c3!.sourceFile, equals('C:/projects/swagger.json'));
    });
  });
}
