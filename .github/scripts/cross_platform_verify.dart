#!/usr/bin/env dart
/// CI 验证脚本：验证编译后的二进制产物能正确执行 generate 命令
/// 用法: dart run .github/scripts/cross_platform_verify.dart <tdesign-flutter-path> <binary-path>
import 'dart:io';

void main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run cross_platform_verify.dart <tdesign-flutter-path> <binary-path>');
    exit(1);
  }

  final repoPath = args[0];
  final binaryPath = args[1];
  final cwd = Directory.current.path;
  final binaryAbsPath = File('$cwd/$binaryPath').absolute.path;
  final componentDir = '$cwd/$repoPath/tdesign-component';

  print('Binary: $binaryAbsPath');
  print('Repo:   $componentDir');

  // 验证二进制文件存在
  if (!File(binaryAbsPath).existsSync()) {
    print('ERROR: Binary not found: $binaryAbsPath');
    exit(1);
  }

  // 用一个真实的 dart 文件测试 generate 命令
  final testFile = '$componentDir/lib/src/components/button/t_button.dart';
  if (!File(testFile).existsSync()) {
    print('ERROR: Test file not found: $testFile');
    exit(1);
  }

  final outputDir = '$componentDir/example/assets/api/';
  Directory(outputDir).createSync(recursive: true);

  print('\nRunning: $binaryAbsPath generate ...');
  final result = await Process.run(binaryAbsPath, [
    'generate',
    '--file', testFile,
    '--name', 'TButton',
    '--folder-name', 'button',
    '--output', outputDir,
    '--only-api',
  ]);

  stdout.write(result.stdout);
  stderr.write(result.stderr);

  if (result.exitCode != 0) {
    print('\nERROR: Binary verification failed (exit code ${result.exitCode})');
    exit(result.exitCode);
  }

  // 验证输出文件生成
  final outputFile = File('${outputDir}button_api.md');
  if (outputFile.existsSync()) {
    print('\nSUCCESS: button_api.md generated (${outputFile.lengthSync()} bytes)');
  } else {
    print('\nERROR: Expected output file not found: ${outputFile.path}');
    exit(1);
  }
}
