import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:path/path.dart' as p;
import 'package:tdesign_flutter_tools/api_completeness.dart';
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:tdesign_flutter_tools/smart_create.dart';
import 'package:test/test.dart';

import 'support/analyzer_context.dart';
import 'support/fixture_paths.dart';

List<ParsedComponentInfoInfo> _analyse(List<String> names) {
  final String path = fixtureSourcePath('top_level_function_fixture.dart');
  final context = testAnalysisContextCollection(includedPaths: <String>[path]);
  final parsed =
      context.contextFor(path).currentSession.getParsedUnit(path)
          as ParsedUnitResult;
  return ComponentRule(
    parsedUnitResult: parsed,
    nameList: names,
    sourceFileName: 'top_level_function_fixture.dart',
  ).analyse();
}

void main() {
  test('parses an explicitly named public top-level function', () {
    final List<ParsedComponentInfoInfo> infos = _analyse(<String>[
      'DemoDrawer',
      'showDemoDrawer',
    ]);
    final ComponentInfo function = infos
        .map((ParsedComponentInfoInfo info) => info.componentInfo!)
        .firstWhere((ComponentInfo info) => info.name == 'showDemoDrawer');

    expect(function.kind, 'function');
    expect(function.topLevelFunction!.returnType, 'DemoDrawerHandle');
    expect(function.topLevelFunction!.introduction, contains('浮层展示'));
    expect(
      function.topLevelFunction!.params.map((PropertyInfo item) => item.name),
      <String>['context', 'drawer', 'placement', 'showOverlay'],
    );
    expect(function.topLevelFunction!.params[1].isRequired, isTrue);
    expect(
      function.topLevelFunction!.params[2].defaultValue,
      'DemoDrawerPlacement.right',
    );
    expect(function.topLevelFunction!.params[3].defaultValue, 'true');
    expect(
      infos.any(
        (ParsedComponentInfoInfo info) =>
            info.componentInfo?.name == '_privateHelper',
      ),
      isFalse,
    );
  });

  test('generates a dedicated top-level function API section', () async {
    final List<ParsedComponentInfoInfo> infos = _analyse(<String>[
      'DemoDrawer',
      'showDemoDrawer',
    ]);
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'tdesign_top_level_function_',
    );
    try {
      final SmartCreator creator = SmartCreator(
        nameList: <String>['DemoDrawer', 'showDemoDrawer'],
        basePath: tempDir.path,
        folderName: 'drawer',
        output: '',
        isFileMode: true,
        onlyApi: true,
      );
      await creator.generateApiInfoFile(infos);
      final String markdown =
          await File(p.join(tempDir.path, 'drawer_api.md')).readAsString();

      expect(markdown, contains('### showDemoDrawer'));
      expect(markdown, contains('#### 顶层函数'));
      expect(markdown, contains('返回类型：`DemoDrawerHandle`'));
      expect(markdown, contains('| drawer | DemoDrawer | - | 只描述抽屉内容。 |'));
      expect(
        markdown,
        contains(
          '| placement | DemoDrawerPlacement | DemoDrawerPlacement.right | 控制抽屉滑出的方向。 |',
        ),
      );
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('completeness audit compares top-level function parameters', () async {
    final List<ParsedComponentInfoInfo> infos = _analyse(<String>[
      'DemoDrawer',
      'showDemoDrawer',
    ]);
    final ComponentInfo function = infos
        .map((ParsedComponentInfoInfo info) => info.componentInfo!)
        .firstWhere((ComponentInfo info) => info.name == 'showDemoDrawer');
    const String section = '''### showDemoDrawer
#### 顶层函数

返回类型：`DemoDrawerHandle`

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| context | Object | - | - |
| drawer | DemoDrawer | - | - |
''';

    final List<CompletenessIssue> issues = functionDocumentationIssues(
      'drawer',
      function,
      section,
    );
    expect(
      issues.map((CompletenessIssue issue) => issue.message),
      contains(contains('placement')),
    );
    expect(
      issues.map((CompletenessIssue issue) => issue.message),
      contains(contains('showOverlay')),
    );
  });
}
