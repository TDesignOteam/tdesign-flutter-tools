#!/usr/bin/env dart
// cross_platform_verify.dart
// 跨平台 CI 验证脚本：修改 pubspec.yaml 和 all_build.sh，然后执行 all_build.sh
// 用法: dart run cross_platform_verify.dart <tdesign-flutter-repo-path> <api-tool-path>

import 'dart:io';

void main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run cross_platform_verify.dart <tdesign-flutter-path> <api-tool-path>');
    exit(1);
  }

  final repoPath = args[0];
  final apiToolPath = args[1];

  // 1. 修改 pubspec.yaml：把 git 依赖改为 path 依赖，删除 ref 行
  final pubspecFile = File('$repoPath/tdesign-component/pubspec.yaml');
  final content = pubspecFile.readAsStringSync();

  String newContent = content
      .replaceFirst(
        RegExp(r"url: https://github\.com/TDesignOteam/tdesign-flutter-tools\.git"),
        'path: ${Directory.current.path}',
      )
      .split('\n')
      .where((line) => !line.trim().startsWith('ref:'))
      .join('\n');

  pubspecFile.writeAsStringSync(newContent);
  print('pubspec.yaml updated');

  // 2. 修改 all_build.sh：把 dart run 改为直接调用二进制（加 ./ 前缀确保能找到）
  final allBuildFile = File('$repoPath/tdesign-component/demo_tool/all_build.sh');
  final scriptContent = allBuildFile.readAsStringSync();
  final replaced = scriptContent.replaceAll(
    'dart run tdesign_flutter_tools:main',
    './$apiToolPath',
  );
  allBuildFile.writeAsStringSync(replaced);
  print('all_build.sh updated');

  // 3. 执行 all_build.sh
  print('Running all_build.sh...');
  final result = await Process.run(
    'sh',
    ['all_build.sh'],
    workingDirectory: '$repoPath/tdesign-component/demo_tool',
  );

  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exit(result.exitCode);
}