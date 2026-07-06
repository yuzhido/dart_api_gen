/// 默认配置文件模板
library;

/// 默认 dart_api_gen.yaml 配置文件内容
const String defaultConfigTemplate = '''
# ============================================================
# Dart API 代码生成工具 - 配置文件
# ============================================================
# 使用方式:
#   1. 将此文件放在项目根目录，命名为 dart_api_gen.yaml
#   2. 运行: dart run bin/dart_api_gen.dart
#   3. 也可以指定配置文件路径:
#      dart run bin/dart_api_gen.dart -c path/to/dart_api_gen.yaml
#   4. CLI 参数可覆盖配置文件中的值:
#      dart run bin/dart_api_gen.dart -o ./lib/generated
# ============================================================

# ------------------------------------------------------------
# Swagger JSON 来源配置（二选一）
# ------------------------------------------------------------
# 方式1: 远程 URL —— 从 HTTP 接口获取 Swagger JSON（推荐用于 CI/CD）
# 方式2: 本地文件 —— 读取本地 Swagger JSON 文件（推荐用于开发调试）
#
# 注意: url 和 file 只能二选一，不能同时配置
#
# 简写形式（直接写路径或URL，等价于下面的展开形式）:
#   source: "./swagger.json"
#   source: "http://127.0.0.1:2387/swagger/all/swagger.json"
source:
  # 远程 URL 地址
  url: "http://127.0.0.1:2387/swagger/all/swagger.json"

  # 本地文件路径（相对于运行目录或绝对路径）
  # file: "./swagger.json"

# ------------------------------------------------------------
# 输出配置
# ------------------------------------------------------------
# 生成的 Dart 代码文件的输出目录
# 路径相对于运行目录，也可以使用绝对路径
#
# 简写形式:
#   output: "./lib/api"
output:
  # 生成代码的输出目录
  dir: "./lib/api"

# ------------------------------------------------------------
# 可选配置
# ------------------------------------------------------------
options:
  # 是否保存原始 Swagger JSON 到输出目录的 swagger/index.json
  # 方便排查生成问题，查看原始 API 定义
  # 默认值: true
  save_swagger_json: true

  # 是否生成 Controller 控制器文件
  # 设为 false 则不生成 controller 目录及相关文件
  # 默认值: true
  generate_controllers: true

  # 是否生成枚举类型文件
  # 设为 false 则不生成 enum 目录及相关文件
  # 默认值: true
  generate_enums: true

  # 是否生成 Types 类型模型文件
  # 设为 false 则不生成 types 目录及相关文件
  # 默认值: true
  generate_types: true

  # 是否生成 index.dart 导出文件
  # 包括根 index.dart、controller/index.dart、types/index.dart、enum/index.dart
  # 根 index.dart 统一导出三个模块，方便整体导入
  # 默认值: true
  generate_index: true

  # 是否覆盖已存在的生成文件
  # true: 每次生成时先删除输出目录中已有的文件，再重新生成
  # false: 如果目标文件已存在则跳过，不覆盖（保留手动修改过的文件）
  # 默认值: true
  overwrite: true

  # 是否在生成完成后自动执行 build_runner 生成 .g.dart 文件
  # true: 生成完成后自动执行 dart run build_runner build --delete-conflicting-outputs
  # false: 仅生成代码，不自动执行 build_runner（需手动运行）
  # 默认值: true
  run_build_runner: true
''';
