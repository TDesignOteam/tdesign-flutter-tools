#!/usr/bin/env dart
/// CI 专用：生成 PR 文档 diff 评论 Markdown。
///
/// 用法（在 tdesign-flutter 根目录）:
///   dart run <tools-repo>/.github/scripts/build_doc_diff_comment.dart \
///     --out /path/to/doc-diff-comment.md
import 'dart:io';

import 'package:tdesign_flutter_tools/doc_diff_comment.dart';

Future<void> main(List<String> args) async {
  String? out;
  var repo = '.';

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--out':
        out = args[++i];
      case '--repo':
        repo = args[++i];
    }
  }
  if (out == null) {
    stderr.writeln('用法: build_doc_diff_comment.dart --out <file> [--repo <flutter-root>]');
    exit(1);
  }

  await DocDiffComment(repoRoot: repo, outPath: out).write();
}
