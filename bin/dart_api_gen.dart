/// Dart API 代码生成工具 - CLI 入口
/// 从 Swagger/OpenAPI JSON 生成 Dart API 控制器、数据模型和枚举定义
library;

import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'package:dart_api_gen/utils/type_mapper.dart';
import 'package:dart_api_gen/generator/enum_gen.dart';
import 'package:dart_api_gen/generator/types_gen.dart';
import 'package:dart_api_gen/generator/index_gen.dart';
import 'package:dart_api_gen/parser/swagger_parser.dart';
import 'package:dart_api_gen/config/code_gen_config.dart';
import 'package:dart_api_gen/generator/controller_gen.dart';
import 'package:dart_api_gen/parser/swagger_processor.dart';
import 'package:dart_api_gen/parser/processed_swagger_loader.dart';

Future<void> main(List<String> arguments) async {
  // 检查子命令
  if (arguments.isNotEmpty && arguments.first == 'init') {
    // 处理 init 子命令: 生成带完整注释的默认配置文件
    // 支持 -c 指定路径: dart_api_gen init -c path/to/config.yaml
    final initArgParser = ArgParser()
      ..addOption('config', abbr: 'c', help: '配置文件路径', defaultsTo: configFileName)
      ..addFlag('force', abbr: 'f', help: '强制覆盖已存在的配置文件', negatable: false);
    final initResults = initArgParser.parse(arguments.sublist(1));
    final initPath = initResults['config'] as String;
    final force = initResults['force'] as bool;
    final initFile = File(initPath);
    if (initFile.existsSync() && !force) {
      print('⚠️  配置文件已存在: $initPath');
      print('   使用 -f 或 --force 强制覆盖');
      exit(1);
    }
    initFile.writeAsStringSync(CodeGenConfig.generateDefaultConfigContent());
    print('✅ 已生成默认配置文件: $initPath');
    print('   请根据需要修改配置项后运行 dart_api_gen');
    return;
  }

  final argParser = ArgParser()
    ..addOption('url', abbr: 'u', help: 'Swagger JSON URL (覆盖配置文件)')
    ..addOption('file', abbr: 'f', help: 'Swagger JSON 文件路径 (覆盖配置文件)')
    ..addOption('output', abbr: 'o', help: '输出目录路径 (覆盖配置文件)')
    ..addOption('config', abbr: 'c', help: '配置文件路径', defaultsTo: configFileName)
    ..addFlag('help', abbr: 'h', help: '显示帮助信息', negatable: false);

  final results = argParser.parse(arguments);

  if (results['help'] as bool) {
    print('Dart API 代码生成工具');
    print('用法: dart_api_gen <command> [options]');
    print('');
    print('命令:');
    print('  init              在当前目录生成带完整注释的默认配置文件');
    print('');
    print('配置文件: 在当前目录查找 $configFileName，CLI 参数优先级高于配置文件');
    print(argParser.usage);
    return;
  }

  // 1. 加载配置文件
  final configPath = results['config'] as String;
  CodeGenConfig config = const CodeGenConfig();
  final foundConfigPath = CodeGenConfig.findConfigFile() ?? (File(configPath).existsSync() ? configPath : null);

  if (foundConfigPath != null) {
    final loaded = CodeGenConfig.fromFile(foundConfigPath);
    if (loaded != null) {
      config = loaded;
      print('📄 已加载配置文件: $foundConfigPath');
    }
  }

  // 2. CLI 参数覆盖配置
  config = config.mergeWithCli(url: results['url'] as String?, file: results['file'] as String?, output: results['output'] as String?);

  // 3. 验证配置
  final configError = config.error;
  if (configError != null) {
    print('❌ 配置错误: $configError');
    print(argParser.usage);
    exit(1);
  }

  print('⚙️  当前配置:');
  print(config.toString());

  final url = config.sourceUrl;
  final filePath = config.sourceFile;
  final outputDir = config.outputDir;

  // 4. 解析 Swagger JSON
  print('📖 正在解析 Swagger JSON...');
  final parser = SwaggerParser();
  if (url != null) {
    print('   URL: $url');
    await parser.loadFromUrl(url);
  } else {
    print('   文件: $filePath');
    await parser.loadFromFile(filePath!);
  }

  // 保存原始 swagger JSON 到输出目录的 temp-swagger-data/index.json
  String? swaggerDir;
  final absOutputDirForSwagger = p.normalize(p.absolute(outputDir));
  final tempSwaggerDir = p.join(absOutputDirForSwagger, 'temp-swagger-data');
  if (config.saveSwaggerJson) {
    swaggerDir = tempSwaggerDir;
    Directory(swaggerDir).createSync(recursive: true);
    final swaggerJsonFile = p.join(swaggerDir, 'index.json');
    File(swaggerJsonFile).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(parser.rawDoc));
    print('   💾 Swagger JSON 已保存: $swaggerJsonFile');
  } else {
    // save_swagger_json: false 时，删除 temp-swagger-data 目录（如果存在）
    if (Directory(tempSwaggerDir).existsSync()) {
      Directory(tempSwaggerDir).deleteSync(recursive: true);
      print('   🗑️  已清理 temp-swagger-data 目录 (save_swagger_json: false)');
    }
  }

  // 4.5 处理 Swagger JSON → processSwagger.json (始终在内存中处理)
  print('🔄 正在处理 Swagger 数据...');
  final processor = SwaggerProcessor();
  final processedSwagger = processor.process(parser.rawDoc);
  if (config.saveSwaggerJson && swaggerDir != null) {
    final processedJsonFile = p.join(swaggerDir, 'processSwagger.json');
    File(processedJsonFile).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(processedSwagger));
    print('   💾 处理后数据已保存: $processedJsonFile');
  }

  // 5. 从处理后的数据加载
  print('📦 正在加载处理后的 Swagger 数据...');
  final loader = ProcessedSwaggerLoader();
  loader.loadFromMap(processedSwagger);

  // 6. 计算分组
  print('🔍 正在分析 API 结构...');
  final classification = loader.classifyTypes();
  final typeLocations = loader.computeTypeLocations();
  final controllerLocations = loader.computeControllerLocations();
  final typeMapper = TypeMapper(loader.schemas);

  final enumNames = classification.enums;
  final objectNames = classification.objects;

  // 按位置分组枚举（key 与 TypeLocation.key 保持一致）
  final enumsByLocation = <String, Set<String>>{};
  for (final name in enumNames) {
    final loc = typeLocations[name];
    if (loc == null) continue;
    enumsByLocation.putIfAbsent(loc.key, () => {}).add(name);
  }

  // 按位置分组对象（key 与 TypeLocation.key 保持一致）
  final objectsByLocation = <String, Set<String>>{};
  for (final name in objectNames) {
    final loc = typeLocations[name];
    if (loc == null) continue;
    objectsByLocation.putIfAbsent(loc.key, () => {}).add(name);
  }

  print('   发现 ${loader.apiEntries.length} 个 API 分组');
  print('   发现 ${objectNames.length} 个数据模型, ${enumNames.length} 个枚举');
  print('   位置分组: ${objectsByLocation.length} 个 types 位置, ${enumsByLocation.length} 个 enum 位置');

  // 7. Inline DTOs 已在 processSwagger.json 的 typesInfo 中，无需额外收集

  // 8. 生成代码文件
  print('🔨 正在生成代码...');
  final absOutputDir = p.normalize(p.absolute(outputDir));
  final enumGen = EnumGenerator(loader.schemas);
  final typesGen = TypesGenerator(loader.schemas, typeMapper);
  final controllerGen = ControllerGenerator(typeMapper);
  final indexGen = IndexGenerator();

  // 创建输出目录
  Directory(absOutputDir).createSync(recursive: true);

  // overwrite=true 时先清理输出目录中已有的生成文件（temp-swagger-data 为中间产物，不参与清理）
  final overwrite = config.overwrite;
  if (overwrite) {
    for (final subDir in ['controller', 'types', 'enum']) {
      final dir = Directory(p.join(absOutputDir, subDir));
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }
    print('   🗑️  已清理旧的生成文件 (overwrite: true)');
  }

  // 记录生成的文件路径（用于 index 文件）
  final generatedControllerPaths = <String>{};
  final generatedEnumPaths = <String>{};
  final generatedTypesPaths = <String>{};

  // 构建 enumName → enum 文件相对路径映射
  // key 格式：'__common__' (跨area) | '{area}/__common__' (area内共用) | '{area}/{tag}'
  final enumLocationMap = <String, String>{};
  for (final entry in enumsByLocation.entries) {
    final locationKey = entry.key;
    for (final enumName in entry.value) {
      String enumPath;
      if (locationKey == '__common__') {
        enumPath = 'common_enum.dart';
      } else if (locationKey.endsWith('/__common__')) {
        final area = locationKey.split('/').first;
        enumPath = '$area/common_enum.dart';
      } else {
        enumPath = '$locationKey.dart';
      }
      enumLocationMap[enumName] = enumPath;
    }
  }

  // 构建 schemaName → types 文件相对路径映射
  final schemaLocationMap = <String, String>{};
  for (final entry in objectsByLocation.entries) {
    final locationKey = entry.key;
    for (final schemaName in entry.value) {
      String typePath;
      if (locationKey == '__common__') {
        typePath = 'common_type/index.dart';
      } else if (locationKey.endsWith('/__common__')) {
        final area = locationKey.split('/').first;
        typePath = '$area/common_type/index.dart';
      } else {
        typePath = '$locationKey/index.dart';
      }
      schemaLocationMap[schemaName] = typePath;
    }
  }

  // 8.1 生成 Controller 文件
  if (config.generateControllers) {
    for (final entry in loader.apiEntries) {
      final loc = controllerLocations[entry.tagName];
      if (loc == null) continue;

      final dir = p.join(absOutputDir, 'controller', loc.area);
      Directory(dir).createSync(recursive: true);

      final content = controllerGen.generateForTag(entry);
      final filePath = p.join(dir, '${loc.fileName}.dart');
      final relPath = '${loc.area}/${loc.fileName}.dart';
      if (!overwrite && File(filePath).existsSync()) {
        print('   ⏭️  跳过 controller/$relPath (已存在)');
      } else {
        File(filePath).writeAsStringSync(content);
        print('   ✅ controller/$relPath');
      }
      generatedControllerPaths.add(relPath);
    }
  } else {
    print('   ⏭️  跳过 Controller 生成 (generate_controllers: false)');
  }

  // 8.2 生成 Enum 文件
  if (config.generateEnums) {
    for (final entry in enumsByLocation.entries) {
      final locationKey = entry.key;
      final names = entry.value;

      if (locationKey == '__common__') {
        // 跨 area 共用枚举 → enum/common_enum.dart
        Directory(p.join(absOutputDir, 'enum')).createSync(recursive: true);
        final files = enumGen.generateCommon(names);
        for (final fileEntry in files.entries) {
          final filePath = p.join(absOutputDir, 'enum', fileEntry.key);
          File(filePath).writeAsStringSync(fileEntry.value);
          print('   ✅ enum/${fileEntry.key}');
          generatedEnumPaths.add(fileEntry.key);
        }
      } else if (locationKey.endsWith('/__common__')) {
        // 单 area 内多 tag 共用枚举 → enum/{area}/common_enum.dart
        final area = locationKey.split('/').first;
        final dir = p.join(absOutputDir, 'enum', area);
        Directory(dir).createSync(recursive: true);
        final files = enumGen.generateCommon(names);
        for (final fileEntry in files.entries) {
          final absFilePath = p.join(absOutputDir, 'enum', area, fileEntry.key);
          File(absFilePath).writeAsStringSync(fileEntry.value);
          print('   ✅ enum/$area/${fileEntry.key}');
          generatedEnumPaths.add('$area/${fileEntry.key}');
        }
      } else {
        final parts = locationKey.split('/');
        final area = parts[0];
        final tagDir = parts[1];
        final dir = p.join(absOutputDir, 'enum', area);
        Directory(dir).createSync(recursive: true);
        final files = enumGen.generateForLocation(area, tagDir, names);
        for (final fileEntry in files.entries) {
          final filePath = p.join(absOutputDir, 'enum', fileEntry.key);
          File(filePath).writeAsStringSync(fileEntry.value);
          print('   ✅ enum/${fileEntry.key}');
          generatedEnumPaths.add(fileEntry.key);
        }
      }
    }
  } else {
    print('   ⏭️  跳过枚举生成 (generate_enums: false)');
  }

  // 8.3 生成 Types 文件
  if (config.generateTypes) {
    for (final entry in objectsByLocation.entries) {
      final locationKey = entry.key;
      final names = entry.value;

      if (locationKey == '__common__') {
        // 跨 area 共用类型 → types/common_type/index.dart
        final dir = p.join(absOutputDir, 'types', 'common_type');
        Directory(dir).createSync(recursive: true);
        final crossAreaEnums = enumsByLocation['__common__'] ?? {};
        final content = typesGen.generateCommon(
          names, crossAreaEnums,
          filePath: 'common_type/index.dart',
          description: '跨服务通用数据模型类型定义',
          schemaLocationMap: schemaLocationMap,
          enumLocationMap: enumLocationMap,
        );
        final filePath = p.join(dir, 'index.dart');
        if (!overwrite && File(filePath).existsSync()) {
          print('   ⏭️  跳过 types/common_type/index.dart (已存在)');
        } else {
          File(filePath).writeAsStringSync(content);
          print('   ✅ types/common_type/index.dart');
        }
        generatedTypesPaths.add('common_type/index.dart');
      } else if (locationKey.endsWith('/__common__')) {
        // 单 area 内多 tag 共用类型 → types/{area}/common_type/index.dart
        final area = locationKey.split('/').first;
        final dir = p.join(absOutputDir, 'types', area, 'common_type');
        Directory(dir).createSync(recursive: true);
        final areaCommonEnums = enumsByLocation[locationKey] ?? {};
        final relPath = '$area/common_type/index.dart';
        final content = typesGen.generateCommon(
          names, areaCommonEnums,
          filePath: relPath,
          description: 'xArea: $area 服务下通用数据模型类型定义',
          schemaLocationMap: schemaLocationMap,
          enumLocationMap: enumLocationMap,
        );
        final filePath = p.join(dir, 'index.dart');
        if (!overwrite && File(filePath).existsSync()) {
          print('   ⏭️  跳过 types/$relPath (已存在)');
        } else {
          File(filePath).writeAsStringSync(content);
          print('   ✅ types/$relPath');
        }
        generatedTypesPaths.add(relPath);
      } else {
        // 单 area 单 tag → types/{area}/{tag}/index.dart
        final parts = locationKey.split('/');
        final area = parts[0];
        final tagDir = parts[1];
        final dir = p.join(absOutputDir, 'types', area, tagDir);
        Directory(dir).createSync(recursive: true);
        final locationEnums = enumsByLocation[locationKey] ?? {};
        final content = typesGen.generateForLocation(area, tagDir, names, locationEnums, [], schemaLocationMap: schemaLocationMap, enumLocationMap: enumLocationMap);
        final filePath = p.join(dir, 'index.dart');
        final relPath = '$area/$tagDir/index.dart';
        if (!overwrite && File(filePath).existsSync()) {
          print('   ⏭️  跳过 types/$relPath (已存在)');
        } else {
          File(filePath).writeAsStringSync(content);
          print('   ✅ types/$relPath');
        }
        generatedTypesPaths.add(relPath);
      }
    }
  } else {
    print('   ⏭️  跳过 Types 生成 (generate_types: false)');
  }

  // 8.4 生成 Index 导出文件
  if (config.generateIndex) {
    if (config.generateControllers && generatedControllerPaths.isNotEmpty) {
      final content = indexGen.generateControllerIndex(generatedControllerPaths);
      File(p.join(absOutputDir, 'controller', 'index.dart')).writeAsStringSync(content);
      print('   ✅ controller/index.dart');
    }

    if (config.generateTypes && generatedTypesPaths.isNotEmpty) {
      final content = indexGen.generateTypesIndex(generatedTypesPaths);
      File(p.join(absOutputDir, 'types', 'index.dart')).writeAsStringSync(content);
      print('   ✅ types/index.dart');
    }

    if (config.generateEnums && generatedEnumPaths.isNotEmpty) {
      final content = indexGen.generateEnumIndex(generatedEnumPaths);
      File(p.join(absOutputDir, 'enum', 'index.dart')).writeAsStringSync(content);
      print('   ✅ enum/index.dart');
    }

    // 生成根 index.dart（导出 controller、types、enum）
    final generatedModules = <String>[];
    if (config.generateControllers && generatedControllerPaths.isNotEmpty) generatedModules.add('controller');
    if (config.generateEnums && generatedEnumPaths.isNotEmpty) generatedModules.add('enum');
    if (config.generateTypes && generatedTypesPaths.isNotEmpty) generatedModules.add('types');
    if (generatedModules.isNotEmpty) {
      final content = indexGen.generateRootIndex(generatedModules);
      File(p.join(absOutputDir, 'index.dart')).writeAsStringSync(content);
      print('   ✅ index.dart');
    }
  }

  print('');
  print('🎉 代码生成完成！输出目录: $absOutputDir');

  // 9. 执行 build_runner 生成 .g.dart 文件
  if (config.runBuildRunner) {
    print('');
    print('🔧 正在执行 build_runner 生成 .g.dart 文件...');
    // build_runner 必须在项目根目录（pubspec.yaml 所在目录）运行，否则会在输出目录生成 .dart_tool
    final projectRoot = foundConfigPath != null ? p.dirname(p.absolute(foundConfigPath)) : Directory.current.path;
    final buildResult = await Process.run('dart', ['run', 'build_runner', 'build', '--delete-conflicting-outputs'], workingDirectory: projectRoot, runInShell: true);
    if (buildResult.exitCode == 0) {
      print('   ✅ build_runner 执行成功');
    } else {
      print('   ❌ build_runner 执行失败 (exitCode: ${buildResult.exitCode})');
      if (buildResult.stdout.toString().isNotEmpty) print(buildResult.stdout);
      if (buildResult.stderr.toString().isNotEmpty) print(buildResult.stderr);
    }
  } else {
    print('💡 提示: 请在目标项目中运行 build_runner 生成 .g.dart 文件');
    print('   cd <项目根目录>');
    print('   dart run build_runner build --delete-conflicting-outputs');
  }
}
