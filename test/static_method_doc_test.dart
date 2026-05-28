import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:tdesign_flutter_tools/smart_create.dart';
import 'package:test/test.dart';

import 'support/component_paths.dart';
import 'support/fixture_paths.dart';

List<ParsedComponentInfoInfo> _analyse(List<String> names, String relPath) {
  final String path = componentSourcePath(relPath);
  final col = AnalysisContextCollection(
    includedPaths: [path],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );
  final parsed =
      col.contextFor(path).currentSession.getParsedUnit(path)
          as ParsedUnitResult;
  return ComponentRule(
    parsedUnitResult: parsed,
    isGrammarParser: false,
    nameList: names,
    sourceFileName: relPath.split('/').last,
  ).analyse();
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
  test('method doc [param] lines fill param table when fieldMap has no match', () {
    final String path = fixtureSourcePath('static_method_doc_fixture.dart');
    final col = AnalysisContextCollection(
      includedPaths: [path],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );
    final parsed =
        col.contextFor(path).currentSession.getParsedUnit(path) as ParsedUnitResult;
    final info = ComponentRule(
      parsedUnitResult: parsed,
      isGrammarParser: false,
      nameList: ['DemoPopup'],
      sourceFileName: 'static_method_doc_fixture.dart',
    ).analyse().first;

    final context = _staticParam(info, 'show', 'context');
    final options = _staticParam(info, 'show', 'options');
    final method = info.componentInfo!.staticMethodList
        .firstWhere((StaticMethodInfo m) => m.name == 'show');

    expect(context!.introduction, '用于查找 `Navigator` 并展示浮层。');
    expect(options!.introduction, contains('`DemoOptions.bottom`'));
    expect(method.introduction, contains('`PopupRoute`'));
    expect(method.introduction, isNot(contains('[context]')));
  });

  test('TMessage.showMessage params get introductions from fieldMap', () {
    final info =
        _analyse([
          'TMessage',
        ], 'lib/src/components/message/t_message.dart').first;

    final onDurationEnd = _staticParam(info, 'showMessage', 'onDurationEnd');
    final onLinkClick = _staticParam(info, 'showMessage', 'onLinkClick');

    expect(onDurationEnd, isNotNull);
    expect(onDurationEnd!.introduction, '计时结束后触发');
    expect(onLinkClick, isNotNull);
    expect(onLinkClick!.introduction, '点击链接文本时触发');
  });

  test('generateApiInfoFile renders DemoPopup.show with formatted docs', () async {
    final String path = fixtureSourcePath('static_method_doc_fixture.dart');
    final col = AnalysisContextCollection(
      includedPaths: [path],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );
    final parsed =
        col.contextFor(path).currentSession.getParsedUnit(path) as ParsedUnitResult;
    final info = ComponentRule(
      parsedUnitResult: parsed,
      isGrammarParser: false,
      nameList: ['DemoPopup'],
      sourceFileName: 'static_method_doc_fixture.dart',
    ).analyse().first;
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'tdesign_demo_popup_doc_',
    );

    try {
      final creator = SmartCreator(
        nameList: ['DemoPopup'],
        basePath: tempDir.path,
        folderName: 'demo_popup',
        output: '',
        isFileMode: true,
        onlyApi: true,
        isGrammarParser: false,
      );
      await creator.generateApiInfoFile([info]);
      final content =
          await File(p.join(tempDir.path, 'demo_popup_api.md')).readAsString();
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
  });

  test('generateApiInfoFile expands static methods with param docs', () async {
    final info =
        _analyse([
          'TMessage',
        ], 'lib/src/components/message/t_message.dart').first;
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'tdesign_static_method_doc_',
    );

    try {
      final creator = SmartCreator(
        nameList: ['TMessage'],
        basePath: tempDir.path,
        folderName: 'message',
        output: '',
        isFileMode: true,
        onlyApi: true,
        isGrammarParser: false,
      );

      await creator.generateApiInfoFile([info]);

      final content =
          await File(p.join(tempDir.path, 'message_api.md')).readAsString();
      expect(content, contains('#### 静态方法'));
      expect(content, contains('##### TMessage.showMessage'));
      expect(content, contains('返回类型：`void`'));
      expect(
        content,
        contains('| onDurationEnd | VoidCallback? | - | 计时结束后触发 |'),
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
          _analyse([
            'TCascader',
            'TMultiCascader',
            'TCascaderAction',
          ], 'lib/src/components/cascader/t_cascader.dart').first;
      final StaticMethodInfo method = info.componentInfo!.staticMethodList
          .firstWhere((StaticMethodInfo m) => m.name == 'showMultiCascader');

      expect(method.forwardedTargetName, 'TMultiCascader');
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
      final creator = SmartCreator(
        nameList: ['TCascader', 'TMultiCascader', 'TCascaderAction'],
        basePath: Directory.current.path,
        path:
            '../tdesign-flutter/tdesign-component/lib/src/components/cascader',
        folderName: 'cascader',
        output: '',
        isFileMode: false,
        onlyApi: true,
        isGrammarParser: false,
      );
      final List<ParsedComponentInfoInfo> infos = await creator.parseOnly(
        quiet: true,
      );
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'tdesign_cascader_static_method_doc_',
      );

      try {
        final outputCreator = SmartCreator(
          nameList: ['TCascader', 'TMultiCascader', 'TCascaderAction'],
          basePath: tempDir.path,
          folderName: 'cascader',
          output: '',
          isFileMode: false,
          onlyApi: true,
          isGrammarParser: false,
        );

        await outputCreator.generateApiInfoFile(infos);

        final content =
            await File(p.join(tempDir.path, 'cascader_api.md')).readAsString();
        expect(content, contains('##### TCascader.showMultiCascader'));
        expect(content, contains('| title | String? | - | 选择器标题 |'));
        expect(
          content,
          contains('| onChange | MultiCascaderCallback | - | 值发生变更时触发 |'),
        );
        expect(
          content,
          contains('| action | TCascaderAction? | - | 自定义选择器右上角按钮 |'),
        );
        expect(content, contains('| barrierColor | Color? | - | - |'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
  );
}
