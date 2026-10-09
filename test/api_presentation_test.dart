import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:tdesign_flutter_tools/api_completeness.dart';
import 'package:tdesign_flutter_tools/api_markdown.dart';
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:tdesign_flutter_tools/documentation.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:test/test.dart';

void main() {
  test('categorized ThemeExtension shows one configuration table', () {
    const source = r"""
/// Component theme.
/// {@category ComponentTheme}
@immutable
class Style extends ThemeExtension<Style> {
  const Style({this.color, this.width = 2});
  /// Foreground; null uses the token.
  final Color? color;
  /// Stroke width.
  final double width;
  Style copyWith({Color? color, double? width}) => this;
  Style lerp(ThemeExtension<Style>? other, double t) => this;
  Style merge(Style? other) => this;
  /// A component-specific operation.
  /// ## 返回值
  /// The resolved width.
  double resolveWidth() => width;
}
""";
    List<ParsedComponentInfoInfo> parse(String text) {
      final result = <ParsedComponentInfoInfo>[];
      parseString(content: text).unit.accept(
        ComponentAstVisitor(
          nameList: ['Style'],
          onParsedComponentInfoInfo: result.add,
        ),
      );
      return result;
    }

    final parsed = parse('$source\nenum Mode { never, always }');
    final output = renderApiMarkdown(
      parsed,
      names: ['Style'],
      includeIntroduction: true,
    );
    expect(output, contains('#### 配置项'));
    expect(output, contains('Component theme.'));
    expect(
      output,
      contains('| color | Color? | - | Foreground; null uses the token. | 否 |'),
    );
    expect(output, contains('| width | double | 2 | Stroke width. | 否 |'));
    expect(output, isNot(contains('Style.copyWith')));
    expect(output, isNot(contains('Style.lerp')));
    expect(output, isNot(contains('Style.merge')));
    expect(output, contains('Style.resolveWidth'));
    expect(output, isNot(contains('{@category')));
    expect(output, isNot(contains('##### Style\n')));
    expect(output.indexOf('### Mode'), greaterThanOrEqualTo(0));
    expect(output.indexOf('### Mode'), lessThan(output.indexOf('### Style')));
    final impostor = renderApiMarkdown(
      parse(source.replaceFirst('extends ThemeExtension<Style>', '')),
      names: ['Style'],
    );
    expect(impostor, contains('Style.copyWith'));
    expect(impostor, isNot(contains('#### 配置项')));
  });

  test('all API tables share columns while notes cannot supply parameters', () {
    const source = r"""
class Fixture {
  /// Create.
  ///
  /// | 名称 | 说明 |
  /// | --- | --- |
  /// | count | a\|b |
  ///
  /// | 名称 | 类型 | 默认值 | 说明 | 必传 |
  /// | --- | --- | --- | --- | --- |
  /// | count | int | - | Authored note. | 是 |
  Fixture({required int count});
}
enum Kind { bottom }
""";
    final parsed = <ParsedComponentInfoInfo>[];
    parseString(content: source).unit.accept(
      ComponentAstVisitor(
        nameList: ['Fixture', 'Kind'],
        onParsedComponentInfoInfo: parsed.add,
      ),
    );
    final output = renderApiMarkdown(parsed, names: ['Fixture', 'Kind']);
    expect(output, contains(r'| count | - | - | a\|b | - |'));
    expect(output, contains('| bottom | Kind | - | - | - |'));
    final section = output.substring(output.indexOf('### Fixture'));
    expect(markdownDefaultCtorParamNames(section), {'count'});
    expect(
      markdownDefaultCtorParamNames(
        section.replaceFirst('| count | int | - | - | 是 |', ''),
      ),
      isEmpty,
    );
    expect(
      RegExp(
        r'^\| 名称 \| 类型 \| 默认值 \| 说明 \| 必传 \|$',
        multiLine: true,
      ).allMatches(output).length,
      4,
    );
  });

  test(
    'void functions omit return tables without accepting malformed contracts',
    () {
      final parsed = <ParsedComponentInfoInfo>[];
      parseString(content: '/// Finishes.\nvoid finish() {}').unit.accept(
        ComponentAstVisitor(
          nameList: ['finish'],
          onParsedComponentInfoInfo: parsed.add,
        ),
      );
      final output = renderApiMarkdown(parsed, names: ['finish']);
      expect(output, isNot(contains('返回值')));
      expect(
        functionDocumentationIssues(
          'sample',
          parsed.single.componentInfo!,
          output,
        ),
        isEmpty,
      );
      expect(
        functionDocumentationIssues(
          'sample',
          parsed.single.componentInfo!,
          '$output\n#### 返回值\n\n| 类型 | 说明 |\n| --- | --- |',
        ),
        isNotEmpty,
      );
    },
  );

  test(
    'return documentation follows parameters and preserves sibling prose',
    () {
      const source = """
class Handle {}
class Popup {
  /// Opens a popup.
  ///
  /// ## 返回值
  /// Controls the current popup.
  ///
  /// ## Failure
  /// Throws on invalid options.
  ///
  /// [count] Number of popups.
  static Handle show(int count) => Handle();
  /// Closes the popup.
  void close() {}
}
/// Selects a value.
///
/// ## Returns
/// The selected value, or null.
T? choose<T extends Object>(T value) => value;
""";
      final parsed = <ParsedComponentInfoInfo>[];
      const names = ['Popup', 'choose'];
      parseString(content: source).unit.accept(
        ComponentAstVisitor(
          nameList: names,
          onParsedComponentInfoInfo: parsed.add,
        ),
      );
      final original =
          parsed.first.componentInfo!.staticMethodList.single.introduction;
      final output = renderApiMarkdown(parsed, names: names);
      expect(output, contains('###### 返回值\n\n| 名称 | 类型 | 默认值 | 说明 | 必传 |'));
      expect(
        output,
        contains('| 返回值 | Handle | - | Controls the current popup. | - |'),
      );
      expect(output, contains('###### Failure\nThrows on invalid options.'));
      expect(
        output.indexOf('| count | int |'),
        lessThan(output.indexOf('| 返回值 | Handle |')),
      );
      expect(output, isNot(contains('| void |')));
      expect(output, contains('#### 返回值\n\n| 名称 | 类型 | 默认值 | 说明 | 必传 |'));
      expect(
        output,
        contains('| 返回值 | T? | - | The selected value, or null. | - |'),
      );
      expect(output, isNot(contains('返回类型：')));
      expect(
        parsed.first.componentInfo!.staticMethodList.single.introduction,
        original,
      );
      expect(renderApiMarkdown(parsed, names: names), output);
      final functionSection = output.substring(output.indexOf('### choose'));
      expect(
        functionDocumentationIssues(
          'sample',
          parsed.last.componentInfo!,
          functionSection,
        ),
        isEmpty,
      );
      expect(
        functionDocumentationIssues(
          'sample',
          parsed.last.componentInfo!,
          functionSection.replaceFirst(
            '| 返回值 | T? | - | The selected value, or null. | - |',
            '| 返回值 | Object? | - | The selected value, or null. | - |',
          ),
        ),
        isNotEmpty,
      );
    },
  );

  test('type prose headings remain inside their type without intro labels', () {
    const source = '''
/// Options.
///
/// ## Creation
///
/// Named factories are preferred.
///
/// ### Details
///
/// Null uses the theme.
///
/// ## Placement
///
/// | Direction | Field |
/// | --- | --- |
/// | bottom | height |
class Options {
  Options();
}
/// Kind.
///
/// # Meaning
/// Choose one kind.
enum Kind { bottom }
/// Callback.
///
/// ## Timing
/// Receives the result.
typedef Result = void Function();
''';
    final parsed = <ParsedComponentInfoInfo>[];
    const names = ['Options', 'Kind', 'Result'];
    parseString(content: source).unit.accept(
      ComponentAstVisitor(
        nameList: names,
        onParsedComponentInfoInfo: parsed.add,
      ),
    );
    final original = parsed.first.componentInfo!.introduction;
    final output = renderApiMarkdown(
      parsed,
      names: names,
      includeIntroduction: true,
    );
    expect(output, isNot(contains('#### 简介')));
    expect(output, contains('### Options\n\nOptions.'));
    for (final heading in [
      '#### Creation',
      '##### Details',
      '#### Placement',
      '#### Meaning',
      '#### Timing',
    ]) {
      expect(output, contains(heading));
    }
    expect(output, contains('| bottom | - | - | Field：height | - |'));
    expect(parsed.first.componentInfo!.introduction, original);
    expect(
      renderApiMarkdown(parsed, names: names, includeIntroduction: true),
      output,
    );
  });

  test('callable prose headings cannot escape their callable section', () {
    const source = '''
class Options {
  /// Default.
  ///
  /// ## Defaults
  /// Null uses the theme.
  Options();
  /// Factory.
  ///
  /// # Factory behavior
  /// Uses a fixed direction.
  factory Options.bottom() => Options();
  /// Method.
  ///
  /// ## Method behavior
  ///
  /// ### Nested behavior
  /// Calling twice has no effect.
  void close() {}
}
/// Function.
///
/// ## Function behavior
/// Returns nothing.
void run() {}
''';
    final parsed = <ParsedComponentInfoInfo>[];
    const names = ['Options', 'run'];
    parseString(content: source).unit.accept(
      ComponentAstVisitor(
        nameList: names,
        onParsedComponentInfoInfo: parsed.add,
      ),
    );
    final output = renderApiMarkdown(parsed, names: names);
    for (final contract in [
      '###### Defaults',
      '###### Factory behavior',
      '###### Method behavior',
      '**Nested behavior**',
      '##### Function behavior',
    ]) {
      expect(output, contains(contract));
    }
    expect(output, isNot(contains('#######')));
  });

  test('setext headings rebase without converting tables or thematic breaks', () {
    const source =
        'Title\n=====\n\nDetails\n-------\n\n| A | B |\n| --- | --- |\n\n---\n\nPlain text.';
    expect(
      formatIntroductionForApiSummary(source),
      '#### Title\n\n##### Details\n\n| A | B |\n| --- | --- |\n\n---\n\nPlain text.',
    );
  });

  test(
    'heading normalization preserves inline hashes and filters code examples',
    () {
      const source =
          'Use `#value`.\n\n```dart\n# code\n```\n\n  ## Behavior ##\n\nC# remains valid.';
      expect(
        formatIntroductionForApiSummary(source),
        'Use `#value`.\n\n#### Behavior\n\nC# remains valid.',
      );
    },
  );

  test(
    'constructors share a group and named boundaries preserve parameter ownership',
    () {
      const source = """
class Options {
  /// Create a default configuration.
  Options({this.count = 1});
  /// Number of items.
  final int count;
  /// Named configuration.
  Options.named(String label) : count = 1;
  /// Factory configuration.
  factory Options.factory() => Options();
  /// Whether this configuration is active.
  bool get active => true;
  /// Read a configuration.
  static Options read() => Options();
  /// Close it.
  void close() {}
}
""";
      final parsed = <ParsedComponentInfoInfo>[];
      parseString(content: source).unit.accept(
        ComponentAstVisitor(
          nameList: ['Options'],
          onParsedComponentInfoInfo: parsed.add,
        ),
      );
      final output = renderApiMarkdown(parsed, names: ['Options']);
      final headings =
          RegExp(
            r'^#{4,5} .+$',
            multiLine: true,
          ).allMatches(output).map((m) => m.group(0)!).toList();
      expect(headings, [
        '#### 构造方法',
        '##### Options',
        '##### Options.factory',
        '##### Options.named',
        '#### 属性',
        '#### 静态方法',
        '##### Options.read',
        '#### 实例方法',
        '##### Options.close',
      ]);
      expect(output, isNot(contains('##### 参数')));
      expect(
        markdownDefaultCtorParamNames(
          output.substring(output.indexOf('### Options')),
        ),
        {'count'},
      );
      final defaultSection =
          output
              .split('##### Options\n')
              .last
              .split('##### Options.factory')
              .first;
      expect(defaultSection, contains('| count | int | 1 |'));
      expect(defaultSection, isNot(contains('| label |')));
      expect(parsed.single.componentInfo!.constructorMethodList.length, 2);
      expect(renderApiMarkdown(parsed, names: ['Options']), output);
    },
  );

  test('constructors retain only positional order and grouping', () {
    const source = '''
/// Options.
class Options {
  /// Default.
  const Options({int count = 1});
  /// Positional and named.
  factory Options.mixed(int z, {required int a}) => Options();
  /// Optional positional.
  Options.optional(int z, [int? a]);
  /// No arguments.
  Options.empty();
}
''';
    final parsed = <ParsedComponentInfoInfo>[];
    parseString(content: source).unit.accept(
      ComponentAstVisitor(
        nameList: ['Options'],
        onParsedComponentInfoInfo: parsed.add,
      ),
    );
    final output = renderApiMarkdown(parsed, names: ['Options']);
    expect(output, isNot(contains('```')));
    expect(output, isNot(contains('const Options')));
    expect(output, isNot(contains('支持 const')));
    expect(output, contains('##### Options.empty'));
    expect(output, contains('#### 构造方法'));
    expect(output, contains('位置参数：`z`'));
    expect(output, contains('位置参数：`z, a`'));
    expect(output, contains('| count | int | 1 |'));
    expect(output, contains('| a | int | - | - | 是 |'));
  });

  test(
    'one compact contract covers static, instance, extension and function APIs',
    () {
      const source = """
class Options {
  Options();
  static T? read<T extends Object>(String z, {required T a}) => a;
  void close([Object? result]) {}
  void set({required int count}) {}
}
extension Helpers on Options {
  E? find<E extends Object>(E z, [E? a]) => a;
}
R? choose<R extends Object>(R z, {required R a}) => a;
""";
      final parsed = <ParsedComponentInfoInfo>[];
      const names = ['Options', 'Helpers', 'choose'];
      parseString(content: source).unit.accept(
        ComponentAstVisitor(
          nameList: names,
          onParsedComponentInfoInfo: parsed.add,
        ),
      );
      final output = renderApiMarkdown(parsed, names: names);
      expect(output, isNot(contains('```')));
      for (final contract in [
        '位置参数：`z`',
        '位置参数：`result`',
        '位置参数：`z, a`',
        '位置参数：`z`',
        '类型参数：`T extends Object`',
        '类型参数：`E extends Object`',
        '类型参数：`R extends Object`',
        '| 返回值 | T? | - | - | - |',
        '| 返回值 | E? | - | - | - |',
        '| 返回值 | R? | - | - | - |',
        '| count | int | - | - | 是 |',
      ]) {
        expect(output, contains(contract));
      }
      expect(output, isNot(contains('位置参数：`Options.set')));
    },
  );

  test(
    'API rendering removes examples across callable scopes, retaining contracts',
    () {
      const source = '''
/// Popup configuration.
///
/// 用法：
/// ```dart
/// classExample();
/// ```
///
/// Only one controller may bind at a time.
class Options<T extends Object> {
  /// Create options; null keeps the default.
  ///
  /// 使用示例：
  /// ```dart
  /// defaultExample();
  /// ```
  Options({this.value});
  /// Current value; null is allowed.
  final T? value;
  /// Create named options.
  ///
  /// ```dart
  /// namedExample();
  /// ```
  Options.named(this.value);
  /// Open options.
  ///
  /// **示例**
  /// ```dart
  /// staticExample();
  /// ```
  ///
  /// Throws StateError when already bound.
  static bool open({required int count}) => true;
  /// Close options.
  ///
  /// ```dart
  /// methodExample();
  /// ```
  ///
  /// Calling twice has no effect.
  void close() {}
}
/// Receives the result.
///
/// ```dart
/// typedefExample();
/// ```
typedef Result = void Function(int value);
/// Read the result.
///
/// ```dart
/// functionExample();
/// ```
///
/// Returns null when absent.
int? read() => null;
/// Helpers for a nullable list.
extension Helpers<E extends Object> on List<E?> {
  /// Clear a binding.
  void clearBinding() {}
}
''';
      final parsed = <ParsedComponentInfoInfo>[];
      const names = ['Options', 'Result', 'read', 'Helpers'];
      parseString(content: source).unit.accept(
        ComponentAstVisitor(
          nameList: names,
          onParsedComponentInfoInfo: parsed.add,
        ),
      );
      final originalIntro = parsed.first.componentInfo!.introduction;
      final output = renderApiMarkdown(
        parsed,
        names: names,
        includeIntroduction: true,
      );
      expect(output, isNot(contains('#### 声明')));
      expect(output, isNot(contains('Example();')));
      expect(output, isNot(contains('**示例**')));
      expect(output, isNot(contains('用法：')));
      for (final contract in [
        'Only one controller',
        'null keeps the default',
        'Throws StateError',
        'Calling twice has no effect',
        'Returns null when absent',
        '类型参数：`T extends Object`',
        '类型参数：`E extends Object`',
        '适用类型：`List&lt;E?&gt;`',
        '| value | int | - | - | 是 |',
        '位置参数：`value`',
        '##### Options.open',
        '| 返回值 | bool | - | - | - |',
        '##### Options.close',
        '| count | int | - |',
      ]) {
        expect(output, contains(contract));
      }
      expect(output, isNot(contains('static bool open(')));
      expect(output, isNot(contains('void close()')));
      expect(output, isNot(contains('int? read()')));
      expect(output, contains('| 返回值 | int? | - | - | - |'));
      expect(RegExp(r'^```dart', multiLine: true).allMatches(output), isEmpty);
      expect(output, isNot(contains('Options({this.value})')));
      expect(output, isNot(contains('Options.named(this.value)')));
      expect(parsed.first.componentInfo!.introduction, originalIntro);
      expect(originalIntro, contains('classExample();'));
      expect(
        renderApiMarkdown(parsed, names: names, includeIntroduction: true),
        output,
      );
    },
  );
}
