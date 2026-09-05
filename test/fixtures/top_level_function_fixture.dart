class DemoDrawer {}

class DemoDrawerHandle {}

enum DemoDrawerPlacement { left, right }

/// 通过浮层展示一个 [DemoDrawer]。
///
/// [context] 用于查找承载浮层的导航器。
/// [drawer] 只描述抽屉内容。
/// [placement] 控制抽屉滑出的方向。
/// [showOverlay] 控制是否显示蒙层。
DemoDrawerHandle showDemoDrawer(
  Object context, {
  required DemoDrawer drawer,
  DemoDrawerPlacement placement = DemoDrawerPlacement.right,
  bool showOverlay = true,
}) {
  throw UnimplementedError();
}

/// 不应被公开 API 生成器收录。
// ignore: unused_element
void _privateHelper() {}
