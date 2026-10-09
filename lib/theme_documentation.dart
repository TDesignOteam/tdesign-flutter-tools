/// Dartdoc category used by component themes that expose configuration tables.
const componentThemeCategory = '{@category ComponentTheme}';

/// Require an authored category and a real ThemeExtension declaration.
bool usesThemeConfigurationTable(String declaration, String documentation) =>
    documentation.contains(componentThemeCategory) &&
    RegExp(r'\bextends\s+ThemeExtension\s*<').hasMatch(declaration);

/// Shared ThemeExtension operations; component-specific methods stay visible.
const sharedThemeMethods = {'copyWith', 'lerp', 'merge'};
