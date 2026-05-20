#!/usr/bin/env dart
/// 生成 PR 文档 diff 评论（develop 已提交 vs PR tools 重新生成）。
///
/// dart run .github/scripts/build_doc_diff_comment.dart \
///   --out doc-diff-comment.md \
///   --preview-url https://preview-pr-1-xxx.surge.sh \
///   --compare /tmp/api-baseline path/to/api "API 文档" "*_api.md" \
///   --compare /tmp/site-baseline path/to/src "站点文档" "README.md"
import 'dart:io';

const _maxLinesPerFile = 150;
const _maxBytes = 55 * 1024;

void main(List<String> args) async {
  final config = _Config.parse(args);
  if (config == null) {
    stderr.writeln(_usage);
    exit(1);
  }

  final slugs = <String>{};
  final sections = StringBuffer();
  var omitted = 0;

  for (final pair in config.pairs) {
    final changed = await _diffPair(pair);
    for (final c in changed) {
      final slug = _componentSlug(c.path);
      if (slug != null) slugs.add(slug);
    }

    sections.writeln('### ${pair.title}');
    sections.writeln();
    if (changed.isEmpty) {
      sections.writeln('_无变更_');
      sections.writeln();
      continue;
    }

    for (final file in changed) {
      final block = _detailsBlock(file);
      if (sections.length + block.length > _maxBytes) {
        omitted++;
        continue;
      }
      sections.write(block);
    }
  }

  final out = StringBuffer('''
## 文档变更预览

> 对比基准：[Tencent/tdesign-flutter](https://github.com/Tencent/tdesign-flutter) @ develop 已提交文档 vs 本 PR tools 重新生成

''');

  if (slugs.isNotEmpty && config.previewUrl != null) {
    final url = config.previewUrl!.replaceAll(RegExp(r'/+$'), '');
    out.writeln('**有变更的组件预览**:');
    for (final s in slugs.toList()..sort()) {
      out.writeln('- [$s]($url/flutter/components/$s)');
    }
    out.writeln();
  }

  out.write(sections);
  if (omitted > 0) {
    out.writeln('> 还有 **$omitted** 个文件未展示（GitHub 评论长度限制）。\n');
  }

  File(config.outPath).writeAsStringSync(out.toString());
  stdout.writeln('Wrote ${config.outPath} (${out.length} bytes)');
}

class _Pair {
  _Pair(this.baseline, this.generated, this.title, this.namePattern);
  final String baseline;
  final String generated;
  final String title;
  final String namePattern;
}

class _Config {
  _Config({required this.outPath, required this.pairs, this.previewUrl});
  final String outPath;
  final List<_Pair> pairs;
  final String? previewUrl;

  static _Config? parse(List<String> args) {
    String? out;
    String? previewUrl;
    final pairs = <_Pair>[];

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--out':
          out = args[++i];
        case '--preview-url':
          previewUrl = args[++i];
        case '--compare':
          if (i + 4 >= args.length) return null;
          pairs.add(_Pair(args[++i], args[++i], args[++i], args[++i]));
      }
    }
    if (out == null || pairs.isEmpty) return null;
    return _Config(outPath: out, pairs: pairs, previewUrl: previewUrl);
  }
}

const _usage = '''
用法:
  dart run .github/scripts/build_doc_diff_comment.dart \\
    --out doc-diff-comment.md \\
    [--preview-url <url>] \\
    --compare <baseline> <generated> <标题> <文件名模式> ...
''';

class _Changed {
  _Changed(this.path, this.diff, this.added, this.removed);
  final String path;
  final String diff;
  final int added;
  final int removed;
}

Future<List<_Changed>> _diffPair(_Pair pair) async {
  final baseDir = Directory(pair.baseline);
  final genDir = Directory(pair.generated);
  if (!baseDir.existsSync() || !genDir.existsSync()) {
    stderr.writeln('ERROR: 目录不存在');
    exit(1);
  }

  final paths = <String>{};
  for (final root in [pair.baseline, pair.generated]) {
    final prefix = '${Directory(root).absolute.path}${Platform.pathSeparator}';
    await for (final entity in Directory(root).list(recursive: true)) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (!_matchName(name, pair.namePattern)) continue;
      paths.add(entity.path.substring(prefix.length));
    }
  }

  final result = <_Changed>[];
  for (final rel in paths.toList()..sort()) {
    final a = File('${pair.baseline}${Platform.pathSeparator}$rel');
    final b = File('${pair.generated}${Platform.pathSeparator}$rel');
    if (a.existsSync() && b.existsSync() && await a.readAsString() == await b.readAsString()) {
      continue;
    }

    final proc = await Process.run('diff', [
      '-u', '-U0',
      '--label', 'develop/$rel',
      '--label', 'pr/$rel',
      a.existsSync() ? a.path : '/dev/null',
      b.existsSync() ? b.path : '/dev/null',
    ]);
    final text = '${proc.stdout}${proc.stderr}'.trimRight();
    var added = 0, removed = 0;
    for (final line in text.split('\n')) {
      if (line.startsWith('+++') || line.startsWith('---') || line.startsWith('@@')) continue;
      if (line.startsWith('+')) added++;
      if (line.startsWith('-')) removed++;
    }
    result.add(_Changed(rel, text.isEmpty ? '(无 diff 输出)' : text, added, removed));
  }
  return result;
}

bool _matchName(String filename, String pattern) {
  if (pattern.startsWith('*')) return filename.endsWith(pattern.substring(1));
  return filename == pattern;
}

String _detailsBlock(_Changed f) {
  var body = f.diff;
  final lines = body.split('\n');
  if (lines.length > _maxLinesPerFile) {
    body = '${lines.take(_maxLinesPerFile).join('\n')}\n\n... 已截断（共 ${lines.length} 行）';
  }
  return '''
<details>
<summary>${f.path} (+${f.added} −${f.removed})</summary>

```diff
$body
```

</details>

''';
}

String? _componentSlug(String rel) {
  final name = rel.split(Platform.pathSeparator).last;
  if (name.endsWith('_api.md')) {
    return name.substring(0, name.length - '_api.md'.length);
  }
  if (rel.endsWith('${Platform.pathSeparator}README.md')) {
    return rel.substring(0, rel.length - '${Platform.pathSeparator}README.md'.length);
  }
  return null;
}
