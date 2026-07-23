/// 弹出层入口示例。
///
/// 通过 [show] 命令式打开。
final class DemoPopup {
  const DemoPopup._();

  /// 打开浮层并压入独立 [PopupRoute]。
  ///
  /// [context] 用于查找 [Navigator] 并展示浮层。
  ///
  /// [options] 浮层配置；推荐 [DemoOptions.bottom]。
  ///
  /// 返回 [DemoHandle]。
  static DemoHandle show({required Object context, required Object options}) {
    throw UnimplementedError();
  }
}

class DemoOptions {
  factory DemoOptions.bottom() => DemoOptions();
  DemoOptions();
}

class DemoHandle {}

/// 级联选择入口示例。
final class DemoCascader {
  const DemoCascader._();

  /// 展示多级选择器。
  static DemoMultiCascader showMultiCascader({
    String? title,
    DemoChangeCallback? onChange,
    DemoCascaderAction? action,
    Object? barrierColor,
  }) {
    return DemoMultiCascader(
      title: title,
      onChange: onChange,
      action: action,
    );
  }
}

class DemoMultiCascader {
  const DemoMultiCascader({this.title, this.onChange, this.action});

  /// 选择器标题
  final String? title;

  /// 值发生变更时触发
  final DemoChangeCallback? onChange;

  /// 自定义选择器右上角按钮
  final DemoCascaderAction? action;
}

class DemoCascaderAction {}

typedef DemoChangeCallback = void Function();
