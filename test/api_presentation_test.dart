import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:tdesign_flutter_tools/api_markdown.dart';
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:test/test.dart';

void main() {
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
    expect(output, contains('参数形式：`Options.mixed(z, {a})`'));
    expect(output, contains('参数形式：`Options.optional(z, [a])`'));
    expect(output, contains('| count | int | 1 |'));
    expect(output, contains('| a | int | - | - | 是 |'));
  });

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
        '参数形式：`Options.named(value)`',
        'static bool open({required int count})',
        'void close()',
        '| count | int | - |',
      ]) {
        expect(output, contains(contract));
      }
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
