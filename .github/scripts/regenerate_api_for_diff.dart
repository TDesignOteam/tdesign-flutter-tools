#!/usr/bin/env dart
/// CI 专用：在克隆的 tdesign-component 工作区批量重生成 API md（供 doc-diff 对比）。
/// 不在 bin/main.dart 暴露；tdesign-flutter 本地维护请用 generate / update。
///
/// 用法（在 tdesign-component 目录）:
///   dart run <tools-repo>/.github/scripts/regenerate_api_for_diff.dart
import 'dart:io';

import 'package:path/path.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:tdesign_flutter_tools/smart_create.dart';

Future<void> main(List<String> args) async {
  final componentRoot = Directory.current.path;
  final folders = args.isEmpty
      ? <String>[]
      : args.first.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  final componentsRoot = Directory(join(componentRoot, 'lib/src/components'));
  if (!componentsRoot.existsSync()) {
    stderr.writeln('ERROR: 请在 tdesign-component 根目录执行，且存在 lib/src/components');
    exit(1);
  }

  print('${DateTime.now().toLocal()}  [CI] 批量生成 API 文档（仅用于 diff 预览）...');
  var count = 0;
  final base = componentRoot.endsWith(Platform.pathSeparator)
      ? componentRoot
      : '$componentRoot${Platform.pathSeparator}';

  for (final entity in componentsRoot.listSync()) {
    if (entity is! Directory) continue;
    final folder = basename(entity.path);
    if (folders.isNotEmpty && !folders.contains(folder)) continue;
    if (!File(join(entity.path, 't_$folder.dart')).existsSync()) continue;

    final className = _folderToMainClassName(folder);
    final relFile = 'lib/src/components/$folder/t_$folder.dart';
    await SmartCreator(
      isFileMode: true,
      onlyApi: true,
      nameList: [className],
      basePath: base,
      path: relFile,
      output: 'example/assets/api/',
      folderName: folder,
      commandInfo: CommandInfo()
        ..file = relFile
        ..folderName = folder
        ..widgetNames = className
        ..isOnlyApi = true,
    ).run();
    count++;
  }
  print('${DateTime.now().toLocal()}  完成，共 $count 个组件');
}

String _folderToMainClassName(String folder) {
  final camel = folder.split('_').map((s) {
    if (s.isEmpty) return s;
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }).join();
  return 'T$camel';
}
