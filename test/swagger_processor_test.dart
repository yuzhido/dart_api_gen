import 'package:test/test.dart';
import 'package:dart_api_gen/parser/swagger_processor.dart';
import 'package:dart_api_gen/utils/type_mapper.dart';

/// 构造一个最小可运行的 Swagger 文档骨架
Map<String, dynamic> _doc({required Map<String, dynamic> paths, Map<String, dynamic> schemas = const {}, Map<String, dynamic> parameters = const {}}) {
  return {
    'openapi': '3.0.1',
    'info': {'title': 'test', 'version': '1.0'},
    'paths': paths,
    'components': {'schemas': schemas, if (parameters.isNotEmpty) 'parameters': parameters},
  };
}

/// 从处理结果中取出指定 tag 的第一个 API 的 parameters.$ref 指向的 typesInfo 条目
Map<String, dynamic>? _firstQueryDto(Map<String, dynamic> processed) {
  final apiPath = processed['apiPath'] as List<dynamic>?;
  if (apiPath == null || apiPath.isEmpty) return null;
  final apis = (apiPath.first as Map<String, dynamic>)['apis'] as List<dynamic>?;
  if (apis == null || apis.isEmpty) return null;
  final params = (apis.first as Map<String, dynamic>)['parameters'] as Map<String, dynamic>?;
  if (params == null) return null;
  final content = params['content'] as Map<String, dynamic>?;
  if (content == null) return null;
  final schema = (content.values.first as Map<String, dynamic>)['schema'] as Map<String, dynamic>?;
  final ref = schema?['\$ref'] as String?;
  if (ref == null) return null;
  final name = ref.split('/').last;
  final typesInfo = processed['typesInfo'] as Map<String, dynamic>?;
  return typesInfo?[name] as Map<String, dynamic>?;
}

