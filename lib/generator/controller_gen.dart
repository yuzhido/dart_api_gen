/// API 控制器生成器
import '../parser/processed_swagger_loader.dart';
import '../utils/naming.dart';
import '../utils/type_mapper.dart';

class ControllerGenerator {
  final TypeMapper typeMapper;

  ControllerGenerator(this.typeMapper);

  /// 为指定 tag 生成控制器文件
  String generateForTag(ProcessedApiEntry entry) {
    final tag = entry.tagName;
    final className = tagToApiClassName(tag);
    final buf = StringBuffer();

    // 文件头
    final tagDesc = entry.description.isNotEmpty ? entry.description : tag;
    buf.writeln('/// $tagDesc API 控制器');
    buf.writeln('/// 此文件由 genCode 工具自动生成');
    buf.writeln('/// 请勿手动修改');
    buf.writeln('library;');
    buf.writeln();
    buf.writeln("import 'package:dio/dio.dart';");
    buf.writeln("import '../../../core/network/index.dart';");
    buf.writeln("import '../../../core/network/request_config.dart';");
    buf.writeln("import '../../types/index.dart';");
    buf.writeln();

    buf.writeln('class $className {');
    buf.writeln('  static final DioUtil _dio = DioUtil();');

    for (var i = 0; i < entry.apis.length; i++) {
      buf.writeln();
      _generateMethod(buf, tag, entry.apis[i]);
    }

    buf.write('}');

    return buf.toString();
  }

  void _generateMethod(StringBuffer buf, String tag, ProcessedApi api) {
    final summary = api.summary;
    final path = api.apiPath;
    final method = api.method.toUpperCase();
    final methodName = toCamelCase(path.split('/').where((s) => s.isNotEmpty).last);

    // 获取返回类型
    final responseRef = api.responseRef;
    String returnType = 'dynamic';
    if (responseRef != null) {
      returnType = responseRef.endsWith('Dto') ? responseRef : '${responseRef}Dto';
    }

    // 确定参数
    final queryRef = api.parametersRef; // query 参数的 $ref schema 名称
    final bodyRef = api.requestBodyRef; // requestBody 的 $ref schema 名称
    final hasQuery = queryRef != null;

    // 判断 body 类型
    final isFormData = api.isFormData;
    final hasArrayBody = _hasArrayBody(api);

    String paramSignature = '';
    String requestLogic = '';

    // 1. 处理 query 参数
    if (hasQuery) {
      // swagger_processor 已在 schema 名中加了 Query 后缀，直接使用
      final dtoName = _toDtoName(queryRef);
      paramSignature = '$dtoName query';
      requestLogic = "      query: query.toJson(),\n";
    }

    // 2. 处理 body 参数 (POST/PUT/PATCH)
    if (api.method == 'post' || api.method == 'put' || api.method == 'patch') {
      if (isFormData) {
        // swagger_processor 已在 schema 名中加了 Body 后缀，直接使用
        final dtoName = _toDtoName(bodyRef ?? queryRef ?? '');
        paramSignature = paramSignature.isNotEmpty ? '$paramSignature, $dtoName data' : '$dtoName data';
        requestLogic += "      data: formData,\n";
      } else if (hasArrayBody) {
        final dtoName = _toDtoName(bodyRef ?? queryRef ?? '');
        paramSignature = paramSignature.isNotEmpty ? '$paramSignature, $dtoName data' : '$dtoName data';
        requestLogic += "      data: data,\n";
      } else if (bodyRef != null) {
        final dtoName = _toDtoName(bodyRef);
        paramSignature = paramSignature.isNotEmpty ? '$paramSignature, $dtoName data' : '$dtoName data';
        requestLogic += "      data: data.toJson(),\n";
      } else {
        // 简单类型 body（从 requestBody content 中获取类型）
        final bodyType = _getSimpleBodyType(api);
        if (bodyType != null) {
          paramSignature = paramSignature.isNotEmpty ? '$paramSignature, $bodyType data' : '$bodyType data';
          requestLogic += "      data: data,\n";
        }
      }
    } else if (api.method == 'delete') {
      if (hasArrayBody) {
        final dtoName = _toDtoName(bodyRef ?? '');
        paramSignature = paramSignature.isNotEmpty ? '$paramSignature, $dtoName data' : '$dtoName data';
        requestLogic += "      data: data,\n";
      } else if (bodyRef != null) {
        final dtoName = _toDtoName(bodyRef);
        paramSignature = paramSignature.isNotEmpty ? '$paramSignature, $dtoName data' : '$dtoName data';
        requestLogic += "      data: data.toJson(),\n";
      }
    }

    // 方法注释
    final singleLineSummary = summary.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).join(' ');
    buf.writeln('  /// ### $singleLineSummary');
    buf.writeln('  /// - 请求路径: $path');
    buf.writeln('  /// - 请求方法: ${api.method}');
    if (paramSignature.isNotEmpty) {
      if (paramSignature.contains('query') && paramSignature.contains('data')) {
        buf.writeln('  /// - [query] 查询参数');
        buf.writeln('  /// - [data] 请求体参数');
      } else if (paramSignature.contains('query')) {
        buf.writeln('  /// - [query] 查询参数');
      } else {
        buf.writeln('  /// - [data] 请求体参数');
      }
    }
    buf.writeln('  /// - [cancelToken] 取消令牌（用于取消请求）');
    buf.writeln('  /// - [config] 请求配置（loading、重试、超时等）');

    // 方法签名
    final paramPart = paramSignature.isNotEmpty ? '$paramSignature, ' : '';
    buf.writeln('  static Future<$returnType> $methodName($paramPart{CancelToken? cancelToken, RequestConfig? config}) async {');

    // form-data 特殊处理
    if (isFormData) {
      buf.writeln('    FormData formData = FormData.fromMap(data.toJson());');
    }

    buf.writeln('    final response = await _dio.request(');
    buf.writeln("      '$path',");
    buf.writeln("      method: '$method',");
    buf.write(requestLogic);
    buf.writeln('      cancelToken: cancelToken,');
    buf.writeln('      config: config,');
    buf.writeln('    );');
    if (returnType == 'dynamic') {
      buf.writeln('    return response.data;');
    } else {
      buf.writeln('    // 从 Response 中提取 data 并转换为 Model');
      buf.writeln('    return $returnType.fromJson(response.data as Map<String, dynamic>);');
    }
    buf.writeln('  }');
  }

  // ─── 工具方法 ───

  /// 将 schema 名称转为 Dto 名称
  String _toDtoName(String name) {
    if (name.isEmpty) return 'dynamic';
    return name.endsWith('Dto') ? name : '${name}Dto';
  }

  /// 判断是否有数组类型的 body
  bool _hasArrayBody(ProcessedApi api) {
    if (api.requestBody == null) return false;
    final content = api.requestBody!['content'] as Map<String, dynamic>?;
    if (content == null) return false;
    for (final mt in content.values) {
      final schema = (mt as Map<String, dynamic>)['schema'] as Map<String, dynamic>?;
      if (schema != null && schema['type'] == 'array') return true;
    }
    return false;
  }

  /// 获取简单类型 body 的 Dart 类型
  String? _getSimpleBodyType(ProcessedApi api) {
    if (api.requestBody == null) return null;
    final content = api.requestBody!['content'] as Map<String, dynamic>?;
    if (content == null) return null;
    for (final mt in content.values) {
      final schema = (mt as Map<String, dynamic>)['schema'] as Map<String, dynamic>?;
      if (schema != null && !schema.containsKey('\$ref') && schema['type'] != 'array') {
        return typeMapper.mapType(schema);
      }
    }
    return null;
  }
}
