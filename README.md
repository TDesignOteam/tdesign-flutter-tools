# tdesign_flutter_tools

[![Flutter Version](https://img.shields.io/badge/Flutter-%3E%3D3.32.0-blue.svg?logo=flutter)](https://flutter.dev/)
[![Dart Version](https://img.shields.io/badge/Dart-%3E%3D3.7.0-blue.svg?logo=dart)](https://dart.dev/)

[TDesign Flutter](https://github.com/Tencent/tdesign-flutter) 组件库文档生成工具

> 一个用于自动生成 TDesign Flutter 组件库示例代码和 API 文档的命令行工具,基于 smart_cli。

## 组件注释规范

### 组件widget注释示例

```dart
/// 组件简介（必须）
```

### 组件属性注释示例

```dart
/// 属性简介（必须）
```

### 工具职责边界

工具只负责**通用 AST 解析规则**，不会对个别组件做特殊兼容，也不会修正源码里不合规的注释。

| 由工具负责（通用规则） | 由源码注释负责（需合规编写） |
| --- | --- |
| 从构造参数 AST 提取类型、默认值 | 字段/参数的 `///` 说明文案 |
| 构造参数与公开属性/静态成员分表展示 | 注释内容与字段语义一致（如 content 不应写「标题」） |
| 过滤 `this.xxx` 被误识别为默认值 | 错别字、遗漏注释、注释写在错误位置 |
| 解析 `abstract class` 实例方法、工厂构造及参数表 | `super.key` 等场景的类型展示 |
| 从父类字段解析 `super.xxx` 参数类型 | 无注释时说明列显示 `-`（符合预期） |
| 不展示库级私有命名构造（`ClassName._`） | 对外文档只保留可调用入口 |
| 类内章节顺序：静态方法 → 命名工厂 → 默认构造 → 公开属性/成员 | `--name` 列表顺序决定多类型先后；enum/typedef 排在 class 之后 |
| 同文件内自动收录 public 的 enum / typedef | 也可在 `--name` 中显式指定枚举或别名名称 |
| folder 模式下检测跨文件重复 enum/typedef 并告警 | 文档保留重复条目以暴露源码问题，工具不做 silent dedupe |
| Markdown 表格转义、方法参数格式化 | 无注释时说明列显示 `-`（符合预期） |
| dartdoc 通用处理：`///`/`/** */` 规范化、`[Type]`/`[param]` 引用转 Markdown、方法块内 `[paramName]` 拆入参数表 | 参数说明优先写在对应形参或 `[paramName]` 文档行；已有 Markdown 链接 `[text](url)` 保持原样 |

**原则：** 注释不合规导致的文档问题，应在组件源码中补全/修正 `///` 注释，而不是在工具里打补丁。

### enum 暴露与注释规范

#### 哪些 enum 应该暴露到 API 文档

满足任一条件即可视为对外 API，应该暴露并维护注释：

- 出现在 public 组件/类的构造参数中
- 出现在 public 方法参数、返回值、属性或回调类型中
- 用户在示例代码或业务代码中可能直接写出该枚举值

如果一个 enum 只是组件内部状态、布局阶段、动画阶段或其他实现细节，不希望出现在文档中，应优先在源码层收敛为私有类型（如 `_InternalPhase`），而不是依赖工具做特殊排除。

#### public enum 的注释要求

- enum 本身应有总说明，解释这组取值的用途
- enum 成员应补充 `///` 注释；当前工具会将成员说明展示在「枚举值」表中
- 若成员未写注释，文档说明列会显示 `-`；`validate` 会将其视为源码问题并给出 `source/WARN`
- 若枚举值本身语义极其直观（如 `small` / `medium` / `large`、`circle` / `square`），可在 enum 前添加普通注释 `// doc-simple-enum`，表示成员说明可省略；该标记不会进入 Flutter / dartdoc 正式文档注释

`simple enum` 示例：

```dart
// doc-simple-enum
/// 头像尺寸
enum TAvatarSize { small, medium, large }
```

对于 `simple enum`：

- 文档中的「枚举值」改为仅展示名称，不再渲染整列 `-`
- `validate` 不再对成员缺少说明发出告警
- 若成员语义后续变复杂，应移除该标记并补充 `///` 注释

建议优先补齐以下类型的成员说明：

- 行为型：如触发方式、交互模式
- 状态型：如选中、禁用、加载阶段
- 位置型：如 top/bottom/left/right
- 逻辑型：如 single/range/multiple

样式型枚举（如 `primary` / `secondary` / `outline`）即使语义较直观，也建议至少补一条简短说明，避免文档长期出现 `-`。

### 组件demo注释示例

```dart
/// demo名称（可以为空，为空的时候默认显示组件名称）
/// demo示例介绍（可以为空）
```

## 本地开发与测试

当 `tdesign-component/pubspec.yaml` 使用 path 依赖指向本仓库时，可在本地直接验证文档生成，无需发布到 git：

```bash
# 1. 确保 component 的 pubspec 已配置：
#    tdesign_flutter_tools:
#      path: ../tdesign-flutter-tools

# 2. 在 component 目录解析依赖（需要网络）
cd ../tdesign-component && dart pub get

# 3. 运行本地测试脚本（picker / calendar / dialog）
./scripts/local_test.sh picker
```

若 `dart pub get` 因网络不可用失败，可临时将 `tdesign-component/.dart_tool/package_config.json` 中
`tdesign_flutter_tools` 的 `rootUri` 指向本地路径，脚本会通过 `--packages` 跳过联网校验：

```bash
./scripts/local_test.sh calendar
```

## 组件库工具使用方法

### 初始化工具调用命令

```bash
dart bin/main.dart generate
    --file                相对ui_component目录的组件文件路径
    --folder              相对ui_component目录的组件文件夹路径
    --name                组件名，多个组件名之间用英文,分割
    --folder-name         [可选]生成的组件示例文件夹名称,默认生成的文件夹名称是第一个name参数的下划线表示
    --[no-]only-api       是否只更新api文件
    --[no-]use-grammar    是否采用语法分析器,默认采用词法分析
```

---

### 一、 初始化命令

初始化命令有以下 3 种使用方式：

1、初始化一个组件文件中的一个组件示例，没有--folder-name的时候，默认文件夹名称是第一个name的下划线表示，示例：

```bash
dart bin/main.dart generate --file lib/checkbox/custom_check_box.dart --name TECheckBox --folder-name checkbox
```

2、把一个文件中的多个组件合并生成一份示例数据（api说明生成在一个文件中），没有--folder-name的时候，默认文件夹名称是第一个name的下划线表示

```bash
dart bin/main.dart generate --file lib/checkbox/custom_check_box.dart --name SquareCheckbox,TECheckBox --folder-name checkbox2
```

3、把一个文件夹中的多个组件合并生成一份示例数据（api说明生成在一个文件中），没有--folder-name的时候，默认文件夹名称是第一个name的下划线表示

```bash
dart bin/main.dart generate --folder lib/setting --name SettingItemWidget,SettingTowRowCellWidget,SettingLeftTextCellWidget,SettingCheckBoxCellWidget,SettingTowTextCellWidget,SettingTowLineTextCellWidget,SettingGroupWidget,SettingGroupTextWidget --folder-name setting
```

如果想只更新API文档，那么在上述初始化的命令之后增加参数 `--only-api` 即可

默认采用词法分析，如果想采用语法分析的方式生成代码，那么在上述初始化的命令之后增加参数 `--use-grammar` 即可

### 二、更新组件示例命令

生成命令行工具

在根目录执行以下命令：

### 编译当前平台的二进制文件

```bash
dart compile exe bin/main.dart -o demo_tool
```

### 编译不同环境的二进制文件

```bash
# macOS (Intel)
dart compile exe bin/main.dart -o demo_tool_macos_intel

# macOS (Apple Silicon/M1/M2)
dart compile exe bin/main.dart -o demo_tool_macos_arm64

# Linux x64
dart compile exe bin/main.dart -o demo_tool_linux_x64

# Windows x64
dart compile exe bin/main.dart -o demo_tool_windows_x64.exe
```

注意：要编译其他平台的二进制文件，需要在对应的平台上运行编译命令，或者使用交叉编译工具。

附录：

生成代码文档

```bash
flutter pub global run dartdoc:dartdoc
```
