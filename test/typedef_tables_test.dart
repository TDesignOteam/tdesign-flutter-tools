import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:tdesign_flutter_tools/api_completeness.dart';
import 'package:tdesign_flutter_tools/api_markdown.dart';
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:test/test.dart';

void main() {
  List<ParsedComponentInfoInfo> parse(String source) {
    final result = <ParsedComponentInfoInfo>[];
    parseString(content: source).unit.accept(
      ComponentAstVisitor(
        nameList: ['Callback'],
        onParsedComponentInfoInfo: result.add,
      ),
    );
    return result;
  }

  test(
    'callback tables combine AST types with authored parameter/return docs',
    () {
      final parsed = parse('''
/// Visibility changed.
///
/// [visible] True opens, false closes.
///
/// [trigger] The origin, including a|b.
///
/// ## 返回值
/// No result.
typedef Callback = void Function(bool visible, Trigger trigger);
''');
      final output = renderApiMarkdown(
        parsed,
        names: ['Callback'],
        includeIntroduction: true,
      );
      expect(output, isNot(contains('```')));
      expect(
        output,
        contains('| visible | bool | - | True opens, false closes. | 是 |'),
      );
      expect(
        output,
        contains(
          r'| trigger | Trigger | - | The origin, including a\|b. | 是 |',
        ),
      );
      expect(output, contains('| 返回值 | void | - | No result. | - |'));
      expect(
        typedefDocumentationIssues(
          'fixture',
          parsed.single.componentInfo!,
          output,
        ),
        isEmpty,
      );
      expect(
        renderApiMarkdown(
          parsed,
          names: ['Callback'],
          includeIntroduction: true,
        ),
        output,
      );
      for (final mutation in [
        output.replaceFirst('| visible | bool |', '| visible | String |'),
        output.replaceFirst('| 返回值 | void |', '| 返回值 | bool |'),
        output.replaceFirst(
          '位置参数：`visible, trigger`',
          '位置参数：`trigger, visible`',
        ),
        output.replaceFirst(' | 是 |', ' | 否 |'),
        output.replaceFirst(
          '| visible | bool | - | True opens, false closes. | 是 |',
          '',
        ),
      ]) {
        expect(
          typedefDocumentationIssues(
            'fixture',
            parsed.single.componentInfo!,
            mutation,
          ),
          isNotEmpty,
        );
      }
    },
  );

  test('generic nullable callbacks retain named optional and nested types', () {
    final parsed = parse('''
/// Callback.
typedef Callback<T extends Object> = T? Function<R extends num>(
  T value, {required R count, void Function(R)? onResult})?;
''');
    final output = renderApiMarkdown(parsed, names: ['Callback']);
    expect(output, contains('类型参数：`T extends Object`'));
    expect(output, contains('回调类型参数：`R extends num`'));
    expect(output, contains('可空：是。'));
    expect(output, contains('位置参数：`value`'));
    expect(output, contains('| onResult | void Function(R)? | - | - | 否 |'));
    expect(
      typedefDocumentationIssues(
        'fixture',
        parsed.single.componentInfo!,
        output,
      ),
      isEmpty,
    );
    for (final mutation in [
      output.replaceFirst('T extends Object', 'T'),
      output.replaceFirst('R extends num', 'R'),
      output.replaceFirst('可空：是。', ''),
    ]) {
      expect(
        typedefDocumentationIssues(
          'fixture',
          parsed.single.componentInfo!,
          mutation,
        ),
        isNotEmpty,
      );
    }
  });

  test(
    'optional unnamed positional callback parameters keep order and types',
    () {
      final parsed = parse('typedef Callback = void Function(int, [String?]);');
      final output = renderApiMarkdown(parsed, names: ['Callback']);
      expect(output, contains('| 参数 1 | int | - | - | 是 |'));
      expect(output, contains('| 参数 2 | String? | - | - | 否 |'));
      expect(
        typedefDocumentationIssues(
          'fixture',
          parsed.single.componentInfo!,
          output,
        ),
        isEmpty,
      );
    },
  );

  test(
    'zero parameter callback has a return table without an empty parameter table',
    () {
      final parsed = parse('typedef Callback = Function();');
      final output = renderApiMarkdown(parsed, names: ['Callback']);
      expect(output, contains('#### 回调参数\n\n无参数。'));
      expect(output, contains('| 返回值 | dynamic | - | - | - |'));
      expect(
        typedefDocumentationIssues(
          'fixture',
          parsed.single.componentInfo!,
          output,
        ),
        isEmpty,
      );
    },
  );

  test(
    'non function alias preserves target type and generic constraints in a table',
    () {
      final parsed = parse(
        '/// Aliased values.\ntypedef Callback<T extends num> = Map<String, List<T?>>;',
      );
      final output = renderApiMarkdown(parsed, names: ['Callback']);
      expect(
        output,
        contains(
          '| Callback | Map&lt;String, List&lt;T?&gt;&gt; | - | Aliased values. | - |',
        ),
      );
      expect(
        typedefDocumentationIssues(
          'fixture',
          parsed.single.componentInfo!,
          output,
        ),
        isEmpty,
      );
    },
  );
}
