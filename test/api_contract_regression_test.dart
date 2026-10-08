import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:tdesign_flutter_tools/api_completeness.dart';
import 'package:tdesign_flutter_tools/api_markdown.dart';
import 'package:tdesign_flutter_tools/api_signature.dart';
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:tdesign_flutter_tools/smart_create.dart';
import 'package:tdesign_flutter_tools/util.dart';
import 'package:test/test.dart';

List<ParsedComponentInfoInfo> parse(String source, List<String> names) {
  final infos = <ParsedComponentInfoInfo>[];
  parseString(content: source).unit.accept(
    ComponentAstVisitor(nameList: names, onParsedComponentInfoInfo: infos.add),
  );
  return infos;
}

List<String> tokens(String source) {
  final result = <String>[];
  Token? token =
      parseString(content: source, throwIfDiagnostics: false).unit.beginToken;
  while (token != null && !token.isEof) {
    if (!token.isSynthetic && token.lexeme != ',') result.add(token.lexeme);
    token = token.next;
  }
  return result;
}

Future<String> generate(String source, List<String> names) async {
  final temp = await Directory.systemTemp.createTemp('api_contract_');
  try {
    await SmartCreator(
      nameList: names,
      basePath: temp.path,
      output: '',
      folderName: 'contract',
      commandInfo:
          CommandInfo()
            ..strictNames = true
            ..isGetComments = true,
    ).generateApiInfoFile(parse(source, names));
    return File('${temp.path}/contract_api.md').readAsStringSync();
  } finally {
    await temp.delete(recursive: true);
  }
}

