# tdesign_flutter_tools

[TDesign Flutter](https://github.com/Tencent/tdesign-flutter) component demo and API documentation generator.

The tool is used by `tdesign-component` to generate files such as `example/assets/api/button_api.md` from Dart source comments. It now uses one AST parsing path only, so documentation should be written in forms that can be read without full semantic resolution.

## Generate API Docs

Run from the component package root:

```bash
flutter pub run tdesign_flutter_tools:main generate \
  --file lib/src/components/button/t_button.dart \
  --name TButton,TButtonResolve \
  --folder-name button \
  --output example/assets/api/ \
  --only-api
```

Use `--folder` instead of `--file` when a component API is split across multiple Dart files:

```bash
flutter pub run tdesign_flutter_tools:main generate \
  --folder lib/src/components/tag \
  --name TTag,TSelectTag,TTagDefaults \
  --folder-name tag \
  --output example/assets/api/ \
  --only-api
```

Useful flags:

| Flag | Purpose |
| --- | --- |
| `--file` | Parse one Dart file. |
| `--folder` | Parse all files in one folder. |
| `--name` | Comma-separated public classes to document, in output order. |
| `--folder-name` | Output API file prefix, for example `button` -> `button_api.md`. |
| `--output` | Output directory, usually `example/assets/api/`. |
| `--only-api` | Generate only API markdown. |
| `--get-comments` | Include class-level introduction text. |

## Comment Contract

### Class Comment

Class comments become the component introduction when `--get-comments` is enabled.

```dart
/// Button component.
class TButton extends StatelessWidget {
}
```

### Constructor Parameters

Constructor parameters can be documented with inline parameter Dartdoc, constructor block `[param]` comments, or field comments for `this.foo` parameters. Inline parameter comments have the highest priority, then `[param]` comments, then field comments.

```dart
class TTextSpan extends TextSpan {
  /// Creates a TDesign text span.
  ///
  /// [text] Text content.
  TTextSpan({
    /// Current build context used to resolve theme tokens.
    BuildContext? context,
    String? text,
  });
}
```

Field formal parameters are resolved from their field documentation:

```dart
class TButton extends StatelessWidget {
  const TButton({required this.child});

  /// Button content.
  final Widget child;
}
```

### Static Methods

Static method descriptions should keep the method summary first, followed by one `[param]` line per public parameter. The generated markdown renders a separate parameter table so every parameter has its own description.

```dart
class TButtonResolve {
  /// Resolves the final button style.
  ///
  /// [variant] Visual variant.
  /// [colorScheme] Semantic color scheme.
  /// [disabled] Whether the button is disabled.
  static ButtonStyle resolve({
    required TButtonVariant variant,
    TButtonColorScheme? colorScheme,
    bool disabled = false,
  }) {
    // ...
  }
}
```

### Demo Files

Demo metadata is parsed from class annotations and documentation comments.

```dart
/// Basic usage
/// Shows the default state
@Priority(1)
class ButtonDemo1 extends StatelessWidget {
}
```

## Development

Run all tool tests:

```bash
flutter test
```

Run with coverage:

```bash
flutter test --coverage
```

Format changed Dart files before committing:

```bash
dart format lib test bin
```

The regression tests cover:

| Area | Coverage |
| --- | --- |
| Constructor API parsing | Inline parameter docs, `[param]` block docs, field formal fallback, default values. |
| Static method API parsing | Independent parameter descriptions and AST-only return type extraction. |
| API markdown rendering | Dedicated static method parameter tables. |
| Demo parsing | `@Priority`, demo class naming, and comment extraction. |

## Known Direction

The next larger refactor should introduce a structured intermediate API model, then render markdown from that model. That will make `generate --check`, strict missing-description failures, and JSON output straightforward without changing component source comments again.
