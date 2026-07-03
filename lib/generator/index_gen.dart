/// Index 导出文件生成器

class IndexGenerator {
  /// 生成 controller/index.dart
  /// [controllerPaths] 所有 controller 文件的相对路径 (如 'admin/announcement.dart')
  String generateControllerIndex(Set<String> controllerPaths) {
    final buf = StringBuffer();
    buf.writeln('/// 控制器统一导出文件');
    buf.writeln('/// 此文件由 codeGen 工具自动生成');
    buf.writeln('/// 请勿手动修改');
    buf.writeln('library;');
    buf.writeln();

    final sorted = controllerPaths.toList()..sort();
    for (final path in sorted) {
      buf.writeln("export '$path';");
    }

    return buf.toString();
  }

  /// 生成 types/index.dart
  /// [typePaths] 所有 types 文件的相对路径 (如 'admin/announcement/index.dart' 或 'common/index.dart')
  String generateTypesIndex(Set<String> typePaths) {
    final buf = StringBuffer();
    buf.writeln('/// 数据模型统一导出文件');
    buf.writeln('/// 此文件由 codeGen 工具自动生成');
    buf.writeln('/// 请勿手动修改');
    buf.writeln('library;');
    buf.writeln();

    // common 优先
    final sorted = typePaths.toList()..sort((a, b) {
      if (a.startsWith('common')) return -1;
      if (b.startsWith('common')) return 1;
      return a.compareTo(b);
    });

    for (final path in sorted) {
      buf.writeln("export '$path';");
    }

    return buf.toString();
  }

  /// 生成根 index.dart（导出 controller、types、enum）
  /// [modules] 已生成的模块名称列表（如 ['controller', 'types', 'enum']）
  String generateRootIndex(List<String> modules) {
    final buf = StringBuffer();
    buf.writeln('/// API 统一导出文件');
    buf.writeln('/// 此文件由 codeGen 工具自动生成');
    buf.writeln('/// 请勿手动修改');
    buf.writeln('library;');
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
  /// [enumPaths] 所有 enum 文件的相对路径 (如 'admin/announcement.dart' 或 'common.dart')
  String generateEnumIndex(Set<String> enumPaths) {
    final buf = StringBuffer();
    buf.writeln('/// 枚举统一导出文件');
    buf.writeln('/// 此文件由 codeGen 工具自动生成');
    buf.writeln('/// 请勿手动修改');
    buf.writeln('library;');
    buf.writeln();

    // common 优先
    final sorted = enumPaths.toList()..sort((a, b) {
      if (a.startsWith('common')) return -1;
      if (b.startsWith('common')) return 1;
      return a.compareTo(b);
    });

    for (final path in sorted) {
      buf.writeln("export '$path';");
    }

    return buf.toString();
  }
}
