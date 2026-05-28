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
  static DemoHandle show({
    required Object context,
    required Object options,
  }) {
    throw UnimplementedError();
  }
}

class DemoOptions {
  factory DemoOptions.bottom() => DemoOptions();
  DemoOptions();
}

class DemoHandle {}