void main() {
  test(
    'CLI generation passes validate and a removed parameter fails',
    () async {
      final temp = await Directory.systemTemp.createTemp('api_cli_contract_');
      try {
        final source = File('${temp.path}/lib/fixture.dart');
        await source.parent.create(recursive: true);
        await source.writeAsString('''
class Fixture {
  /// Create a requested count.
  Fixture({this.count = 1});
  /// Number of items.
  final int count;
}
''');
        final output = Directory('${temp.path}/example/assets/api');
        await output.create(recursive: true);
        final config = File('${temp.path}/config.json');
        await config.writeAsString('''
{"components":{"fixture":{"classes":["Fixture"],"source_folder":"lib","folder_name":"fixture"}}}
''');
        final cli = File('bin/main.dart').absolute.path;
        final environment = <String, String>{
          'DART_SDK':
              Directory(
                File(Platform.resolvedExecutable).parent.parent.path,
              ).path,
        };
        final generated = await Process.run(Platform.resolvedExecutable, [
          cli,
          'generate',
          '--folder',
          source.parent.path,
          '--name',
          'Fixture',
          '--folder-name',
          'fixture',
          '--output',
          '${output.path}/',
          '--only-api',
          '--get-comments',
          '--strict-names',
        ], environment: environment);
        expect(
          generated.exitCode,
          0,
          reason: '${generated.stdout}\n${generated.stderr}',
        );
        final args = [
          cli,
          'validate',
          '--component-root',
          temp.path,
          '--config',
          config.path,
        ];
        final valid = await Process.run(
          Platform.resolvedExecutable,
          args,
          environment: environment,
        );
        expect(valid.exitCode, 0, reason: '${valid.stdout}\n${valid.stderr}');
        final manifest = File('${temp.path}/tool/components.json');
        await manifest.parent.create(recursive: true);
        await manifest.writeAsString('''
{"schemaVersion":1,"components":[{"slug":"fixture","source":{"type":"file","path":"lib/fixture.dart"},"api":{"names":["Fixture"]}}]}
''');
        final fromManifest = await Process.run(Platform.resolvedExecutable, [
          cli,
          'validate',
          '--component-root',
          temp.path,
        ], environment: environment);
        expect(
          fromManifest.exitCode,
          0,
          reason: '${fromManifest.stdout}\n${fromManifest.stderr}',
        );
        expect(fromManifest.stdout, contains('1 组件'));
        final markdownFile = File('${output.path}/fixture_api.md');
        final markdown = await markdownFile.readAsString();
        expect(markdown, contains('##### 参数'));
        expect(markdown, contains('Create a requested count.'));
        await markdownFile.writeAsString(
          markdown.replaceAll(RegExp(r'^\| count \|.*\n', multiLine: true), ''),
        );
        final invalid = await Process.run(
          Platform.resolvedExecutable,
          args,
          environment: environment,
        );
        expect(invalid.exitCode, 1);
        expect(invalid.stdout, contains('缺少构造参数: [count]'));
      } finally {
        await temp.delete(recursive: true);
      }
    },
    // Four separate CLI launches compile on a cold CI runner.
    timeout: const Timeout(Duration(minutes: 2)),
  );

  for (final heading in ['', '#### 参数\n', '##### 参数\n']) {
    test('constructor reader accepts parameter heading $heading', () {
      final section =
          '''
### Fixture
#### 默认构造方法
```dart
Fixture({String text = ''' +
          "'''\n#### not a section\n'''" +
          '''})
```
$heading
| 参数 | 类型 | 默认值 | 说明 | 必填 |
| --- | --- | --- | --- | --- |
| count | - | 1 | Count. | 否 |
#### 公开属性
| 属性 | 类型 | 默认值 | 说明 |
| other | int | - | Other. |
''';
      expect(markdownDefaultCtorParamNames(section), {'count'});
      expect(markdownCtorParamsWithEmptyType(section), ['count']);
    });
  }

  test(
    'external methods and default/named/factory constructors generate',
    () async {
      final markdown = await generate(
        '''
class External {
  external External();
  external External.named(int value);
  external factory External.factory();
  external void run();
  external static void invoke();
}
''',
        ['External'],
      );
      for (final signature in [
        '#### 默认构造方法',
        '##### External.named',
        '参数形式：`External.named(value)`',
        '##### External.factory',
        'external void run()',
        'external static void invoke()',
      ]) {
        expect(markdown, contains(signature));
      }
    },
  );

  test(
    'signature tokens preserve multiline and interpolated string contents',
    () {
      for (final signature in [
        "Fixture({String text = '''line1\n  line2\n    line3'''})",
        r"Fixture({String text = '''line1"
            '\n  '
            r'${1 + 2}'
            '\n    '
            r"line3'''})",
      ]) {
        final rendered = formatApiSignature(
          signature,
          ownerDeclaration: 'class Fixture',
          kind: ApiCallableKind.constructor,
        );
        expect(tokens(rendered), tokens(signature));
      }
    },
  );

  test(
    'code table cells preserve whitespace, entities, pipes and generics',
    () {
      const value = "'''line1\n  line2\t&<String>|'''";
      final encoded = sanitizeApiType(value);
      final decoded = encoded
          .replaceAll('&#10;', '\n')
          .replaceAll('&#9;', '\t')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&amp;', '&')
          .replaceAll(r'\|', '|');
      expect(decoded, value);
      expect(sanitizeApiType("'&gt;'"), "'&amp;gt;'");
    },
  );

  test(
    'business build and custom overrides remain public without comments',
    () {
      final info =
          parse(
            '''
abstract class Contract { void close(); }
abstract class Builder implements Contract {
  /// Build a business value.
  String build() => 'value';
  @override
  void close() {}
}
''',
            ['Builder'],
          ).single;
      expect(info.componentInfo!.instanceMethodList.map((m) => m.name), [
        'build',
        'close',
      ]);
      expect(info.componentInfo!.instanceMethodList.last.introduction, isEmpty);
    },
  );

  test(
    'framework hooks require an owner, including local superclass chains',
    () {
      final infos = parse(
        '''
class Intermediate extends StatelessWidget {}
class View extends Intermediate {
  /// Render the widget.
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
  void close() {}
}
class Widget { void build() {} }
class Business extends Widget { void build() {} }
''',
        ['View', 'Business'],
      );
      // A locally declared Widget is a business type, never a Flutter identity.
      expect(infos.first.componentInfo!.instanceMethodList.map((m) => m.name), [
        'close',
      ]);
      expect(infos.last.componentInfo!.instanceMethodList.map((m) => m.name), [
        'build',
      ]);
    },
  );

  test('custom methods on framework owners are not blanket excluded', () {
    final info =
        parse(
          '''
class CustomMap extends MapBase {
  @override
  void close() {}
  @override
  void clear() {}
  @override
  Object? operator [](Object key) => null;
}
''',
          ['CustomMap'],
        ).single;
    expect(info.componentInfo!.instanceMethodList.map((m) => m.name), [
      'close',
      '[]',
    ]);
  });

  test(
    'legacy function typed parameters retain generic/nullable signatures',
    () {
      final info =
          parse(
            '''
class CallbackHost {
  void run(void callback(int value), E mapper<E extends Object>(E input), void nullable(int value)?, dynamic explicit, untyped) {}
}
''',
            ['CallbackHost'],
          ).single;
      expect(
        info.componentInfo!.instanceMethodList.single.params.map((p) => p.type),
        [
          'void Function(int value)',
          'E Function<E extends Object>(E input)',
          'void Function(int value)?',
          'dynamic',
          'dynamic',
        ],
      );
    },
  );

  test('unresolved super types are not reported as dynamic', () {
    final info =
        parse('class Child extends Unknown { Child.named(super.value); }', [
          'Child',
        ]).single;
    expect(
      info.componentInfo!.constructorMethodList.single.params.single.type,
      '-',
    );
  });

  test('rendering is repeatable without reordering parsed method models', () {
    final infos = parse('class Fixture { void z() {} void a() {} }', [
      'Fixture',
    ]);
    final before =
        infos.single.componentInfo!.instanceMethodList
            .map((m) => m.name)
            .toList();
    final first = renderApiMarkdown(infos, names: ['Fixture']);
    expect(renderApiMarkdown(infos, names: ['Fixture']), first);
    expect(
      infos.single.componentInfo!.instanceMethodList.map((m) => m.name),
      before,
    );
  });

  test('unknown inferred field types do not become dynamic', () {
    final info =
        parse(
          'class Fixture { final unknown = loadValue(); final empty = null; }',
          ['Fixture'],
        ).single;
    expect(
      info.extraPropertyList.firstWhere((p) => p.name == 'unknown').type,
      '-',
    );
    expect(
      info.extraPropertyList.firstWhere((p) => p.name == 'empty').type,
      'Null',
    );
  });

  test('render object, element and Material Tab hooks are framework APIs', () {
    final infos = parse(
      '''
class View extends RenderObjectWidget {
  @override
  Element createElement() => throw UnimplementedError();
  @override
  RenderObject createRenderObject(BuildContext context) => throw UnimplementedError();
}
class ViewElement extends RenderObjectElement {
  @override
  void mount(Element? parent, Object? slot) {}
  @override
  void businessCommand() {}
}
class MaterialTab extends Tab {
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
  @override
  Size get preferredSize => throw UnimplementedError();
}
''',
      ['View', 'ViewElement', 'MaterialTab'],
    );
    expect(infos[0].componentInfo!.instanceMethodList, isEmpty);
    expect(infos[1].componentInfo!.instanceMethodList.map((m) => m.name), [
      'businessCommand',
    ]);
    expect(infos[2].componentInfo!.instanceMethodList, isEmpty);
    expect(infos[2].extraPropertyList, isEmpty);
  });
}
