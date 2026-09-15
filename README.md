# Dart API Gen

从 Swagger/OpenAPI JSON 自动生成 Dart API 控制器、数据模型和枚举定义的代码生成工具。

## 功能特性

- **Controller 生成** — 根据 API Tag 分组自动生成 API 控制器文件
- **Types 数据模型生成** — 自动将 Schema 转换为 Dart 数据模型类
- **Enum 枚举生成** — 自动识别并生成枚举类型定义
- **Index 导出文件** — 自动生成 `index.dart` 统一导出，方便导入使用
- **灵活的来源支持** — 支持远程 URL 和本地文件两种 Swagger JSON 来源
- **多环境切换** — 在配置中为 local/dev/testing/production 各配一个 URL，用 `--env` 一键切换
- **智能分组** — 按 API 服务（Area）和 Tag 自动分组输出文件
- **YAML 配置** — 通过 `dart_api_gen.yaml` 配置文件灵活控制生成行为
- **CLI 参数覆盖** — 命令行参数优先级高于配置文件
- **build_runner 集成** — 可选自动执行 `build_runner` 生成 `.g.dart` 文件

## 安装

`dart_api_gen` 是一个 CLI 工具，通常作为 **业务项目的 `dev_dependencies`** 引入。以下三种方式任选其一。

### 方式一：从 pub.dev 获取（推荐，线上使用）

在业务项目的 `pubspec.yaml` 中添加：

```yaml
dev_dependencies:
  dart_api_gen: ^1.1.0
```

然后拉取依赖：

```bash
dart pub get
# Flutter 项目使用: flutter pub get
```

获取到依赖后，可以在业务项目根目录通过以下任一方式调用：

```bash
# 方式 A: 通过 dart run 调用（推荐，无需额外配置）
dart run dart_api_gen init
dart run dart_api_gen

# 方式 B: 全局激活后直接使用命令（一次激活，全局可用）
dart pub global activate dart_api_gen
dart_api_gen init
dart_api_gen
```

> 若使用方式 B 后提示 `command not found`，请将 pub 全局 bin 目录加入 `PATH`：
>
> ```bash
> echo 'export PATH="$PATH":"$HOME/.pub-cache/bin"' >> ~/.zshrc
> source ~/.zshrc
> ```

### 方式二：本地路径依赖（本地调试 / 未发布场景）

当你需要 **一边改 `dart_api_gen` 源码、一边在业务项目里验证效果** 时，使用 `path:` 引用本地克隆的仓库：

```yaml
dev_dependencies:
  dart_api_gen:
    path: ../dart_api_gen # 指向本地 dart_api_gen 仓库根目录（pubspec.yaml 所在目录）
```

然后：

```bash
dart pub get
dart run dart_api_gen init
dart run dart_api_gen
```

`path:` 依赖是符号链接方式，**修改 `dart_api_gen` 源码后无需重新 `pub get`，直接再次运行 `dart run dart_api_gen` 即可生效**，非常适合调试。

如果业务项目已经依赖了 pub.dev 上的版本，但临时想用本地源码调试，可以使用 `dependency_overrides` 强制覆盖：

```yaml
dependencies:
  # ... 业务依赖

dev_dependencies:
  dart_api_gen: ^1.1.0

dependency_overrides:
  dart_api_gen:
    path: ../dart_api_gen
```

调试完成后记得移除 `dependency_overrides`。

### 方式三：Git 依赖（跟踪仓库最新代码）

```yaml
dev_dependencies:
  dart_api_gen:
    git:
      url: https://github.com/yuzhido/dart_api_gen.git
      ref: main # 分支名 / tag / commit hash
```

然后执行 `dart pub get`，调用方式与方式一相同。

### 在 dart_api_gen 仓库内直接运行（贡献者/开发本工具时）

如果你是 `dart_api_gen` 本身的开发者，在仓库根目录可以直接跑 `bin/` 入口：

```bash
cd path/to/dart_api_gen
dart pub get
dart run bin/dart_api_gen.dart -c /path/to/other/project/dart_api_gen.yaml
```

通过 `-c` 指定其他项目的配置文件路径，即可在不切换目录的情况下调试生成效果。

## 快速开始

> 以下示例假设你在**业务项目根目录**，且已通过上面任一方式安装好 `dart_api_gen`。
> 命令统一使用 `dart run dart_api_gen`；若已全局激活，可直接替换为 `dart_api_gen`。

### 1. 初始化配置文件

```bash
dart run dart_api_gen init
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
dart run dart_api_gen
```

