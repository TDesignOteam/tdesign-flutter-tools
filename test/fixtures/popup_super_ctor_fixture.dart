// 最小 fixture：子类 super 形参继承父类默认构造默认值（与旧 popup panel 同构，不依赖 component 版本）

abstract class TPopupBasePanel {
  const TPopupBasePanel({this.draggable = false, this.maxHeightRatio = 0.9});

  final bool draggable;
  final double maxHeightRatio;
}

class TPopupBottomDisplayPanel extends TPopupBasePanel {
  const TPopupBottomDisplayPanel({super.draggable, super.maxHeightRatio});
}
