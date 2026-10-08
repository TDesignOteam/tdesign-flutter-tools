import 'model.dart';

/// 从 analyzer 文档注释 token 或 element.documentationComment 提取的原始文本。
String documentationCommentRaw(String? raw) {
  if (raw == null || raw.isEmpty) {
    return '';
  }
  return raw;
}

/// 解析后的文档：正文（Markdown 就绪）+ 可选的参数说明表。
class ParsedDocumentation {
  ParsedDocumentation({
    required this.narrative,
    this.parameterDocs = const <String, String>{},
  });

  final String narrative;
  final Map<String, String> parameterDocs;
}

/// 去掉 `///`、`/** */` 标记；围栏内保留行尾空格与缩进。
String normalizeDocumentationText(String raw) {
  if (raw.isEmpty) {
    return '';
  }
  var text = raw;
  if (text.contains('/**') || text.contains('/*')) {
    text = text
        .replaceAll(RegExp(r'^[ \t]*/\*\*?', multiLine: true), '')
        .replaceAll(RegExp(r'\*/[ \t]*$', multiLine: true), '')
        .replaceAll(RegExp(r'^[ \t]*\*[ \t]?', multiLine: true), '');
  }
  text = text.replaceAll(RegExp(r'^[ \t]*///[ \t]?', multiLine: true), '');

  final List<String> lines = <String>[];
  var inFence = false;
  for (final String line in text.split('\n')) {
    final String trimmed = line.trim();
    if (trimmed.startsWith('```')) {
      inFence = !inFence;
      lines.add(trimmed);
      continue;
    }
    if (inFence) {
      lines.add(line.trimRight());
      continue;
    }
    if (trimmed.isEmpty) {
      if (lines.isNotEmpty && lines.last.isEmpty) {
        continue;
      }
      lines.add('');
      continue;
    }
    lines.add(trimmed);
  }
  while (lines.isNotEmpty && lines.first.isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}

/// dartdoc 方括号引用 → API Markdown 行内代码（通用规则，非组件特化）。
String formatDartdocReferencesInProse(
  String text, {
  Set<String> parameterNames = const <String>{},
}) {
  if (text.isEmpty) {
    return text;
  }
  final StringBuffer buffer = StringBuffer();
  var inFence = false;
  for (final String line in text.split('\n')) {
    final String trimmed = line.trim();
    if (trimmed.startsWith('```')) {
      inFence = !inFence;
      if (buffer.isNotEmpty) {
        buffer.writeln();
      }
      buffer.write(line);
      continue;
    }
    if (inFence) {
      if (buffer.isNotEmpty) {
        buffer.writeln();
      }
      buffer.write(line);
      continue;
    }
    if (buffer.isNotEmpty) {
      buffer.writeln();
    }
    buffer.write(
      _formatDartdocReferencesInLine(line, parameterNames: parameterNames),
    );
  }
  return buffer.toString();
}

String _formatDartdocReferencesInLine(
  String line, {
  required Set<String> parameterNames,
}) {
  final StringBuffer out = StringBuffer();
  var i = 0;
  var inInlineCode = false;
  while (i < line.length) {
    if (line[i] == '`') {
      inInlineCode = !inInlineCode;
      out.write('`');
      i++;
      continue;
    }
    if (inInlineCode) {
      out.write(line[i]);
      i++;
      continue;
    }
    if (line[i] == '[') {
      final int close = line.indexOf(']', i + 1);
      if (close == -1) {
        out.write(line[i]);
        i++;
        continue;
      }
      if (close + 1 < line.length && line[close + 1] == '(') {
        out.write(line.substring(i, close + 1));
        i = close + 1;
        continue;
      }
      final String inner = line.substring(i + 1, close).trim();
      if (inner.isNotEmpty) {
        out.write('`$inner`');
      } else {
        out.write('[]');
      }
      i = close + 1;
      continue;
    }
    out.write(line[i]);
    i++;
  }
  return out.toString();
}

final RegExp _paramDocHeader = RegExp(r'^\[([a-zA-Z_]\w*)\](?:\s+(.*))?$');

/// 按 [dartdoc 参数文档约定](https://dart.dev/tools/dart-doc/comments#document-parameters)
/// 拆分正文与 `[paramName]` 说明；`parameterNames` 为空时不做参数拆分。
ParsedDocumentation parseDocumentation(
  String raw, {
  Iterable<String> parameterNames = const <String>[],
}) {
  final String normalized = normalizeDocumentationText(raw);
  if (normalized.isEmpty) {
    return ParsedDocumentation(narrative: '');
  }

  final Set<String> names =
      parameterNames
          .map((String n) => n.trim())
          .where((String n) => n.isNotEmpty)
          .toSet();
  if (names.isEmpty) {
    return ParsedDocumentation(
      narrative: formatDartdocReferencesInProse(normalized),
    );
  }

  final Map<String, String> paramDocs = <String, String>{};
  final List<String> narrativeLines = <String>[];
  String? activeParam;
  var inFence = false;

  void flushActiveParam() {
    activeParam = null;
  }

  for (final String line in normalized.split('\n')) {
    final String trimmed = line.trim();
    if (trimmed.startsWith('```')) {
      flushActiveParam();
      inFence = !inFence;
      narrativeLines.add(trimmed);
      continue;
    }
    if (inFence) {
      flushActiveParam();
      narrativeLines.add(line);
      continue;
    }
    if (trimmed.isEmpty) {
      flushActiveParam();
      if (narrativeLines.isNotEmpty && narrativeLines.last.isNotEmpty) {
        narrativeLines.add('');
      }
      continue;
    }

    final RegExpMatch? header = _paramDocHeader.firstMatch(trimmed);
    if (header != null && names.contains(header.group(1))) {
      final String name = header.group(1)!;
      final String rest = (header.group(2) ?? '').trim();
      paramDocs[name] = rest;
      // 参数说明属于同一 Markdown 段落。直到空行、下一参数或代码围栏
      // 才结束，正文中的其他 dartdoc 引用也可能位于续行开头。
      activeParam = name;
      continue;
    }

    if (activeParam != null) {
      final String existing = paramDocs[activeParam!] ?? '';
      paramDocs[activeParam!] =
          existing.isEmpty ? trimmed : '$existing\n$trimmed';
      continue;
    }

    flushActiveParam();
    narrativeLines.add(trimmed);
  }

  var narrative = narrativeLines.join('\n');
  while (narrative.contains('\n\n\n')) {
    narrative = narrative.replaceAll('\n\n\n', '\n\n');
  }

  final Map<String, String> formattedParamDocs = <String, String>{
    for (final MapEntry<String, String> e in paramDocs.entries)
      e.key: formatDartdocReferencesInProse(
        e.value.trim(),
        parameterNames: names,
      ),
  };

  return ParsedDocumentation(
    narrative: formatDartdocReferencesInProse(
      narrative.trim(),
      parameterNames: names,
    ),
    parameterDocs: formattedParamDocs,
  );
}

/// 解析可调用成员（构造 / 静态方法 / 实例方法）文档并写回 [StaticMethodInfo]。
void applyCallableDocumentation(StaticMethodInfo method) {
  final String? intro = method.introduction;
  if (intro == null || intro.isEmpty) {
    return;
  }
  final ParsedDocumentation parsed = parseDocumentation(
    intro,
    parameterNames: method.params.map((PropertyInfo p) => p.name),
  );
  method.introduction = parsed.narrative;
  for (final PropertyInfo param in method.params) {
    final String? fromDoc = parsed.parameterDocs[param.name];
    if (fromDoc != null && fromDoc.isNotEmpty && param.introduction.isEmpty) {
      param.introduction = fromDoc;
    }
  }
}

/// 类 / 字段 / 枚举等仅正文，无参数表拆分。
String formatDocumentationForMarkdown(String? raw) {
  if (raw == null || raw.isEmpty) {
    return '';
  }
  return parseDocumentation(raw).narrative;
}

/// 保留简介中的正文与示例代码，只去掉首尾空白。
///
/// dartdoc 的代码示例也是用户文档；删除围栏会丢失使用方式，并留下孤立的
/// “示例”或“典型用法”标题。Markdown 渲染器负责呈现完整简介。
String formatIntroductionForApiSummary(String text) => text.trim();

/// 兼容旧工具调用方；简介现在保留示例代码。
@Deprecated('Use formatIntroductionForApiSummary instead.')
String stripIntroductionForApiSummary(String text) =>
    formatIntroductionForApiSummary(text);
