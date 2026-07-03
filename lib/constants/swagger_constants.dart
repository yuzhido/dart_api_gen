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
