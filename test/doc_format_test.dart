import 'package:tdesign_flutter_tools/documentation.dart';
import 'package:test/test.dart';

void main() {
  test('normalizeDocumentationText trims prose and keeps fence body', () {
    expect(normalizeDocumentationText('/// 第一行\n/// \n///  第二行'), '第一行\n\n第二行');
  });

  test(
    'bare dartdoc markers preserve paragraphs and literal slashes in fences',
    () {
      const raw =
          '/// 第一段\n///\n/// 第二段\n///\n'
          '/// ```dart\n/// final marker = "///";\n/// ```';
      expect(
        normalizeDocumentationText(raw),
        '第一段\n\n第二段\n\n```dart\nfinal marker = "///";\n```',
      );
    },
  );

  test('formatDartdocReferencesInProse converts bracket references', () {
    expect(
      formatDartdocReferencesInProse('见 [TPopupOptions.bottom] 与 [Navigator]'),
      '见 `TPopupOptions.bottom` 与 `Navigator`',
    );
  });

  test('formatDartdocReferencesInProse preserves markdown links', () {
    expect(
      formatDartdocReferencesInProse('详见 [文档](https://example.com)'),
      '详见 [文档](https://example.com)',
    );
  });

  test('formatDartdocReferencesInProse skips fenced code blocks', () {
    const input = '''
说明 [Foo]

```dart
final x = [1];
```
''';
    final String output = formatDartdocReferencesInProse(input);
    expect(output, contains('`Foo`'));
    expect(output, contains('final x = [1];'));
  });

  test('parseDocumentation extracts single-line param docs', () {
    const raw = '''
打开浮层并压入独立 [PopupRoute]。

[context] 用于查找 [Navigator]。

[options] 浮层配置。

返回 [TPopupHandle]。
''';
    final ParsedDocumentation result = parseDocumentation(
      raw,
      parameterNames: <String>['context', 'options'],
    );
    expect(result.parameterDocs['context'], '用于查找 `Navigator`。');
    expect(result.parameterDocs['options'], '浮层配置。');
    expect(result.narrative, contains('打开浮层并压入独立 `PopupRoute`'));
    expect(result.narrative, contains('返回 `TPopupHandle`'));
    expect(result.narrative, isNot(contains('[context]')));
  });

  test(
    'parseDocumentation does not merge narrative after same-line param doc',
    () {
      const raw = '''
[options] 浮层配置；推荐 bottom。

返回 Handle，可用 close、open。
''';
      final ParsedDocumentation result = parseDocumentation(
        raw,
        parameterNames: <String>['options'],
      );
      expect(result.parameterDocs['options'], '浮层配置；推荐 bottom。');
      expect(result.narrative, contains('返回 Handle'));
      expect(result.parameterDocs['options'], isNot(contains('返回')));
    },
  );

  test('parseDocumentation merges multi-line param docs', () {
    const raw = '''
[context]
用于查找 Navigator。
第二行说明。
''';
    final ParsedDocumentation result = parseDocumentation(
      raw,
      parameterNames: <String>['context'],
    );
    expect(result.parameterDocs['context'], '用于查找 Navigator。\n第二行说明。');
    expect(result.narrative, isEmpty);
  });

  test('parameter paragraphs retain wrapped prose and dartdoc references', () {
    const raw = '''
/// 打开或重新打开浮层。
///
/// [context] 可选。首次调用须能解析 [Navigator]（传入 [context] 或依赖
/// [navigatorContext]）；后续可省略，优先复用缓存的 [NavigatorState]。
///
/// 已展示时调用无副作用。
''';
    final result = parseDocumentation(raw, parameterNames: ['context']);
    expect(
      result.parameterDocs['context'],
      '可选。首次调用须能解析 `Navigator`（传入 `context` 或依赖\n'
      '`navigatorContext`）；后续可省略，优先复用缓存的 `NavigatorState`。',
    );
    expect(result.narrative, '打开或重新打开浮层。\n\n已展示时调用无副作用。');
  });

  test('wrapped parameter paragraphs stop at the next parameter or fence', () {
    const raw = '''
[first] 第一参数说明，
续行。
[second] 第二参数说明。
```dart
final values = [first, second];
```
''';
    final result = parseDocumentation(raw, parameterNames: ['first', 'second']);
    expect(result.parameterDocs, {
      'first': '第一参数说明，\n续行。',
      'second': '第二参数说明。',
    });
    expect(result.narrative, contains('final values = [first, second];'));
  });

  test('API summary omits example labels and fences but retains prose', () {
    const raw = '''
第一段说明。

**示例**
```dart
final a = 1;
```

第二段说明。
''';
    expect(formatIntroductionForApiSummary(raw), '第一段说明。\n\n第二段说明。');
  });

  test('API summary omits standalone fenced examples', () {
    const raw = '''
第一段说明。

```dart
final a = 1;
```

第二段说明。
''';
    expect(formatIntroductionForApiSummary(raw), '第一段说明。\n\n第二段说明。');
  });
  test(
    'summary omits the plain example label without losing later constraints',
    () {
      const raw = '说明。\n\n示例：\n```dart\nTDivider()\n```\n\n后续契约。';
      expect(formatIntroductionForApiSummary(raw), '说明。\n\n后续契约。');
    },
  );

  test(
    'API prose preserves inline defaults and handles long and tilde fences',
    () {
      const raw = '''
`null` 保留原值；零时长会关闭。

### 使用示例
````dart
final text = '```';
```
````

**Examples:**
~~~dart
open();
~~~

不可重复绑定，否则抛出 `StateError`。
''';
      expect(
        formatDocumentationForApi(raw),
        '`null` 保留原值；零时长会关闭。\n\n不可重复绑定，否则抛出 `StateError`。',
      );
    },
  );
}
