/// Swagger/OpenAPI 相关常量
library;

/// 支持的 HTTP 方法
const httpMethods = ['get', 'post', 'put', 'delete', 'patch'];

/// OpenAPI $ref 路径前缀
const refPathPrefix = '#/components/schemas/';

/// 配置文件名
const configFileName = 'dart_api_gen.yaml';

/// 默认输出目录
const defaultOutputDir = './lib/api';

/// 支持的环境名（固定顺序）
/// 用于 --env 参数校验，以及未指定 --env 时的默认回退顺序：
/// 按 local → dev → testing → production 取第一个已定义的环境
const allowedEnvironments = ['local', 'dev', 'testing', 'production'];
