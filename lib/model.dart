//组件信息
// import 'package:component_info/component_info.dart';

class ComponentConfig {
  ComponentConfig();

  factory ComponentConfig.fromJson(Map<String, dynamic> json) {
    return ComponentConfig()..componentList = (json['componentList'] as List?)?.map((e) => ComponentInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'componentList': componentList,
    };
  }

  // 组件信息
  List<ComponentInfo>? componentList = [];
}

class ComponentInfo {
  ComponentInfo();

  factory ComponentInfo.fromJson(Map<String, dynamic> json) {
    return ComponentInfo()
      ..name = json['name'] as String?
      ..folderName = json['folderName'] as String?
      ..subtitle = json['subtitle'] as String?
      ..owner = json['owner'] as String?
      ..group = json['group'] as String?
      ..introduction = json['introduction'] as String?
      ..demoList = ((json['demoList'] ?? []) as List).map((e) => DemoInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  //组件的简介
  String? introduction = '';

  //组件的维护者
  String? owner = '';

  //组件分组
  String? group = '未分类';

  //组件名称
  String? name = '';

  //组件所在的文件夹名称
  String? folderName = '';

  //组件子标题
  String? subtitle = '';

  // 组件demo信息
  List<DemoInfo>? demoList = [];

  // 生成组件demo的命令信息
  CommandInfo? commandInfo;

  // 静态方法信息
  List<StaticMethodInfo> staticMethodList = [];

  // 其他构造方法信息
  List<StaticMethodInfo> constructorMethodList = [];

  // 实例方法信息（用于 abstract class 的接口方法文档）
  List<StaticMethodInfo> instanceMethodList = [];

  /// API 条目类型：class | enum | typedef
  String kind = 'class';

  /// 枚举成员名称（仅 kind == enum）
  List<String> enumValues = [];

  /// 枚举成员详情（仅 kind == enum）
  List<EnumMemberInfo> enumMembers = [];

  /// typedef 定义源码（仅 kind == typedef）
  String typedefDefinition = '';

  /// 解析来源文件（用于 folder 模式下检测跨文件重复定义）
  String? sourceFile;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'folderName': folderName,
      'subtitle': subtitle,
      'owner': name,
      'group': group,
      'introduction': introduction,
      'demoList': demoList,
    };
  }

  @override
  String toString() {
    return '$name | $introduction';
  }
}

//组件demo基本信息
class DemoInfo {
  DemoInfo();

  factory DemoInfo.fromJson(Map<String, dynamic> json) {
    return DemoInfo()
      ..name = json['demoName'] as String?
      // ..displayStyle = json['displayStyle'] as String?
      ..fileName = json['fileName'] as String?
      ..introductions = json['introductions'] as List<String>
      ..priority = json['priority'] as int?;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'demoName': name,
      // 'displayStyle': displayStyle,
      'priority': priority,
      'fileName': fileName,
      'introductions': introductions,
    };
  }

  //demo组件的widget名称
  String? name = '';

  //demo的文件名称
  String? fileName = '';

  //demo的文件路径
  String filePath = '';

  // 显示样式
  // String? displayStyle = DemoItemStyle.sideBySide;

  // 优先级 1 > 2 > 3 ……
  int? priority = 1;
  bool isValid = false; //是否是有效的组件示例

  //组件demo的简介
  List<String> introductions = [];

  // 获取父目录的文件夹名字
  String getParentDirName() {
    List<String> dirs = filePath.split('/');
    return dirs[dirs.length - 2];
  }

  @override
  String toString() {
    return '$name | displayStyle | $priority | $fileName | ${introductions.join(",")}';
  }
}

//组件属性信息
/// 枚举成员（名称 + 文档注释）
class EnumMemberInfo {
  String name = '';
  String introduction = '';
}

class PropertyInfo {
  //属性的名称
  String name = '';

  //属性的类型
  String type = '';

  // 是否是必要属性
  bool isRequired = false;

  // 是否是命名参数属性
  bool isNamed = false;

  //属性的简介
  String introduction = '';

  // 默认值
  String defaultValue = '-';

  // 是否为静态成员
  bool isStatic = false;

  @override
  String toString() {
    return '$name | $type | $isRequired | $isNamed | $defaultValue | $introduction';
  }
}

class ParsedComponentInfoInfo {
  ComponentInfo? componentInfo;
  /// 默认构造方法的形式参数
  late List<PropertyInfo> propertyList;
  /// 未出现在默认构造中、但对外可见的实例字段
  late List<PropertyInfo> extraPropertyList;
  /// 静态成员（含 static const 等）
  late List<PropertyInfo> staticMemberList;
  late Map<String, PropertyInfo> fieldMap;
}

// 用户执行的命令
class CommandInfo {
  String? file;
  String? folder;
  String? widgetNames;
  String? folderName = '';
  String? output = '';
  bool isOnlyApi = false;
  bool isUseGrammar = false;
  bool isGetComments = false;

  // 命令是否有效
  bool isValid() {
    return (file != null && file!.isNotEmpty) || (folder != null && folder!.isNotEmpty);
  }

  bool isFileMode() {
    return file != null && file!.isNotEmpty;
  }

  String getCommand() {
    StringBuffer sb = StringBuffer();
    if (isFileMode()) {
      sb.write('--file $file ');
    } else {
      sb.write('--folder $folder ');
    }
    sb.write('--name $widgetNames ');
    if (folderName != null && folderName!.isNotEmpty) {
      sb.write('--folder-name $folderName ');
    }
    if (output != null && output!.isNotEmpty) {
      sb.write('--output $output ');
    }
    return sb.toString();
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    sb.write('file: $file\n');
    sb.write('folder: $folder\n');
    sb.write('folderName: $folderName\n');
    sb.write('output: $output\n');
    sb.write('isOnlyApi: $isOnlyApi\n');
    sb.write('isUseGrammar: $isUseGrammar\n');
    sb.write('widgetNames: $widgetNames\n');
    return sb.toString();
  }
}

class StaticMethodInfo {
  // 方法名称
  String? name;

  // 返回类型
  String? returnType;

  // 方法参数
  List<PropertyInfo> params = [];

  // 方法说明
  String? introduction;
}
