import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:tdesign_flutter_tools/smart_create.dart';
import 'package:test/test.dart';
import 'package:markdown/markdown.dart' as md;

import 'support/analyzer_context.dart';
import 'support/fixture_paths.dart';

void main() {
  test(
    'documents concrete handles, accessors, constructors and extensions',
    () async {
      final path = fixtureSourcePath('public_members_fixture.dart');
      final context = testAnalysisContextCollection(
        includedPaths: <String>[path],
      );
      final parsed =
          context.contextFor(path).currentSession.getParsedUnit(path)
              as ParsedUnitResult;
      final names = <String>[
        'DemoHandle',
        'DemoController',
        'DemoOptions',
        'DemoHelpers',
        'GenericBuilder',
        'DemoGeneric',
        'DemoRedirect',
      ];
      final infos =
          ComponentRule(parsedUnitResult: parsed, nameList: names).analyse();
      final handle = infos.firstWhere(
        (info) => info.componentInfo!.name == 'DemoHandle',
      );
      expect(
        handle.extraPropertyList.map((field) => field.name),
        containsAll(<String>['isShowing', 'label']),
      );
      expect(
        handle.extraPropertyList
            .firstWhere((field) => field.name == 'label')
            .type,
        'String',
      );
      expect(
        handle.componentInfo!.instanceMethodList.map((method) => method.name),
        <String>['close', 'build'],
      );
      final options = infos.firstWhere(
        (info) => info.componentInfo!.name == 'DemoOptions',
      );
      expect(
        options.extraPropertyList.map((field) => field.name),
        containsAll(<String>['first', 'second', 'publicMixed']),
      );
      final controller = infos.firstWhere(
        (info) => info.componentInfo!.name == 'DemoController',
      );
      expect(controller.componentInfo!.hasDefaultConstructor, isTrue);
      final generic = infos.firstWhere(
        (info) => info.componentInfo!.name == 'DemoGeneric',
      );
      final methods = generic.componentInfo!.instanceMethodList;
      expect(
        methods.map((method) => method.name),
        containsAll(['jump', 'lookup', 'read', 'copyWith', '[]']),
      );
      expect(
        methods
            .firstWhere((method) => method.name == 'jump')
            .params
            .single
            .introduction,
        isEmpty,
      );
      expect(
        methods
            .firstWhere((method) => method.name == 'lookup')
            .params
            .single
            .introduction,
        isEmpty,
      );
      expect(
        methods
            .firstWhere((method) => method.name == 'lookup')
            .params
            .single
            .type,
        'String?',
      );
      final temp = await Directory.systemTemp.createTemp(
        'tdesign_public_members_',
      );
      try {
        final creator = SmartCreator(
          isFileMode: true,
          onlyApi: true,
          nameList: names,
          basePath: temp.path,
          output: '',
          folderName: 'members',
          commandInfo:
              CommandInfo()
                ..folderName = 'members'
                ..output = '${temp.path}/'
                ..isGetComments = true
                ..strictNames = true,
        );
        await creator.generateApiInfoFile(infos);
        final markdown = File('${temp.path}/members_api.md').readAsStringSync();
        expect(markdown, contains('### DemoHelpers'));
        expect(markdown, contains('| values | List&lt;String&gt; |'));
        final html = md.markdownToHtml(
          markdown,
          extensionSet: md.ExtensionSet.gitHubWeb,
        );
        expect(html, contains('<td>List&lt;String&gt;</td>'));
        expect(html, isNot(contains('<String>')));
        expect(markdown, contains('typedef GenericBuilder<T>'));
        expect(markdown, contains('类型参数：`T extends Object`'));
        expect(markdown, contains('位置参数：`value, fallback`'));
        expect(markdown, contains('类型参数：`E extends Object`'));
        expect(markdown, contains('返回类型：`T?`'));
        expect(markdown, contains('##### DemoGeneric.copyWith'));
        expect(markdown, contains('##### DemoGeneric.[]'));
        expect(markdown, contains('##### DemoRedirect.fixed'));
        expect(markdown, isNot(contains('const factory DemoRedirect.fixed(')));
        expect(markdown, isNot(contains('### UnregisteredEnum')));
        expect(markdown, contains('| canClose | bool |'));
        expect(markdown, contains('##### DemoHelpers.dismiss'));
        expect(markdown, contains('#### 构造方法'));
        expect(markdown, contains('##### DemoController\n'));
        expect(markdown, isNot(contains('```dart\nDemoController()\n```')));
        expect(markdown, contains('### DemoController\n'));
        expect(markdown, contains('Whether closure is animated.'));
        expect(
          markdown,
          contains(
            '| animated | bool | true | Whether closure is animated. | 否 |',
          ),
        );
        expect(markdown, isNot(contains('| build |')));
        expect(markdown, isNot(contains('##### DemoHandle._hidden')));
        expect(markdown, contains('| publicMixed | int | 3 |'));
        expect(markdown, contains('| first | int | 1 |'));
      } finally {
        await temp.delete(recursive: true);
      }
    },
  );
}
