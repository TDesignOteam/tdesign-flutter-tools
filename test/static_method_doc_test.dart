import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:path/path.dart' as p;
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:tdesign_flutter_tools/smart_create.dart';
import 'package:test/test.dart';

import 'support/analyzer_context.dart';
import 'support/fixture_paths.dart';

List<ParsedComponentInfoInfo> _analyseFixture(
  List<String> names,
  String fixtureFile,
) {
  final String path = fixtureSourcePath(fixtureFile);
  final col = testAnalysisContextCollection(includedPaths: [path]);
  final parsed =
      col.contextFor(path).currentSession.getParsedUnit(path)
          as ParsedUnitResult;
  return ComponentRule(
    parsedUnitResult: parsed,
    nameList: names,
    sourceFileName: fixtureFile,
  ).analyse();
}

Future<String> _generateFixtureApi({
  required List<String> names,
  required String fixtureFile,
  required String folderName,
  required bool getComments,
}) async {
  final List<ParsedComponentInfoInfo> infos = _analyseFixture(
    names,
    fixtureFile,
  );
  final Directory tempDir = await Directory.systemTemp.createTemp(
    'tdesign_api_gen_${folderName}_',
  );
  try {
    final CommandInfo commandInfo =
        CommandInfo()
          ..isGetComments = getComments
          ..isOnlyApi = true;
    final SmartCreator creator = SmartCreator(
      nameList: names,
      basePath: tempDir.path,
      folderName: folderName,
      output: '',
      isFileMode: true,
      onlyApi: true,
      commandInfo: commandInfo,
    );
    await creator.generateApiInfoFile(infos);
    return File(p.join(tempDir.path, '${folderName}_api.md')).readAsString();
  } finally {
    await tempDir.delete(recursive: true);
  }
}

PropertyInfo? _staticParam(
  ParsedComponentInfoInfo info,
  String methodName,
  String paramName,
) {
  final StaticMethodInfo method = info.componentInfo!.staticMethodList
      .firstWhere((StaticMethodInfo m) => m.name == methodName);
  for (final PropertyInfo param in method.params) {
    if (param.name == paramName) {
      return param;
    }
  }
  return null;
}