生成完成后，若配置了 `run_build_runner: true`，工具会自动在业务项目根目录执行 `dart run build_runner build --delete-conflicting-outputs` 生成 `.g.dart` 序列化文件。

## CLI 用法

```bash
用法: dart run dart_api_gen <command> [options]
# 或全局激活后: dart_api_gen <command> [options]

命令:
  init              在当前目录生成带完整注释的默认配置文件

选项:
  -u, --url         Swagger JSON URL (覆盖配置文件)
  -f, --file        Swagger JSON 文件路径 (覆盖配置文件)
  -e, --env         选择环境: local/dev/testing/production (取配置 environments 中对应 URL)
  -o, --output      输出目录路径 (覆盖配置文件)
  -c, --config      配置文件路径 (默认: dart_api_gen.yaml)
  -h, --help        显示帮助信息
```

### 示例

```bash
# 使用本地文件
dart run dart_api_gen -f ./swagger.json -o ./lib/api

# 使用远程 URL
dart run dart_api_gen -u http://localhost:8080/swagger.json

# 使用配置中的多环境 URL（选择 production 环境）
dart run dart_api_gen --env production

# 指定配置文件（在任意目录调用其他项目的配置）
dart run dart_api_gen -c path/to/config.yaml

# 初始化配置文件
dart run dart_api_gen init

# 强制覆盖已有配置文件
dart run dart_api_gen init -f
```

## 本地调试 dart_api_gen

当你需要修改 `dart_api_gen` 本身的源码（修 bug、加功能）并即时在业务项目里看到效果时：

**步骤 1：克隆源码到本地**

```bash
git clone https://github.com/yuzhido/dart_api_gen.git
cd dart_api_gen
dart pub get
```

**步骤 2：在业务项目中以 `path:` 引用**

```yaml
# 业务项目的 pubspec.yaml
dev_dependencies:
  dart_api_gen:
    path: ../dart_api_gen

# 或者用 dependency_overrides 临时覆盖已发布版本
# dependency_overrides:
#   dart_api_gen:
#     path: ../dart_api_gen
```

```bash
cd ../your_business_project
dart pub get
```

**步骤 3：修改源码 → 立即验证**

`path:` 依赖是符号链接，修改 `dart_api_gen/lib/` 或 `bin/` 下的任何文件后，**无需重新 `pub get`**，直接：

```bash
dart run dart_api_gen
```

即可看到修改效果。

**步骤 4：单元测试验证**

在 `dart_api_gen` 仓库根目录跑测试：

```bash
cd ../dart_api_gen
dart test
```

**步骤 5：不切目录直接调试其他项目**

如果不想改业务项目的 `pubspec.yaml`，也可以直接在 `dart_api_gen` 仓库内跑 `bin/`，通过 `-c` 指定业务项目的配置文件：

```bash
cd path/to/dart_api_gen
dart run bin/dart_api_gen.dart -c /absolute/path/to/business_project/dart_api_gen.yaml
```

> 注意：此时 `run_build_runner: true` 会在配置文件所在目录（即业务项目根目录）执行 build_runner，符合预期。

## 配置文件说明

配置文件 `dart_api_gen.yaml` 放在项目根目录，包含以下配置项：

### `source` — Swagger 来源

| 字段           | 类型               | 说明                                            |
| -------------- | ------------------ | ----------------------------------------------- |
| `url`          | String             | 远程 Swagger JSON URL                           |
| `file`         | String             | 本地 Swagger JSON 路径                          |
| `environments` | Map<String,String> | 多环境 URL 配置，键为环境名，值为对应环境的 URL |

`url` 和 `file` 二选一；也支持简写形式：

```yaml
source: "./swagger.json"
source: "http://127.0.0.1:2387/swagger/all/swagger.json"
```

**多环境 URL（`environments`）**：为不同环境各配一个 URL，运行时用 `--env <name>` 选择使用哪个环境获取 JSON。

- 环境名仅限 `local` / `dev` / `testing` / `production`，出现其它名称会报错
- 未指定 `--env` 时，按 `local → dev → testing → production` 顺序取第一个已定义的环境
- 来源优先级：`--url`/`--file` > `--env` > `environments`（固定顺序回退）> `source.url`/`source.file`

```yaml
source:
  environments:
    local: 'http://127.0.0.1:2387/swagger/all/swagger.json'
    dev: 'http://dev.example.com/swagger.json'
    testing: 'http://test.example.com/swagger.json'
    production: 'https://api.example.com/swagger.json'
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

```bash
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

```bash
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
