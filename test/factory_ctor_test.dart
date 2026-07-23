import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:tdesign_flutter_tools/smart_create.dart';
import 'package:test/test.dart';

import 'support/analyzer_context.dart';

List<ParsedComponentInfoInfo> _analyseAbsolutePath(
  List<String> names,
  String absolutePath,
) {
  final col = testAnalysisContextCollection(includedPaths: [absolutePath]);
  final parsed =
      col.contextFor(absolutePath).currentSession.getParsedUnit(absolutePath)
          as ParsedUnitResult;
  return ComponentRule(
    parsedUnitResult: parsed,
    nameList: names,
    sourceFileName: absolutePath.split('/').last,
  ).analyse();
}

void main() {
  test('factory constructors capture redirect forwarding map', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'tdesign_factory_forwarding_',
    );
    final File source = File('${tempDir.path}/demo_options.dart');
    await source.writeAsString('''
class DemoOptions {
  const DemoOptions({this.a, this.b, this.c});

  final int? a;
  final int? b;
  final int? c;

  factory DemoOptions.bottom({int? a, int? b, int? onlyBottom}) =>
      DemoOptions(a: a, b: b, c: onlyBottom);

  factory DemoOptions.top({int? a, int? b}) => DemoOptions(a: a, b: b);
}
''');
    try {
      final list = _analyseAbsolutePath(['DemoOptions'], source.path);
      final info = list.first;
      final StaticMethodInfo bottom = info.componentInfo!.constructorMethodList
          .firstWhere((StaticMethodInfo m) => m.name == 'bottom');
      final StaticMethodInfo top = info.componentInfo!.constructorMethodList
          .firstWhere((StaticMethodInfo m) => m.name == 'top');

      expect(bottom.forwardedTargetName, 'DemoOptions');
      expect(bottom.forwardedConstructorName, isNull);
      expect(bottom.forwardedParamMap['a'], 'a');
      expect(bottom.forwardedParamMap['b'], 'b');
      expect(bottom.forwardedParamMap['onlyBottom'], 'c');
      expect(top.forwardedParamMap['a'], 'a');
      expect(top.forwardedParamMap['b'], 'b');
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'library-private named constructors are omitted from API docs',
    () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'tdesign_private_ctor_',
      );
      final File source = File('${tempDir.path}/demo_handle.dart');
      await source.writeAsString('''
class DemoHandle {
  DemoHandle._({required this.value});

  /// 句柄上的值
  final int value;

  void refresh() {}
}

class DemoEntry {
  const DemoEntry._();

  static void show() {}
}
''');
      try {
        final list = _analyseAbsolutePath([
          'DemoHandle',
          'DemoEntry',
        ], source.path);
        final ParsedComponentInfoInfo handleInfo = list.firstWhere(
          (ParsedComponentInfoInfo item) =>
              item.componentInfo?.name == 'DemoHandle',
        );
        final ParsedComponentInfoInfo entryInfo = list.firstWhere(
          (ParsedComponentInfoInfo item) =>
              item.componentInfo?.name == 'DemoEntry',
        );

        expect(handleInfo.componentInfo!.constructorMethodList, isEmpty);
        expect(
          handleInfo.extraPropertyList.map((PropertyInfo p) => p.name),
          contains('value'),
        );
        expect(entryInfo.componentInfo!.constructorMethodList, isEmpty);

        final Directory outDir = Directory('${tempDir.path}/out');
        await outDir.create(recursive: true);
        final SmartCreator creator = SmartCreator(
          isFileMode: true,
          onlyApi: true,
          nameList: const <String>['DemoHandle', 'DemoEntry'],
          basePath: '${tempDir.path}/',
          path: 'demo_handle.dart',
          folderName: 'demo',
          output: 'out/',
        );
        await creator.generateApiInfoFile(list);
        final String content =
            await File('${outDir.path}/demo_api.md').readAsString();
        expect(content, isNot(contains('DemoHandle._')));
        expect(content, isNot(contains('DemoEntry._')));
        expect(content, contains('| value |'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
  );

  test(
    'generateApiInfoFile orders factory constructors before default constructor',
    () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'tdesign_api_section_order_',
      );
      final File source = File('${tempDir.path}/demo_options.dart');
      await source.writeAsString('''
class DemoOptions {
  const DemoOptions({this.a});

  final int? a;

  factory DemoOptions.bottom({int? a}) => DemoOptions(a: a);
}
''');
      try {
        final list = _analyseAbsolutePath(['DemoOptions'], source.path);
        final Directory outDir = Directory('${tempDir.path}/out');
        await outDir.create(recursive: true);
        final SmartCreator creator = SmartCreator(
          isFileMode: true,
          onlyApi: true,
          nameList: const <String>['DemoOptions'],
          basePath: '${tempDir.path}/',
          path: 'demo_options.dart',
          folderName: 'demo',
          output: 'out/',
        );
        await creator.generateApiInfoFile(list);
        final String content =
            await File('${outDir.path}/demo_api.md').readAsString();
        expect(
          content.indexOf('#### 工厂构造方法'),
          lessThan(content.indexOf('#### 默认构造方法')),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
  );
}