void main() {
  test(
    'method doc [param] lines fill param table when fieldMap has no match',
    () {
      final String path = fixtureSourcePath('static_method_doc_fixture.dart');
      final col = testAnalysisContextCollection(includedPaths: [path]);
      final parsed =
          col.contextFor(path).currentSession.getParsedUnit(path)
              as ParsedUnitResult;
      final info =
          ComponentRule(
            parsedUnitResult: parsed,
            nameList: ['DemoPopup'],
            sourceFileName: 'static_method_doc_fixture.dart',
          ).analyse().first;

      final context = _staticParam(info, 'show', 'context');
      final options = _staticParam(info, 'show', 'options');
      final method = info.componentInfo!.staticMethodList.firstWhere(
        (StaticMethodInfo m) => m.name == 'show',
      );

      expect(context!.introduction, '用于查找 `Navigator` 并展示浮层。');
      expect(options!.introduction, contains('`DemoOptions.bottom`'));
      expect(method.introduction, contains('`PopupRoute`'));
      expect(method.introduction, isNot(contains('[context]')));
    },
  );

  test('generateApiInfoFile omits 简介 without --get-comments', () async {
    final String path = fixtureSourcePath('static_method_doc_fixture.dart');
    final col = testAnalysisContextCollection(includedPaths: [path]);
    final parsed =
        col.contextFor(path).currentSession.getParsedUnit(path)
            as ParsedUnitResult;
    final info =
        ComponentRule(
          parsedUnitResult: parsed,
          nameList: ['DemoPopup'],
          sourceFileName: 'static_method_doc_fixture.dart',
        ).analyse().first;
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'tdesign_demo_popup_no_intro_',
    );

    try {
      final creator = SmartCreator(
        nameList: ['DemoPopup'],
        basePath: tempDir.path,
        folderName: 'demo_popup',
        output: '',
        isFileMode: true,
        onlyApi: true,
      );
      await creator.generateApiInfoFile([info]);
      final content =
          await File(p.join(tempDir.path, 'demo_popup_api.md')).readAsString();
      expect(content, isNot(contains('#### 简介')));
      expect(content, contains('##### DemoPopup.show'));
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'generateApiInfoFile renders DemoPopup.show with formatted docs',
    () async {
      final String path = fixtureSourcePath('static_method_doc_fixture.dart');
      final col = testAnalysisContextCollection(includedPaths: [path]);
      final parsed =
          col.contextFor(path).currentSession.getParsedUnit(path)
              as ParsedUnitResult;
      final info =
          ComponentRule(
            parsedUnitResult: parsed,
            nameList: ['DemoPopup'],
            sourceFileName: 'static_method_doc_fixture.dart',
          ).analyse().first;
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'tdesign_demo_popup_doc_',
      );

      try {
        final CommandInfo commandInfo =
            CommandInfo()
              ..isGetComments = true
              ..isOnlyApi = true;
        final creator = SmartCreator(
          nameList: ['DemoPopup'],
          basePath: tempDir.path,
          folderName: 'demo_popup',
          output: '',
          isFileMode: true,
          onlyApi: true,
          commandInfo: commandInfo,
        );
        await creator.generateApiInfoFile([info]);
        final content =
            await File(
              p.join(tempDir.path, 'demo_popup_api.md'),
            ).readAsString();
        expect(content, contains('#### 简介'));
        expect(content, contains('通过 `show` 命令式打开'));
        expect(content, contains('##### DemoPopup.show'));
        expect(content, contains('打开浮层并压入独立 `PopupRoute`'));
        expect(
          content,
          contains('| context | Object | - | 用于查找 `Navigator` 并展示浮层。 |'),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
  );

  test('generateApiInfoFile expands static methods with param docs', () async {
    final info =
        _analyseFixture(['DemoPopup'], 'static_method_doc_fixture.dart').first;
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'tdesign_static_method_doc_',
    );

    try {
      final creator = SmartCreator(
        nameList: ['DemoPopup'],
        basePath: tempDir.path,
        folderName: 'demo_popup',
        output: '',
        isFileMode: true,
        onlyApi: true,
      );

      await creator.generateApiInfoFile([info]);

      final content =
          await File(p.join(tempDir.path, 'demo_popup_api.md')).readAsString();
      expect(content, contains('#### 静态方法'));
      expect(content, contains('##### DemoPopup.show'));
      expect(content, contains('返回类型：`DemoHandle`'));
      expect(
        content,
        contains('| context | Object | - | 用于查找 `Navigator` 并展示浮层。 |'),
      );
      expect(content, isNot(contains('| 名称 | 返回类型 | 参数 | 说明 |')));
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'TCascader.showMultiCascader captures explicit constructor forwarding',
    () {
      final info =
          _analyseFixture([
            'DemoCascader',
            'DemoMultiCascader',
            'DemoCascaderAction',
          ], 'static_method_doc_fixture.dart').first;
      final StaticMethodInfo method = info.componentInfo!.staticMethodList
          .firstWhere((StaticMethodInfo m) => m.name == 'showMultiCascader');

      expect(method.forwardedTargetName, 'DemoMultiCascader');
      expect(method.forwardedConstructorName, isNull);
      expect(method.forwardedParamMap['title'], 'title');
      expect(method.forwardedParamMap['onChange'], 'onChange');
      expect(method.forwardedParamMap['action'], 'action');
      expect(method.forwardedParamMap.containsKey('barrierColor'), isFalse);
    },
  );

  test(
    'generateApiInfoFile fills wrapper static method docs only for explicit constructor forwarding',
    () async {
      final List<ParsedComponentInfoInfo> infos = _analyseFixture([
        'DemoCascader',
        'DemoMultiCascader',
        'DemoCascaderAction',
      ], 'static_method_doc_fixture.dart');
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'tdesign_cascader_static_method_doc_',
      );

      try {
        final outputCreator = SmartCreator(
          nameList: ['DemoCascader', 'DemoMultiCascader', 'DemoCascaderAction'],
          basePath: tempDir.path,
          folderName: 'cascader',
          output: '',
          isFileMode: false,
          onlyApi: true,
        );

        await outputCreator.generateApiInfoFile(infos);

        final content =
            await File(p.join(tempDir.path, 'cascader_api.md')).readAsString();
        expect(content, contains('##### DemoCascader.showMultiCascader'));
        expect(content, contains('| title | String? | - | 选择器标题 |'));
        expect(
          content,
          contains('| onChange | DemoChangeCallback? | - | 值发生变更时触发 |'),
        );
        expect(
          content,
          contains('| action | DemoCascaderAction? | - | 自定义选择器右上角按钮 |'),
        );
        expect(content, contains('| barrierColor | Object? | - | - |'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
  );

  group('generateApiInfoFile --get-comments and section separators', () {
    test('does not insert empty ``` fence between multiple types', () async {
      final String content = await _generateFixtureApi(
        names: <String>['TypeAlpha', 'TypeBeta'],
        fixtureFile: 'multi_type_intro_fixture.dart',
        folderName: 'multi_type',
        getComments: true,
      );

      expect(content, contains('### TypeAlpha'));
      expect(content, contains('### TypeBeta'));
      expect(content, isNot(contains('```\n```')));
      expect(content, isNot(matches(RegExp(r'```\s*\n\s*```'))));

      final RegExpMatch? sectionGap = RegExp(
        r'### TypeAlpha[\s\S]*?\n\n### TypeBeta',
      ).firstMatch(content);
      expect(sectionGap, isNotNull);
      expect(sectionGap!.group(0), isNot(contains('```')));
    });

    test(
      'with --get-comments writes intro without fenced code blocks',
      () async {
        final String content = await _generateFixtureApi(
          names: <String>['TypeAlpha'],
          fixtureFile: 'multi_type_intro_fixture.dart',
          folderName: 'multi_type_intro',
          getComments: true,
        );

        expect(content, contains('#### 简介'));
        expect(content, contains('第一个组件说明'));
        expect(content, isNot(contains('TypeAlpha.demo()')));
        expect(content, isNot(matches(RegExp(r'#### 简介[\s\S]*```'))));
      },
    );

    test('without --get-comments omits intro for all kinds', () async {
      final String content = await _generateFixtureApi(
        names: <String>['TypeAlpha', 'TypeBeta'],
        fixtureFile: 'multi_type_intro_fixture.dart',
        folderName: 'multi_type_no_intro',
        getComments: false,
      );

      expect(content, isNot(contains('#### 简介')));
      expect(content, isNot(contains('第一个组件说明')));
      expect(content, isNot(contains('第二个组件说明')));
    });
  });
}
