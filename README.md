# tdesign_flutter_tools

[![Flutter Version](https://img.shields.io/badge/Flutter-%3E%3D3.32.0-blue.svg?logo=flutter)](https://flutter.dev/)
[![Dart Version](https://img.shields.io/badge/Dart-%3E%3D3.7.0-blue.svg?logo=dart)](https://dart.dev/)

[TDesign Flutter](https://github.com/Tencent/tdesign-flutter) 组件库文档与示例生成工具（基于 smart_cli）。

## 注意事项

1. **在 `tdesign-component` 根目录执行 `generate`**
   `basePath` 指向 component 根目录；在 tools 仓库里直接跑会找不到源码。

2. **只生成 API 时加 `--only-api`**
   否则会额外生成 demo 示例文件。

3. **参数说明写在「方法注释」或「字段注释」**
   - 静态方法 / 工厂 / 构造：推荐在该方法的 `///` 里写 `[paramName] 说明`。
   - 构造参数：也可写在同名字段的 `///` 上。
   - 无注释时表格「说明」列为 `-`，属预期，应在源码补全，**不要**在工具里打补丁。

4. **不要把静态方法参数表只写在类简介里**
   类注释中的 `## xxx 参数` Markdown 表**不会**回填到方法参数表，方法表仍会显示 `-`。

5. **`--get-comments` 控制是否输出 `#### 简介`**
   - 不加：只生成参数表、工厂、枚举值等，**不写**类简介。
   - 加上：输出简介，并自动去掉 `**示例**` 与所有 `` ``` `` 代码块（简介里不放代码）。
   旧版曾在多类型之间误插入空 `` ``` `` 两行，当前已移除；请用 `dart run bin/main.dart` 生成。

6. **`library` + `part` 需在 `--name` 中显式列出类型**
   例如 popup 的 `TPopupOptions`、`TPopupPlacement` 在 part 文件中，需写入 `--name` 或单独对 part 文件生成。

7. **不对个别组件做特殊兼容**
   工具只保留单一 AST / dartdoc 解析路线；注释位置或格式不对，应在 `tdesign-component` 修正。

8. **CI 抽测清单见 `.github/config/tdesign_api.yaml`**
   本地 `validate` 与 CI 使用同一配置；`ERROR` 需为 0，`WARN` 多为 enum 成员缺注释等源码问题。

## 快速开始

```bash
# 环境
export TOOLS=/path/to/tdesign-flutter-tools
export COMPONENT=/path/to/tdesign-flutter-v1/tdesign-component
export TDESIGN_COMPONENT_ROOT=$COMPONENT   # 跑 tools 单元测试时用

cd $TOOLS && dart pub get
```

**生成 API（示例：popup）**

```bash
cd $COMPONENT

dart run $TOOLS/bin/main.dart generate \
  --folder lib/src/components/popup \
  --name TPopup,TPopupOptions,TPopupHandle,TPopupPlacement,TPopupTrigger \
  --folder-name popup \
  --only-api \
  --get-comments \
  --output $TOOLS/tmp-local-preview/popup/
```

**完备性校验（在 tools 仓库根目录）**

```bash
cd $TOOLS

dart run bin/main.dart validate \
  --component-root $COMPONENT \
  --config .github/config/tdesign_api.yaml

# 仅测部分组件
dart run bin/main.dart validate \
  --component-root $COMPONENT \
  --config .github/config/tdesign_api.yaml \
  --components button,popup
```

## 注释规范

### 类 / 字段

```dart
/// 组件简介（class / enum / typedef）
class TFoo { ... }

/// 字段或构造参数说明
final int count;
```

### 静态方法 / 工厂（推荐）

```dart
/// 方法简述。
///
/// [context] 用于展示浮层。
/// [options] 配置对象。
static void show(BuildContext context, {required FooOptions options}) { ... }
```

dartdoc 引用 `[Type]`、`[param]` 会转为 Markdown 行内代码；已有 Markdown 链接 `[text](url)` 保持原样。

### 命名工厂「通用参数」

多个命名工厂 1:1 透传同一组参数到默认构造时，文档会合并「通用参数」表，各工厂只保留方向独有参数。

### enum

- 对外 API 的 enum 应有类型说明；成员建议写 `///`，否则文档与 `validate` 为 `-` / WARN。
- 语义极直观的枚举可在 enum 前加 `// doc-simple-enum`，成员表仅列名称且不告警。

```dart
// doc-simple-enum
/// 尺寸
enum TSize { small, medium, large }
```

### demo 示例（生成 demo 页时）

```dart
/// demo 名称（可空，默认组件名）
/// demo 说明（可空）
```

## 工具能力摘要

| 工具负责 | 源码负责 |
| --- | --- |
| 提取类型、默认值；过滤 `this.xxx` 误识别 | 参数 / 字段 `///` 文案 |
| 静态方法 → 命名工厂 → 默认构造 → 公开属性/成员 | 注释位置、语义正确 |
| 隐藏 `ClassName._`；dartdoc → Markdown | 无注释时显示 `-` |
| 同文件收录 public enum/typedef；跨文件重复告警 | `--name` 与 CI 清单一致 |
| 简介剥离 `**示例**` 代码块 | 不在类简介用表写方法参数 |

## 命令

在 **component 根目录**执行 `generate`：

```bash
dart run <tools>/bin/main.dart generate [选项]
```

| 选项 | 说明 |
| --- | --- |
| `--file` | 单个组件文件（相对 component 根） |
| `--folder` | 组件目录 |
| `--name` | 类型名，逗号分隔 |
| `--folder-name` | 输出文件名前缀，如 `popup` → `popup_api.md` |
| `--only-api` | 只生成 API，不生成 demo |
| `--output` | 输出目录（可用绝对路径写到 tools 仓库外预览） |

**示例**

```bash
# 单文件
dart run bin/main.dart generate \
  --file lib/src/components/checkbox/t_checkbox.dart \
  --name TCheckbox --folder-name checkbox --only-api

# 整个目录多类型
dart run bin/main.dart generate \
  --folder lib/src/components/dialog \
  --name TAlertDialog,TConfirmDialog \
  --folder-name dialog --only-api
```

**validate**（在 tools 根目录）：

```bash
dart run bin/main.dart validate \
  --component-root <tdesign-component> \
  --config .github/config/tdesign_api.yaml \
  [--components button,popup]
```

## 本地开发与测试

`tdesign-component` 通过 path 依赖本仓库时：

```bash
cd tdesign-component && dart pub get
cd ../tdesign-flutter-tools && ./scripts/local_test.sh picker
```

```bash
TDESIGN_COMPONENT_ROOT=/path/to/tdesign-component \
  dart test test/doc_format_test.dart test/static_method_doc_test.dart
```

## 编译可执行文件

```bash
dart compile exe bin/main.dart -o demo_tool
```

其它平台需在对应系统上编译，或使用交叉编译工具。
