import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:test/test.dart';

void main() {
  test(
    'copyWith field fallback is distinct from explicit parameter semantics',
    () {
      final parsed = parseString(
        content: r"""
/// 配置。
class Config {
  /// 背景颜色；字段未配置时回退 Token。
  final String? color;
  /// 标题。
  final String? title;
  const Config({this.color, this.title});
  /// 返回副本；color 为 null 时保留，title 可显式清空。
  Config copyWith({String? color,
    /// 不传时保留，显式 null 清除标题。
    Object? title = 0,
  }) => Config(color: color ?? this.color);
}
""",
      );
      final infos = <ParsedComponentInfoInfo>[];
      parsed.unit.accept(
        ComponentAstVisitor(
          nameList: ['Config'],
          onParsedComponentInfoInfo: infos.add,
        ),
      );
      final info = infos.single;
      final copy = info.componentInfo!.instanceMethodList.single;
      expect(
        copy.params.singleWhere((p) => p.name == 'color').introduction,
        '字段含义：背景颜色；字段未配置时回退 Token。 调用时的空值行为见方法说明。',
      );
      expect(
        copy.params.singleWhere((p) => p.name == 'title').introduction,
        '不传时保留，显式 null 清除标题。',
      );
      expect(
        info.propertyList.singleWhere((p) => p.name == 'color').introduction,
        '背景颜色；字段未配置时回退 Token。',
      );
    },
  );
}
