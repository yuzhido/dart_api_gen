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

/// IFormFile 特征字段集（ASP.NET Core IFormFile 接口暴露的属性）
/// 后端 Swagger 生成器（如 Swashbuckle/NSwag）把 IFormFile 直接序列化为对象时
/// 会出现这些字段但没有 format: binary 标记，导致生成器无法识别为文件上传。
/// 命中该特征集时，multipart/form-data 请求体会被重写为单文件 binary schema。
const iFormFileSignatureFields = <String>{'ContentType', 'ContentDisposition', 'Headers', 'Length', 'Name', 'FileName'};

/// IFormFile 特征命中后，重写 schema 使用的默认表单字段名
const defaultMultipartFileFieldName = 'file';
