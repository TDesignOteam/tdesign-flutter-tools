# demo_tool

[![Flutter Version](https://img.shields.io/badge/Flutter-%3E%3D3.32.0%20%3C4.0.0-blue.svg?logo=flutter)](https://flutter.dev/)
[![Dart Version](https://img.shields.io/badge/Dart-%3E%3D3.0.0%20%3C4.0.0-blue.svg?logo=dart)](https://dart.dev/)

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

### 组件demo注释示例

```dart
/// demo名称（可以为空，为空的时候默认显示组件名称）
/// demo示例介绍（可以为空）
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
