// 同文件内 enum/typedef 应随目标 class 一并收录（不依赖 part 文件）

class TargetWidget {}

enum AutoIncludedEnum { top, bottom }

typedef AutoIncludedTypedef = void Function();
