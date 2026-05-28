import 'package:tdesign_flutter_tools/documentation.dart';
import 'package:test/test.dart';

void main() {
  test('normalizeDocumentationText trims prose and keeps fence body', () {
    expect(
      normalizeDocumentationText('/// 第一行\n/// \n///  第二行'),
      '第一行\n\n第二行',
    );
  });

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

  test('parseDocumentation does not merge narrative after same-line param doc', () {
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
  });

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
    expect(
      result.parameterDocs['context'],
      '用于查找 Navigator。\n第二行说明。',
    );
    expect(result.narrative, isEmpty);
  });

  test('stripIntroductionForApiSummary removes 示例 and other fenced blocks', () {
    const raw = '''
第一段说明。

**示例**
```dart
final a = 1;
```

第二段说明。
''';
    expect(
      stripIntroductionForApiSummary(raw),
      '第一段说明。\n\n第二段说明。',
    );
  });

  test('stripIntroductionForApiSummary removes standalone fenced blocks', () {
    const raw = '''
第一段说明。

```dart
final a = 1;
```

第二段说明。
''';
    expect(stripIntroductionForApiSummary(raw), '第一段说明。\n\n第二段说明。');
    expect(stripIntroductionForApiSummary(raw), isNot(contains('```')));
  });
}
