import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:tdesign_flutter_tools/demo_rule.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:tdesign_flutter_tools/smart_create.dart';

ParsedComponentInfoInfo _parseComponent(String source, List<String> names) {
  ParsedComponentInfoInfo? result;
  parseString(content: source).unit.accept(
    ComponentAstVisitor(
      nameList: names,
      onParsedComponentInfoInfo: (ParsedComponentInfoInfo info) {
        result = info;
      },
    ),
  );
  return result!;
}

void main() {
  group('component api parser', () {
    test(
      'reads constructor parameter docs from inline docs, block docs, and fields',
      () {
        final ParsedComponentInfoInfo info = _parseComponent(
          '''
/// Fixture widget.
class FixtureWidget extends StatelessWidget {
  /// Creates a fixture widget.
  ///
  /// [blockOnly] comes from the constructor block comment.
  const FixtureWidget({
    /// Inline text description.
    String? inlineText = 'hello',
    required this.fromField,
    bool blockOnly = false,
    super.key,
  });

  /// Field formal description.
  final int fromField;
}
''',
          <String>['FixtureWidget'],
        );

        final Map<String, PropertyInfo> properties = <String, PropertyInfo>{
          for (final PropertyInfo property in info.propertyList)
            property.name: property,
        };

        expect(properties['inlineText']!.type, 'String?');
        expect(properties['inlineText']!.defaultValue, "'hello'");
        expect(
          properties['inlineText']!.introduction,
          'Inline text description.',
        );
        expect(properties['fromField']!.type, 'int');
        expect(
          properties['fromField']!.introduction,
          'Field formal description.',
        );
        expect(properties['blockOnly']!.defaultValue, 'false');
        expect(
          properties['blockOnly']!.introduction,
          'comes from the constructor block comment.',
        );
        expect(properties['key']!.name, 'key');
      },
    );

    test('reads static method parameter docs independently', () {
      final ParsedComponentInfoInfo info = _parseComponent(
        '''
class ButtonResolver {
  /// Resolves the final style.
  ///
  /// [variant] visual variant.
  /// [colorScheme] semantic color scheme.
  /// [disabled] whether the button is disabled.
  static ButtonStyle resolve({
    required ButtonVariant variant,
    Color? colorScheme,
    bool disabled = false,
  }) {
    throw UnimplementedError();
  }
}
''',
        <String>['ButtonResolver'],
      );

      final StaticMethodInfo method =
          info.componentInfo!.staticMethodList.single;
      final Map<String, PropertyInfo> params = <String, PropertyInfo>{
        for (final PropertyInfo param in method.params) param.name: param,
      };

      expect(method.name, 'resolve');
      expect(method.introduction, 'Resolves the final style.');
      expect(params['variant']!.type, 'ButtonVariant');
      expect(params['variant']!.isRequired, isTrue);
      expect(params['variant']!.introduction, 'visual variant.');
      expect(params['colorScheme']!.introduction, 'semantic color scheme.');
      expect(params['disabled']!.defaultValue, 'false');
      expect(
        params['disabled']!.introduction,
        'whether the button is disabled.',
      );
    });

    test('ignores private named constructors in public api output', () {
      final ParsedComponentInfoInfo info = _parseComponent(
        '''
class ButtonResolver {
  const ButtonResolver._();

  /// Creates a public variant.
  const ButtonResolver.public();
}
''',
        <String>['ButtonResolver'],
      );

      expect(
        info.componentInfo!.constructorMethodList.map((method) => method.name),
        <String>['public'],
      );
    });

    test('renders static method params as a dedicated api table', () async {
      final ParsedComponentInfoInfo info = _parseComponent(
        '''
class ButtonResolver {
  /// Resolves the final style.
  ///
  /// [variant] visual variant.
  /// [disabled] whether the button is disabled.
  static ButtonStyle resolve({
    required ButtonVariant variant,
    bool disabled = false,
  }) {
    throw UnimplementedError();
  }
}
''',
        <String>['ButtonResolver'],
      );
      final Directory outputDir = Directory.systemTemp.createTempSync(
        'tdesign_tools_api_test_',
      );
      addTearDown(() => outputDir.deleteSync(recursive: true));

      await SmartCreator(
        nameList: <String>['ButtonResolver'],
        basePath: '',
        output: '${outputDir.path}/',
        folderName: 'button_resolver',
      ).generateApiInfoFile(<ParsedComponentInfoInfo>[info]);

      final String markdown =
          File('${outputDir.path}/button_resolver_api.md').readAsStringSync();
      expect(markdown, contains('##### ButtonResolver.resolve'));
      expect(markdown, contains('Resolves the final style.'));
      expect(markdown, contains('返回类型：`ButtonStyle`'));
      expect(
        markdown,
        contains('| variant | ButtonVariant | - | visual variant. |'),
      );
      expect(
        markdown,
        contains(
          '| disabled | bool | false | whether the button is disabled. |',
        ),
      );
    });
  });

  group('demo parser', () {
    test('reads demo priority, class name, and comments', () {
      final DemoVisitor visitor = DemoVisitor();
      parseString(
        content: '''
/// 基础用法
/// 展示默认状态
@Priority(2)
class ButtonDemo1 extends StatelessWidget {}
''',
      ).unit.accept(visitor);

      expect(visitor.demoInfo.isValid, isTrue);
      expect(visitor.demoInfo.name, 'ButtonDemo1');
      expect(visitor.demoInfo.priority, 2);
      expect(visitor.demoInfo.introductions, <String>['基础用法', '展示默认状态']);
    });
  });
}
