import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:tdesign_flutter_tools/api_markdown.dart';
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:tdesign_flutter_tools/documentation.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:test/test.dart';

void main() {
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
    expect(output, contains('| bottom | height |'));
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
      '##### Defaults',
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
    expect(output, contains('#### 工厂构造方法'));
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
        '返回类型：`T?`',
        '返回类型：`E?`',
        '返回类型：`R?`',
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
/// **示例**
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
      for (final contract in [
        'Only one controller',
        'null keeps the default',
        'Throws StateError',
        'Calling twice has no effect',
        'Returns null when absent',
        '类型参数：`T extends Object`',
        '类型参数：`E extends Object`',
        '适用类型：`List&lt;E?&gt;`',
        'typedef Result = void Function(int value)',
        '位置参数：`value`',
        '##### Options.open',
        '返回类型：`bool`',
        '##### Options.close',
        '返回类型：`void`',
        '| count | int | - |',
      ]) {
        expect(output, contains(contract));
      }
      expect(output, isNot(contains('static bool open(')));
      expect(output, isNot(contains('void close()')));
      expect(output, isNot(contains('int? read()')));
      expect(output, contains('返回类型：`int?`'));
      expect(RegExp(r'^```dart', multiLine: true).allMatches(output).length, 1);
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
