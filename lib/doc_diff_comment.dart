import 'dart:io';

/// 基于 git 工作区变更，生成 PR 文档 diff 评论 Markdown。
class DocDiffComment {
  DocDiffComment({required this.repoRoot, required this.outPath});

  final String repoRoot;
  final String outPath;

  static const _gitPaths = [
    'tdesign-component/example/assets/api',
    'tdesign-site/src',
  ];
  static const _maxLines = 150;
  static const _maxBytes = 55 * 1024;

  Future<void> write() async {
    final files = await _changedFiles();
    final body = StringBuffer('## 文档变更\n\n');
    if (files.isEmpty) {
      body.writeln('_无变更_');
    } else {
      var omitted = 0;
      for (final f in files) {
        final block = _details(f);
        if (body.length + block.length > _maxBytes) {
          omitted++;
          continue;
        }
        body.write(block);
      }
      if (omitted > 0) {
        body.writeln('\n> 另有 $omitted 个文件未展示（评论长度限制）。');
      }
    }
    File(outPath).writeAsStringSync(body.toString());
    stdout.writeln('Wrote $outPath');
  }

  Future<List<({String path, String diff})>> _changedFiles() async {
    final paths = <String>{};
    final git = ['-C', repoRoot];

    final names = await Process.run('git', [...git, 'diff', '--name-only', '--', ..._gitPaths]);
    _exitIfFail(names, 'git diff --name-only');
    for (final line in '${names.stdout}'.split('\n')) {
      if (line.trim().isNotEmpty) paths.add(line.trim());
    }

    final status = await Process.run('git', [...git, 'status', '--porcelain', '-u', '--', ..._gitPaths]);
    _exitIfFail(status, 'git status');
    for (final line in '${status.stdout}'.split('\n')) {
      if (line.startsWith('??')) paths.add(line.substring(3).trim());
    }

    final out = <({String path, String diff})>[];
    for (final rel in paths.toList()..sort()) {
      if (!_match(rel)) continue;
      out.add((path: rel, diff: await _diff(rel)));
    }
    return out;
  }

  bool _match(String rel) {
    final name = rel.split(Platform.pathSeparator).last;
    return name.endsWith('_api.md') || name == 'README.md';
  }

  Future<String> _diff(String rel) async {
    final git = ['-C', repoRoot];
    final tracked = await Process.run('git', [...git, 'ls-files', '--error-unmatch', rel]);
    if (tracked.exitCode == 0) {
      final r = await Process.run('git', [...git, 'diff', '--no-color', '-U3', '--', rel]);
      return '${r.stdout}'.trimRight().isEmpty ? '(无变更内容)' : '${r.stdout}'.trimRight();
    }
    final full = '${Directory(repoRoot).path}${Platform.pathSeparator}$rel';
    final r = await Process.run('diff', ['-u', '/dev/null', full]);
    return '${r.stdout}'.trimRight().isEmpty ? '(新文件)' : '${r.stdout}'.trimRight();
  }

  String _details(({String path, String diff}) f) {
    var text = f.diff;
    final lines = text.split('\n');
    if (lines.length > _maxLines) {
      text = '${lines.take(_maxLines).join('\n')}\n...（共 ${lines.length} 行）';
    }
    return '''
<details>
<summary>${f.path}</summary>

```diff
$text
```

</details>

''';
  }

  void _exitIfFail(ProcessResult r, String cmd) {
    if (r.exitCode != 0) {
      stderr.writeln('$cmd 失败: ${r.stderr}');
      exit(r.exitCode);
    }
  }
}
