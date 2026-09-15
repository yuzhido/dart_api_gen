import 'package:test/test.dart';
import 'package:dart_api_gen/utils/naming.dart';
import 'package:dart_api_gen/utils/ref_utils.dart';
import 'package:dart_api_gen/utils/type_mapper.dart';
import 'package:dart_api_gen/config/code_gen_config.dart';

void main() {
  group('naming utils', () {
    test('toPascalCase converts correctly', () {
      expect(toPascalCase('hello_world'), equals('HelloWorld'));
      expect(toPascalCase('demo-user'), equals('DemoUser'));
      expect(toPascalCase('api_group'), equals('ApiGroup'));
    });

    test('toCamelCase converts correctly', () {
      expect(toCamelCase('hello_world'), equals('helloWorld'));
      expect(toCamelCase('DemoUser'), equals('demoUser'));
    });

    test('toSnakeCase converts correctly', () {
      expect(toSnakeCase('DemoUser'), equals('demo_user'));
      expect(toSnakeCase('ApiGroup'), equals('api_group'));
    });

    test('tagToFileName converts correctly', () {
      expect(tagToFileName('DemoUser'), equals('demo_user'));
      expect(tagToFileName('ApiGroup'), equals('api_group'));
    });

    test('schemaToClassName always adds Dto suffix', () {
      expect(schemaToClassName('DemoUser'), equals('DemoUserDto'));
      expect(schemaToClassName('DemoUserDto'), equals('DemoUserDtoDto'));
    });

    test('ensureDtoSuffix always appends Dto', () {
      expect(ensureDtoSuffix('AssetConfigRetirement'), equals('AssetConfigRetirementDto'));
      expect(ensureDtoSuffix('AssetConfigRetirementDto'), equals('AssetConfigRetirementDtoDto'));
    });

    test('enumSchemaToClassName adds Enum suffix', () {
      expect(enumSchemaToClassName('UserType'), equals('UserTypeEnum'));
      expect(enumSchemaToClassName('UserTypeEnum'), equals('UserTypeEnum'));
    });

    test('safeEnumName handles keywords and special chars', () {
      expect(safeEnumName('class'), equals(r'$class'));
      expect(safeEnumName('value-1'), equals('valueNeg1'));
      expect(safeEnumName('123abc'), equals('value123abc'));
    });

    test('inlineDtoName generates correct name', () {
      expect(inlineDtoName('Captcha', '/api/admin/captcha/generate'), equals('CaptchaGenerateDto'));
      expect(inlineDtoName('DocumentGroup', '/api/admin/document-group/batch-delete'), equals('DocumentGroupBatchDeleteDto'));
    });
  });

  group('TypeMapper', () {
    test('maps basic types correctly', () {
      final mapper = TypeMapper({});
      expect(mapper.mapType({'type': 'string'}), equals('String'));
      expect(mapper.mapType({'type': 'integer'}), equals('int'));
      expect(mapper.mapType({'type': 'number'}), equals('double'));
      expect(mapper.mapType({'type': 'boolean'}), equals('bool'));
    });

    test('maps array types correctly', () {
      final mapper = TypeMapper({});
      expect(
        mapper.mapType({
          'type': 'array',
          'items': {'type': 'string'},
        }),
        equals('List<String>'),
      );
    });

    test('maps binary field to MultipartFile only for request body', () {
      final mapper = TypeMapper({});
      // 请求体中的 binary 字段映射为 MultipartFile
      expect(mapper.mapType({'type': 'string', 'format': 'binary'}, forRequestBody: true), equals('MultipartFile'));
      // 非请求体中的 binary 字段映射为 String
      expect(mapper.mapType({'type': 'string', 'format': 'binary'}), equals('String'));
      // 普通 string 不受影响
      expect(mapper.mapType({'type': 'string'}), equals('String'));
    });

    test('isBinaryField detects binary fields', () {
      expect(TypeMapper.isBinaryField({'type': 'string', 'format': 'binary'}), isTrue);
      expect(TypeMapper.isBinaryField({'type': 'string', 'format': 'date'}), isFalse);
      expect(TypeMapper.isBinaryField({'type': 'string'}), isFalse);
      expect(TypeMapper.isBinaryField({'type': 'integer', 'format': 'binary'}), isFalse);
    });
  });

  group('CodeGenConfig', () {
    test('default config is valid', () {
      const config = CodeGenConfig(sourceUrl: 'http://example.com/swagger.json');
      expect(config.isValid, isTrue);
      expect(config.error, isNull);
    });

    test('config without source is invalid', () {
      const config = CodeGenConfig();
      expect(config.isValid, isFalse);
      expect(config.error, isNotNull);
    });

    test('mergeWithCli overrides values', () {
      const config = CodeGenConfig(sourceUrl: 'http://old.com');
      final merged = config.mergeWithCli(url: 'http://new.com');
      expect(merged.sourceUrl, equals('http://new.com'));
      expect(merged.sourceFile, isNull);
    });
  });
}