void main() {
  group('SwaggerProcessor - schema 级 \$ref（query 参数引用 components/schemas）', () {
    test('query 参数 schema 引用枚举时，\$ref 被保留到 typesInfo', () {
      final processor = SwaggerProcessor();
      final doc = _doc(
        paths: {
          '/api/orders': {
            'get': {
              'tags': ['Order'],
              'summary': '查询订单',
              'operationId': 'queryOrders',
              'parameters': [
                {
                  'name': 'status',
                  'in': 'query',
                  'description': '订单状态',
                  'required': true,
                  'schema': {'\$ref': '#/components/schemas/OrderStatusEnum'},
                },
              ],
              'responses': {
                '200': {'description': 'ok'},
              },
            },
          },
        },
        schemas: {
          'OrderStatusEnum': {
            'type': 'integer',
            'enum': [0, 1, 2],
            'description': '订单状态',
          },
        },
      );

      final processed = processor.process(doc);
      final dto = _firstQueryDto(processed);
      expect(dto, isNotNull);
      final props = dto!['properties'] as Map<String, dynamic>;
      expect(props.containsKey('status'), isTrue);
      final statusProp = props['status'] as Map<String, dynamic>;
      // 关键断言：$ref 被保留，而不是被兜底成 type: string
      expect(statusProp['\$ref'], equals('#/components/schemas/OrderStatusEnum'));
      expect(statusProp.containsKey('type'), isFalse);
      expect(statusProp['description'], equals('订单状态'));
      expect(statusProp['required'], isTrue);
      expect(statusProp['in'], equals('query'));
    });

    test('TypeMapper 能把保留下来的 \$ref 映射为 Enum 类型', () {
      final processor = SwaggerProcessor();
      final doc = _doc(
        paths: {
          '/api/orders': {
            'get': {
              'tags': ['Order'],
              'operationId': 'queryOrders',
              'parameters': [
                {
                  'name': 'status',
                  'in': 'query',
                  'schema': {'\$ref': '#/components/schemas/OrderStatusEnum'},
                },
              ],
              'responses': {
                '200': {'description': 'ok'},
              },
            },
          },
        },
        schemas: {
          'OrderStatusEnum': {
            'type': 'integer',
            'enum': [0, 1, 2],
          },
        },
      );
      final processed = processor.process(doc);
      final typesInfo = (processed['typesInfo'] as Map<String, dynamic>).cast<String, Map<String, dynamic>>();
      final mapper = TypeMapper(typesInfo);
      // 直接对 property schema 做映射
      final dto = _firstQueryDto(processed)!;
      final statusProp = (dto['properties'] as Map<String, dynamic>)['status'] as Map<String, dynamic>;
      // ensureEnumSuffix 对已以 Enum 结尾的名字不重复加后缀
      expect(mapper.mapType(statusProp), equals('OrderStatusEnum'));
    });

    test('query 参数为数组且 items 引用 schema 时，items.\$ref 被保留', () {
      final processor = SwaggerProcessor();
      final doc = _doc(
        paths: {
          '/api/orders': {
            'get': {
              'tags': ['Order'],
              'operationId': 'queryOrders',
              'parameters': [
                {
                  'name': 'ids',
                  'in': 'query',
                  'schema': {
                    'type': 'array',
                    'items': {'\$ref': '#/components/schemas/OrderId'},
                  },
                },
              ],
              'responses': {
                '200': {'description': 'ok'},
              },
            },
          },
        },
        schemas: {
          'OrderId': {'type': 'string'},
        },
      );
      final processed = processor.process(doc);
      final dto = _firstQueryDto(processed)!;
      final idsProp = (dto['properties'] as Map<String, dynamic>)['ids'] as Map<String, dynamic>;
      expect(idsProp['type'], equals('array'));
      final items = idsProp['items'] as Map<String, dynamic>;
      expect(items['\$ref'], equals('#/components/schemas/OrderId'));
    });

    test('普通类型 query 参数行为不变（向后兼容）', () {
      final processor = SwaggerProcessor();
      final doc = _doc(
        paths: {
          '/api/users': {
            'get': {
              'tags': ['User'],
              'operationId': 'queryUsers',
              'parameters': [
                {
                  'name': 'page',
                  'in': 'query',
                  'schema': {'type': 'integer', 'format': 'int32'},
                },
                {
                  'name': 'keyword',
                  'in': 'query',
                  'schema': {'type': 'string'},
                },
              ],
              'responses': {
                '200': {'description': 'ok'},
              },
            },
          },
        },
      );
      final processed = processor.process(doc);
      final dto = _firstQueryDto(processed)!;
      final props = dto['properties'] as Map<String, dynamic>;
      expect((props['page'] as Map)['type'], equals('integer'));
      expect((props['page'] as Map)['format'], equals('int32'));
      expect((props['keyword'] as Map)['type'], equals('string'));
      expect((props['keyword'] as Map).containsKey('\$ref'), isFalse);
    });
  });

  group('SwaggerProcessor - parameter 级 \$ref（引用 components/parameters）', () {
    test('operation 下 parameters 中的 \$ref 被展开为实际参数定义', () {
      final processor = SwaggerProcessor();
      final doc = _doc(
        paths: {
          '/api/orders': {
            'get': {
              'tags': ['Order'],
              'operationId': 'queryOrders',
              'parameters': [
                {'\$ref': '#/components/parameters/PageParam'},
                {'\$ref': '#/components/parameters/KeywordParam'},
              ],
              'responses': {
                '200': {'description': 'ok'},
              },
            },
          },
        },
        parameters: {
          'PageParam': {
            'name': 'page',
            'in': 'query',
            'description': '页码',
            'required': true,
            'schema': {'type': 'integer', 'format': 'int32'},
          },
          'KeywordParam': {
            'name': 'keyword',
            'in': 'query',
            'schema': {'type': 'string'},
          },
        },
      );
      final processed = processor.process(doc);
      final dto = _firstQueryDto(processed)!;
      final props = dto['properties'] as Map<String, dynamic>;
      expect(props.containsKey('page'), isTrue, reason: 'PageParam 应被展开');
      expect(props.containsKey('keyword'), isTrue, reason: 'KeywordParam 应被展开');
      expect((props['page'] as Map)['type'], equals('integer'));
      expect((props['page'] as Map)['description'], equals('页码'));
      expect((props['page'] as Map)['required'], isTrue);
    });

    test('path-level parameters 中的 \$ref 同样被展开', () {
      final processor = SwaggerProcessor();
      final doc = _doc(
        paths: {
          '/api/orders/{id}': {
            'parameters': [
              {'\$ref': '#/components/parameters/IdParam'},
            ],
            'get': {
              'tags': ['Order'],
              'operationId': 'getOrder',
              'responses': {
                '200': {'description': 'ok'},
              },
            },
          },
        },
        parameters: {
          'IdParam': {
            'name': 'id',
            'in': 'path',
            'required': true,
            'schema': {'type': 'string'},
          },
        },
      );
      // path-level 参数展开不应抛异常（即便 in:path 不会进入 query DTO）
      expect(() => processor.process(doc), returnsNormally);
    });

    test('parameter \$ref 与 schema \$ref 组合：展开后 schema.\$ref 仍被保留', () {
      final processor = SwaggerProcessor();
      final doc = _doc(
        paths: {
          '/api/orders': {
            'get': {
              'tags': ['Order'],
              'operationId': 'queryOrders',
              'parameters': [
                {'\$ref': '#/components/parameters/StatusParam'},
              ],
              'responses': {
                '200': {'description': 'ok'},
              },
            },
          },
        },
        parameters: {
          'StatusParam': {
            'name': 'status',
            'in': 'query',
            'schema': {'\$ref': '#/components/schemas/OrderStatusEnum'},
          },
        },
        schemas: {
          'OrderStatusEnum': {
            'type': 'integer',
            'enum': [0, 1],
          },
        },
      );
      final processed = processor.process(doc);
      final dto = _firstQueryDto(processed)!;
      final statusProp = (dto['properties'] as Map<String, dynamic>)['status'] as Map<String, dynamic>;
      expect(statusProp['\$ref'], equals('#/components/schemas/OrderStatusEnum'));
    });

    test('嵌套 parameter \$ref 被递归展开', () {
      final processor = SwaggerProcessor();
      final doc = _doc(
        paths: {
          '/api/orders': {
            'get': {
              'tags': ['Order'],
              'operationId': 'queryOrders',
              'parameters': [
                {'\$ref': '#/components/parameters/OuterParam'},
              ],
              'responses': {
                '200': {'description': 'ok'},
              },
            },
          },
        },
        parameters: {
          'OuterParam': {'\$ref': '#/components/parameters/InnerParam'},
          'InnerParam': {
            'name': 'inner',
            'in': 'query',
            'schema': {'type': 'string'},
          },
        },
      );
      final processed = processor.process(doc);
      final dto = _firstQueryDto(processed)!;
      final props = dto['properties'] as Map<String, dynamic>;
      expect(props.containsKey('inner'), isTrue);
    });

    test('parameter \$ref 环引用不会导致死循环', () {
      final processor = SwaggerProcessor();
      final doc = _doc(
        paths: {
          '/api/orders': {
            'get': {
              'tags': ['Order'],
              'operationId': 'queryOrders',
              'parameters': [
                {'\$ref': '#/components/parameters/A'},
              ],
              'responses': {
                '200': {'description': 'ok'},
              },
            },
          },
        },
        parameters: {
          'A': {'\$ref': '#/components/parameters/B'},
          'B': {'\$ref': '#/components/parameters/A'},
        },
      );
      // 环检测应阻止无限递归；无法解析时保留原样即可
      expect(() => processor.process(doc), returnsNormally);
    });

    test('指向不存在的 components/parameters 时安全跳过', () {
      final processor = SwaggerProcessor();
      final doc = _doc(
        paths: {
          '/api/orders': {
            'get': {
              'tags': ['Order'],
              'operationId': 'queryOrders',
              'parameters': [
                {'\$ref': '#/components/parameters/NotExist'},
                {
                  'name': 'keyword',
                  'in': 'query',
                  'schema': {'type': 'string'},
                },
              ],
              'responses': {
                '200': {'description': 'ok'},
              },
            },
          },
        },
      );
      final processed = processor.process(doc);
      final dto = _firstQueryDto(processed)!;
      final props = dto['properties'] as Map<String, dynamic>;
      // 无效 $ref 被忽略，正常参数仍然进入 DTO
      expect(props.containsKey('keyword'), isTrue);
    });

    test('process 不会污染调用方传入的原始 swaggerDoc', () {
      final processor = SwaggerProcessor();
      final doc = _doc(
        paths: {
          '/api/orders': {
            'get': {
              'tags': ['Order'],
              'operationId': 'queryOrders',
              'parameters': [
                {'\$ref': '#/components/parameters/PageParam'},
              ],
              'responses': {
                '200': {'description': 'ok'},
              },
            },
          },
        },
        parameters: {
          'PageParam': {
            'name': 'page',
            'in': 'query',
            'schema': {'type': 'integer'},
          },
        },
      );
      processor.process(doc);
      // 原始 paths 下的 parameters 应仍然只有 $ref，未被就地改写
      final originalParam = ((doc['paths'] as Map)['/api/orders'] as Map)['get'] as Map;
      final params = originalParam['parameters'] as List;
      expect((params.first as Map).containsKey('\$ref'), isTrue);
      expect((params.first as Map)['\$ref'], equals('#/components/parameters/PageParam'));
    });
  });
}
