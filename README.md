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
   - 顶层函数 / 静态方法 / 工厂 / 构造：推荐在该方法的 `///` 里写 `[paramName] 说明`。
   - 构造参数：也可写在同名字段的 `///` 上。
   - 参数声明前的行内 `///` 也会读取，包含带默认值的命名参数。
   - 无注释时表格「说明」列为 `-`，属预期，应在源码补全，**不要**在工具里打补丁。

4. **不要把静态方法参数表只写在类简介里**
   类注释中的 `## xxx 参数` Markdown 表**不会**回填到方法参数表，方法表仍会显示 `-`。

5. **`--get-comments` 控制是否输出 `#### 简介`**
   - 不加：只生成参数表、工厂、枚举值等，**不写**类简介。
   - 加上：输出简介，保留行为说明、段落、列表与行内参数值；完整代码示例及独立示例标题由专门的示例页展示，不进入 API 页。此规则同样适用于构造、方法及其他 API 正文，源码 dartdoc 保持完整。
   旧版曾在多类型之间误插入空 `` ``` `` 两行，当前已移除；请用 `dart run bin/main.dart` 生成。

6. **`library` + `part` 需在 `--name` 中显式列出声明**
   例如 popup 的 `TPopupOptions`、`TPopupPlacement` 在 part 文件中，需写入 `--name` 或单独对 part 文件生成。

7. **顶层函数需在 `--name` 中显式列出**
   工具会为任意公开顶层函数生成独立 API 区块，包含返回类型、参数类型、默认值和 dartdoc；私有函数、getter、setter 以及未登记函数不会被收录。
   维护组件清单时加 `--strict-names`，只输出 `--name` 中登记的声明，避免同文件辅助枚举或 typedef 混入其他组件文档。文件夹扫描会递归读取 `.dart` 源文件。

   公开普通实例方法、字段访问器、命名/工厂/无参构造与命名 extension 均会展示；Flutter 构建钩子、未自行补充文档的标准继承 override、`@internal` 和 `@visibleForTesting` 成员不收录。默认值保留声明值，Theme / Token 回退由源码注释说明；构造及方法参数另列是否必填。泛型在 Markdown 表格中转义，保留网页与 Demo 中的完整类型。类/extension 不再单列声明章节，类型参数和 extension 适用类型用简短说明展示；构造方法只展示名称、参数表和行为说明，不重复完整代码及 const 标识；含位置参数时另列简短参数形式以保留顺序和参数分组。方法及函数保留源码调用签名；泛型约束、默认值及必填状态不丢失，每个构造或方法独立列出完整参数。自定义 copyWith/lerp/Token 查询运算符会展示，即使源码尚未补注释也不会静默遗漏。参数说明仅从源码注释、构造/复制字段或 AST 可证明的透传获取；Widget key 的兜底说明仅适用于 Key/Key?，不会套用到 Token 的 String/Object 键。

8. **不对个别组件做特殊兼容**
   工具只保留单一 AST / dartdoc 解析路线；注释位置或格式不对，应在 `tdesign-component` 修正。

   解析（`component_rule.dart`）、框架成员筛选（`public_member_policy.dart`）、签名格式化（`api_signature.dart`）与 Markdown 渲染（`api_markdown.dart`）分别维护。渲染不修改解析模型；构造/工厂/external 按 AST 标记处理。仅过滤能由所属基类识别的框架钩子，业务 `build` 和普通接口 `override` 不会因名字或缺注释被隐藏。函数类型参数保留完整类型；无法从源码推断的父类/字段类型显示 `-`，不伪造 `dynamic`。代码单元格保留字符串空白并转义 HTML 实体。

   默认构造参数使用五级子标题，`validate` 同时兼容既有的四级参数标题。CI 在 Flutter 3.32.0 与 latest 下运行完整工具单测，包含真实 CLI generate → validate 正例及删参数反例。

9. **生成与验收共用消费仓库 `tool/components.json`**
   `validate --component-root ...` 默认验收完整 manifest，支持 file/folder、声明及顶层函数。仍可用 `--config` 指定原有 YAML/JSON 抽测清单；`ERROR` 需为 0，`WARN` 多为 enum 成员缺注释等源码问题。

## 快速开始

```bash
# 环境
export TOOLS=/path/to/tdesign-flutter-tools
export COMPONENT=/path/to/tdesign-flutter/tdesign-component
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
  --config $COMPONENT/tool/components.json

# 仅测部分组件
dart run bin/main.dart validate \
  --component-root $COMPONENT \
  --config $COMPONENT/tool/components.json \
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

### 顶层函数 / 静态方法 / 工厂（推荐）

```dart
/// 方法简述。
///
/// [context] 用于展示浮层。
/// [options] 配置对象。
static void show(BuildContext context, {required FooOptions options}) { ... }
```

顶层函数使用相同的 dartdoc 参数约定，并直接将函数名加入 `--name`：

```bash
dart run bin/main.dart generate \
  --folder lib/src/components/drawer \
  --name TDrawer,showTDrawer \
  --folder-name drawer \
  --only-api \
  --get-comments
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
| 提取 class、enum、typedef、顶层函数的类型和默认值；过滤 `this.xxx` 误识别 | 参数 / 字段 `///` 文案 |
| 静态方法 → 命名工厂 → 默认构造 → 公开属性/成员 | 注释位置、语义正确 |
| 隐藏 `ClassName._`；dartdoc → Markdown | 无注释时显示 `-` |
| 同文件收录 public enum/typedef；跨文件重复告警 | `--name` 与 CI 清单一致 |
| API 保留行为契约，完整示例由示例页展示 | 源码 dartdoc 可以保留示例；不在类简介用表写方法参数 |

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
  --config $COMPONENT/tool/components.json \
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
