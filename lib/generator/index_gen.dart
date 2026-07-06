/// Index 导出文件生成器
library;

import '../utils/header_utils.dart';

class IndexGenerator {
  /// 生成 controller/index.dart
  /// [controllerPaths] 所有 controller 文件的相对路径 (如 'admin/announcement.dart')
  String generateControllerIndex(Set<String> controllerPaths) {
    return _generateExportIndex('控制器统一导出文件', controllerPaths);
  }

  /// 生成 types/index.dart
  /// [typePaths] 所有 types 文件的相对路径 (如 'admin/announcement/index.dart' 或 'common/index.dart')
  String generateTypesIndex(Set<String> typePaths) {
    return _generateExportIndex('数据模型统一导出文件', typePaths, commonFirst: true);
  }

  /// 生成根 index.dart（导出 controller、types、enum）
  /// [modules] 已生成的模块名称列表（如 ['controller', 'types', 'enum']）
  String generateRootIndex(List<String> modules) {
    final buf = StringBuffer();
    writeFileHeader(buf, 'API 统一导出文件');
    buf.writeln();

    final order = ['controller', 'enum', 'types'];
    for (final mod in order) {
      if (modules.contains(mod)) {
        buf.writeln("export '$mod/index.dart';");
      }
    }

    return buf.toString();
  }

  /// 生成 enum/index.dart
  /// [enumPaths] 所有 enum 文件的相对路径 (如 'admin/announcement.dart' 或 'common_enum.dart')
  String generateEnumIndex(Set<String> enumPaths) {
    return _generateExportIndex('枚举统一导出文件', enumPaths, commonFirst: true);
  }

  /// 通用 export index 文件生成
  /// [commonFirst] 是否将 common 路径排在最前
  String _generateExportIndex(String description, Set<String> paths, {bool commonFirst = false}) {
    final buf = StringBuffer();
    writeFileHeader(buf, description);
    buf.writeln();

    final sorted = paths.toList()
      ..sort(
        commonFirst
            ? (a, b) {
                if (a.startsWith('common')) return -1;
                if (b.startsWith('common')) return 1;
                return a.compareTo(b);
              }
            : (a, b) => a.compareTo(b),
      );

    for (final path in sorted) {
      buf.writeln("export '$path';");
    }

    return buf.toString();
  }
}
