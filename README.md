# Dart API Gen

从 Swagger/OpenAPI JSON 自动生成 Dart API 控制器、数据模型和枚举定义的代码生成工具。

## 功能特性

- **Controller 生成** — 根据 API Tag 分组自动生成 API 控制器文件
- **Types 数据模型生成** — 自动将 Schema 转换为 Dart 数据模型类
- **Enum 枚举生成** — 自动识别并生成枚举类型定义
- **Index 导出文件** — 自动生成 `index.dart` 统一导出，方便导入使用
- **灵活的来源支持** — 支持远程 URL 和本地文件两种 Swagger JSON 来源
- **智能分组** — 按 API 服务（Area）和 Tag 自动分组输出文件
- **YAML 配置** — 通过 `dart_api_gen.yaml` 配置文件灵活控制生成行为
- **CLI 参数覆盖** — 命令行参数优先级高于配置文件
- **build_runner 集成** — 可选自动执行 `build_runner` 生成 `.g.dart` 文件

## 安装

在项目的 `pubspec.yaml` 中添加依赖：

```yaml
dev_dependencies:
  dart_api_gen:
    path: ./path/to/dart_api_gen
```

或直接通过 CLI 运行：

```bash
dart run bin/dart_api_gen.dart
```

## 快速开始

### 1. 初始化配置文件

```bash
dart run bin/dart_api_gen.dart init
```

这会在当前目录生成带完整注释的 `dart_api_gen.yaml` 配置文件。

### 2. 编辑配置文件

```yaml
# dart_api_gen.yaml
source:
  file: './swagger.json' # 本地 Swagger JSON 文件
  # url: 'http://...'           # 或远程 URL

output:
  dir: './lib/api' # 代码输出目录

options:
  generate_controllers: true
  generate_enums: true
  generate_types: true
  generate_index: true
  overwrite: true
  run_build_runner: true
```

### 3. 运行代码生成

```bash
dart run bin/dart_api_gen.dart
```

## CLI 用法

```
用法: dart_api_gen <command> [options]

命令:
  init              在当前目录生成带完整注释的默认配置文件

选项:
  -u, --url         Swagger JSON URL (覆盖配置文件)
  -f, --file        Swagger JSON 文件路径 (覆盖配置文件)
  -o, --output      输出目录路径 (覆盖配置文件)
  -c, --config      配置文件路径 (默认: dart_api_gen.yaml)
  -h, --help        显示帮助信息
```

### 示例

```bash
# 使用本地文件
dart run bin/dart_api_gen.dart -f ./swagger.json -o ./lib/api

# 使用远程 URL
dart run bin/dart_api_gen.dart -u http://localhost:8080/swagger.json

# 指定配置文件
dart run bin/dart_api_gen.dart -c path/to/config.yaml

# 初始化配置文件
dart run bin/dart_api_gen.dart init

# 强制覆盖已有配置文件
dart run bin/dart_api_gen.dart init -f
```

## 配置文件说明

配置文件 `dart_api_gen.yaml` 放在项目根目录，包含以下配置项：

### `source` — Swagger 来源（二选一）

| 字段   | 类型   | 说明                   |
| ------ | ------ | ---------------------- |
| `url`  | String | 远程 Swagger JSON URL  |
| `file` | String | 本地 Swagger JSON 路径 |

也支持简写形式：

```yaml
source: "./swagger.json"
source: "http://127.0.0.1:2387/swagger/all/swagger.json"
```

### `output` — 输出配置

| 字段  | 类型   | 说明         | 默认值      |
| ----- | ------ | ------------ | ----------- |
| `dir` | String | 代码输出目录 | `./lib/api` |

### `options` — 可选配置

| 字段                   | 类型 | 说明                                  | 默认值 |
| ---------------------- | ---- | ------------------------------------- | ------ |
| `save_swagger_json`    | bool | 是否保存原始 Swagger JSON 到输出目录  | `true` |
| `generate_controllers` | bool | 是否生成 Controller 控制器文件        | `true` |
| `generate_enums`       | bool | 是否生成枚举类型文件                  | `true` |
| `generate_types`       | bool | 是否生成 Types 数据模型文件           | `true` |
| `generate_index`       | bool | 是否生成 index.dart 导出文件          | `true` |
| `overwrite`            | bool | 是否覆盖已存在的生成文件              | `true` |
| `run_build_runner`     | bool | 是否在生成完成后自动执行 build_runner | `true` |

## 生成目录结构

```
lib/api/
├── index.dart                  # 根导出文件
├── controller/
│   ├── index.dart              # Controller 导出
│   └── {area}/
│       └── {tag}.dart          # API 控制器
├── enum/
│   ├── index.dart              # Enum 导出
│   ├── common_enum.dart        # 跨服务共用枚举
│   └── {area}/
│       └── common_enum.dart    # 服务内共用枚举
├── types/
│   ├── index.dart              # Types 导出
│   ├── common_type/
│   │   └── index.dart          # 跨服务通用数据模型
│   └── {area}/
│       ├── common_type/
│       │   └── index.dart      # 服务内通用数据模型
│       └── {tag}/
│           └── index.dart      # Tag 级别数据模型
└── temp-swagger-data/
    ├── index.json              # 原始 Swagger JSON
    └── processSwagger.json     # 处理后的 Swagger 数据
```

## 项目架构

```
dart_api_gen/
├── bin/
│   └── dart_api_gen.dart       # CLI 入口
├── lib/
│   ├── config/
│   │   └── code_gen_config.dart    # 配置加载与管理
│   ├── constants/
│   │   ├── config_template.dart    # 默认配置模板
│   │   ├── generator_constants.dart # 生成器常量
│   │   └── swagger_constants.dart  # Swagger 相关常量
│   ├── generator/
│   │   ├── controller_gen.dart     # Controller 代码生成
│   │   ├── enum_gen.dart           # Enum 代码生成
│   │   ├── types_gen.dart          # Types 数据模型生成
│   │   └── index_gen.dart          # Index 导出文件生成
│   ├── parser/
│   │   ├── swagger_parser.dart     # Swagger JSON 解析
│   │   ├── swagger_processor.dart  # Swagger 数据预处理
│   │   └── processed_swagger_loader.dart # 处理后数据加载
│   └── utils/
│       ├── header_utils.dart       # 文件头工具
│       ├── media_type_utils.dart   # Media Type 工具
│       ├── naming.dart             # 命名规范转换
│       ├── path_utils.dart         # 路径工具
│       ├── ref_utils.dart          # $ref 引用解析
│       └── type_mapper.dart        # Swagger 类型到 Dart 类型映射
└── test/                           # 测试文件
```

## 工作流程

1. **加载配置** — 读取 `dart_api_gen.yaml` 或使用 CLI 参数
2. **解析 Swagger** — 从 URL 或文件加载 Swagger/OpenAPI JSON
3. **数据预处理** — 处理 `$ref` 引用、提取类型信息、分类枚举与对象
4. **分析结构** — 按 API 服务（Area）和 Tag 进行智能分组
5. **生成代码** — 依次生成 Controller、Enum、Types、Index 文件
6. **执行 build_runner**（可选）— 自动生成 `.g.dart` 序列化文件

## 依赖

| 包名   | 版本   | 说明           |
| ------ | ------ | -------------- |
| `http` | ^1.2.0 | HTTP 请求      |
| `path` | ^1.9.0 | 路径处理       |
| `args` | ^2.5.0 | 命令行参数解析 |
| `yaml` | ^3.1.0 | YAML 配置解析  |

## 许可证

详见 [LICENSE](LICENSE) 文件。
