import 'dart:async';
import 'dart:convert';
import 'dart:io';
// import 'dart:math';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:ansicolor/ansicolor.dart';
import 'package:path/path.dart';
import 'package:analyzer/dart/analysis/results.dart';

import 'api_markdown.dart';
import 'component_rule.dart';
import 'model.dart';
import 'util.dart';

// ignore_for_file: always_specify_types
class SmartCreator {
  SmartCreator({
    this.nameList,
    this.path,
    this.commandInfo,
    this.basePath,
    this.folderName,
    this.output,
    this.isFileMode,
    this.onlyApi = false,
  });

  final String? path; //文件相对路径
  final List<String>? nameList; //组件名称
  final String? basePath;
  final String? folderName; // 文件夹名称
  final String? output; // 输出文件夹名称
  final bool? isFileMode; // 是否是单文件模式
  final bool? onlyApi;
  final CommandInfo? commandInfo;

  Future<void> run() async {
    final List<String> files = _collectSourceFiles();
    if (files.isEmpty)
      throw ArgumentError('No Dart sources found: ${join(basePath!, path)}');
    int startTime = DateTime.now().microsecondsSinceEpoch;
    // print('${DateTime.now().toLocal()}  AnalysisContextCollection');]
    var sb = StringBuffer();
    files.forEach((element) {
      sb.write("path:$element   \n");
    });
    // try to detect Dart SDK robustly (async): prefer env, flutter cache, 'where'/'which', then walk up from resolvedExecutable
    String? sdkPath = await _detectSdkPath();
    if (sdkPath != null && sdkPath.isNotEmpty) {
      AnsiPen pen = AnsiPen()..green(bold: true);
      print(pen('Detected Dart SDK: $sdkPath'));
    } else {
      AnsiPen pen = AnsiPen()..yellow(bold: true);
      print(
        pen(
          'Warning: Could not auto-detect Dart SDK. Analyzer may fail in compiled binary.',
        ),
      );
    }

    // If sdkPath is not found, omit sdkPath and let the analyzer attempt default discovery (may fail for compiled exe).
    AnalysisContextCollection analysisContextCollection =
        (sdkPath != null && sdkPath.isNotEmpty)
            ? AnalysisContextCollection(
              includedPaths: files,
              excludedPaths: [],
              resourceProvider: PhysicalResourceProvider.INSTANCE,
              sdkPath: sdkPath,
            )
            : AnalysisContextCollection(
              includedPaths: files,
              excludedPaths: [],
              resourceProvider: PhysicalResourceProvider.INSTANCE,
            );
    return analyseFile(analysisContextCollection, files, startTime);
  }

  /// 仅解析源码（不写入 md），供完备性检测等场景复用与 generate 相同的 AST 规则。
  Future<List<ParsedComponentInfoInfo>> parseOnly({bool quiet = false}) async {
    final List<String> files = _collectSourceFiles();
    if (files.isEmpty) {
      return <ParsedComponentInfoInfo>[];
    }
    final int startTime = DateTime.now().microsecondsSinceEpoch;
    if (!quiet) {
      final String? sdkPath = await _detectSdkPath();
      if (sdkPath != null && sdkPath.isNotEmpty) {
        AnsiPen pen = AnsiPen()..green(bold: true);
        print(pen('Detected Dart SDK: $sdkPath'));
      }
    }
    final String? sdkPath = await _detectSdkPath();
    final AnalysisContextCollection analysisContextCollection =
        (sdkPath != null && sdkPath.isNotEmpty)
            ? AnalysisContextCollection(
              includedPaths: files,
              excludedPaths: [],
              resourceProvider: PhysicalResourceProvider.INSTANCE,
              sdkPath: sdkPath,
            )
            : AnalysisContextCollection(
              includedPaths: files,
              excludedPaths: [],
              resourceProvider: PhysicalResourceProvider.INSTANCE,
            );
    return _parseComponents(
      analysisContextCollection,
      files,
      startTime,
      quiet: quiet,
    );
  }

  List<String> _collectSourceFiles() {
    final List<String> files = <String>[];
    if (isFileMode!) {
      String filePath = join(basePath!, path);
      filePath = normalize(filePath);
      if (File(filePath).existsSync()) {
        files.add(filePath);
      }
    } else {
      final String fullPath = normalize(join(basePath!, path));
      final Directory comDir = Directory(fullPath);
      if (comDir.existsSync()) {
        for (final FileSystemEntity item in comDir.listSync(
          recursive: true,
          followLinks: false,
        )) {
          if (item is File && item.path.endsWith('.dart')) {
            files.add(item.path);
          }
        }
        // Directory.listSync() 不保证目录顺序，跨环境/文件系统可能返回不同顺序，
        // 导致生成的 *_api.md 中类型顺序不稳定（git 中反复出现 M 变更）。
        // 排序保证输出内容固定、可复现。
        files.sort();
      }
    }
    return files;
  }

  // Attempt to detect Dart SDK path using multiple strategies:
  // 1) DART_SDK env
  // 2) FLUTTER_ROOT/FLUTTER_HOME -> bin/cache/dart-sdk
  // 3) run 'where dart' (Windows) or 'which dart' (posix) and inspect parent dirs
  // 4) walk up from Platform.resolvedExecutable looking for 'lib/_internal'
  Future<String?> _detectSdkPath() async {
    // 1) env
    String? sdkPath = Platform.environment['DART_SDK'];
    if (sdkPath != null && sdkPath.isNotEmpty) {
      return normalize(sdkPath);
    }

    // 2) flutter env
    final flutterRoot =
        Platform.environment['FLUTTER_ROOT'] ??
        Platform.environment['FLUTTER_HOME'];
    if (flutterRoot != null && flutterRoot.isNotEmpty) {
      final candidate = normalize(
        join(flutterRoot, 'bin', 'cache', 'dart-sdk'),
      );
      if (Directory(candidate).existsSync()) return candidate;
    }

    // 3) find 'dart' executable using platform tools
    try {
      if (Platform.isWindows) {
        var result = await Process.run('where.exe', ['dart']);
        if (result.exitCode == 0) {
          final stdoutStr = result.stdout.toString();
          final lines = stdoutStr.trim().split(RegExp(r"\r?\n"));
          if (lines.isNotEmpty) {
            final dartExe = lines.first.trim();
            final binDir = dirname(dartExe);
            final parent = dirname(binDir);
            // check for flutter cached sdk
            final flutterCache = normalize(
              join(parent, 'bin', 'cache', 'dart-sdk'),
            );
            if (Directory(flutterCache).existsSync()) return flutterCache;
            // check for lib/_internal
            final internal = normalize(join(parent, 'lib', '_internal'));
            if (Directory(internal).existsSync()) return parent;
            return parent;
          }
        }
      } else {
        var result = await Process.run('which', ['dart']);
        if (result.exitCode == 0) {
          final dartExe = result.stdout.toString().trim();
          if (dartExe.isNotEmpty) {
            final binDir = dirname(dartExe);
            final parent = dirname(binDir);
            final internal = normalize(join(parent, 'lib', '_internal'));
            if (Directory(internal).existsSync()) return parent;
            return parent;
          }
        }
      }
    } catch (e) {
      // ignore failures
    }

    // 4) walk up from resolvedExecutable
    try {
      String exec = Platform.resolvedExecutable;
      String dir = normalize(dirname(exec));
      for (int i = 0; i < 8; i++) {
        final candidate = normalize(join(dir, 'lib', '_internal'));
        if (Directory(candidate).existsSync()) {
          return normalize(dirname(candidate));
        }
        final parent = dirname(dir);
        if (parent == dir) break;
        dir = parent;
      }
    } catch (e) {
      // ignore
    }

    return null;
  }

  Future<List<ParsedComponentInfoInfo>> _parseComponents(
    AnalysisContextCollection analysisContextCollection,
    List<String> paths,
    int startTime, {
    bool quiet = false,
  }) async {
    final List<ParsedComponentInfoInfo> parsedComponentInfoList =
        <ParsedComponentInfoInfo>[];
    for (final String filePath in paths) {
      if (!quiet) {
        print('\n\n${DateTime.now().toLocal()}  开始分析 ${basename(filePath)}');
      }
      final String normalizedPath = normalize(filePath);
      final result = await analysisContextCollection
          .contextFor(normalizedPath)
          .currentSession
          .getParsedUnit(normalizedPath);
      final unit = result as ParsedUnitResult?;
      final ComponentRule issuesInFile = ComponentRule(
        parsedUnitResult: unit,
        nameList: nameList,
        basePath: basePath,
        folderName: folderName,
        startTime: startTime,
        sourceFileName: basename(filePath),
      );
      if (!quiet) {
        final int endTime = DateTime.now().microsecondsSinceEpoch;
        print('AST分析执行用时: ${((endTime - startTime) / 1000).floor()}ms');
      }
      parsedComponentInfoList.addAll(issuesInFile.analyse());
    }
    reportDuplicateAuxiliaryDefinitions(parsedComponentInfoList);

    int kindOrder(ParsedComponentInfoInfo info) {
      switch (info.componentInfo?.kind) {
        case 'function':
          return 0;
        case 'enum':
          return 1;
        case 'typedef':
          return 2;
        default:
          return 0;
      }
    }

    parsedComponentInfoList.sort((
      ParsedComponentInfoInfo a,
      ParsedComponentInfoInfo b,
    ) {
      final int kindCmp = kindOrder(a).compareTo(kindOrder(b));
      if (kindCmp != 0) {
        return kindCmp;
      }
      int indexA = nameList!.indexOf(a.componentInfo!.name!);
      int indexB = nameList!.indexOf(b.componentInfo!.name!);
      if (indexA == -1) indexA = nameList!.length;
      if (indexB == -1) indexB = nameList!.length;
      return indexA.compareTo(indexB);
    });
    return parsedComponentInfoList;
  }

  Future<void> analyseFile(
    AnalysisContextCollection analysisContextCollection,
    List<String> paths,
    int startTime,
  ) async {
    final List<ParsedComponentInfoInfo> parsedComponentInfoList =
        await _parseComponents(analysisContextCollection, paths, startTime);
    await generateApiInfoFile(parsedComponentInfoList);
    if (!onlyApi! && parsedComponentInfoList.isNotEmpty) {
      await generateBaseInfoFile(
        parsedComponentInfoList.first.componentInfo!,
        commandInfo!,
      );
      await generateDemoFile(parsedComponentInfoList.first.componentInfo);
      await copyCoverFile(parsedComponentInfoList.first.componentInfo);
    }
    print('全部生成完毕, 共 ${parsedComponentInfoList.length} 个');
    // print('${parsedComponentInfoList.map((e) => e.componentInfo.name).toList().join(",")}');
  }

  // 生成 api 信息文件
  Future<void> generateApiInfoFile(
    List<ParsedComponentInfoInfo> parsedComponentInfoList,
  ) async {
    int startTime = DateTime.now().microsecondsSinceEpoch;
    String? destName = CamelToUnderline(nameList!.first);
    if (folderName != null && folderName!.isNotEmpty) {
      destName = folderName;
    }
    String relativePath = getRelativePath(destName);
    String path = join(basePath!, relativePath);
    File file = File(path);
    await file.create(recursive: false);
    final markdown = renderApiMarkdown(
      parsedComponentInfoList,
      names: nameList!,
      strictNames: commandInfo?.strictNames ?? false,
      includeIntroduction: commandInfo?.isGetComments ?? false,
    );
    await file.writeAsString(markdown, encoding: utf8);
    int endTime = DateTime.now().microsecondsSinceEpoch;
    AnsiPen pen = AnsiPen()..green(bold: true);
    print(
      pen(
        '$relativePath 生成完毕!  用时: ${((endTime - startTime) / 1000).floor()}ms',
      ),
    );
  }

  // 生成基本信息文件
  Future<void> generateBaseInfoFile(
    ComponentInfo componentInfo,
    CommandInfo commandInfo,
  ) async {
    int startTime = DateTime.now().microsecondsSinceEpoch;
    String? destName = getDestFolderName(componentInfo);
    String relativePath = getWidgetDirPath(destName);
    String path = join(basePath!, relativePath);
    Directory comDir = Directory(path);
    if (!comDir.existsSync()) {
      await Directory(path).create(recursive: true);
    }
    File file = File(join(path, '$destName.md'));
    file.createSync(recursive: false);
    StringBuffer sb = StringBuffer();
    if (commandInfo.file != null) {
      sb.write('file: ${commandInfo.file}\n');
    }
    if (commandInfo.folder != null) {
      sb.write('folder: ${commandInfo.folder}\n');
    }
    if (commandInfo.folderName != null) {
      sb.write('folderName: ${commandInfo.folderName}\n');
    }
    if (commandInfo.isOnlyApi) {
      sb.write('isOnlyApi: ${commandInfo.isOnlyApi}\n');
    }
    sb.write('widgetNames: ${commandInfo.widgetNames}');

    String fileContent = '''
---
group: 未分类
name: ${nameList!.first}
subtitle:
owner: unspecified
${sb.toString()}
---
## 介绍
${componentInfo.introduction}
''';
    await file.writeAsString(fileContent, encoding: utf8);
    int endTime = DateTime.now().microsecondsSinceEpoch;
    AnsiPen pen = AnsiPen()..green(bold: true);
    print(
      pen(
        '${join(relativePath, '$destName.md')} 生成完毕!  用时: ${((endTime - startTime) / 1000).floor()}ms',
      ),
    );
  }

  // 生成 demo 示例文件
  Future<void> generateDemoFile(ComponentInfo? componentInfo) async {
    int startTime = DateTime.now().microsecondsSinceEpoch;
    String? destName = getDestFolderName(componentInfo);
    String relativePath = getWidgetDirPath(destName);
    String path = join(basePath!, relativePath);
    Directory comDir = Directory(path);
    if (!comDir.existsSync()) {
      await Directory(path).create(recursive: true);
    }
    File file = File(join(path, 'demo1.dart'));
    if (!file.existsSync()) {
      file.createSync(recursive: false);
      String fileContent = '''
import 'package:flutter/material.dart';
import 'package:ui_component_example/model/model.dart';

@Priority(1)
@DemoItemStyle(ItemStyle.sideBySide)
class ${componentInfo!.name}Demo1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text('请完善demo示例');
  }
}
''';
      await file.writeAsString(fileContent, encoding: utf8);
      int endTime = DateTime.now().microsecondsSinceEpoch;
      AnsiPen pen = AnsiPen()..green(bold: true);
      print(
        pen(
          '${join(relativePath, 'demo1.dart')} 生成完毕!  用时: ${((endTime - startTime) / 1000).floor()}ms',
        ),
      );
    }
  }

  // 拷贝默认的组件封面图
  Future<void> copyCoverFile(ComponentInfo? componentInfo) async {
    String? destName = getDestFolderName(componentInfo);
    String relativePath = getWidgetDirPath(destName);
    String path = join(basePath!, relativePath);
    Directory comDir = Directory(path);
    if (!comDir.existsSync()) {
      await Directory(path).create(recursive: true);
    }
    // TODO:暂时不需要封面
    // File fileTmp = File(join(path, '$destName.png'));
    // if (!fileTmp.existsSync()) {
    //   File file = File(join(basePath!, 'tools/smart_cli/template/cover.png'));
    //   await file.copy(join(path, '$destName.png'));
    //   int endTime = DateTime.now().microsecondsSinceEpoch;
    //   AnsiPen pen = AnsiPen()..green(bold: true);
    //   print(pen('${join(relativePath, '$destName.png')} 封面图初始化完毕!  用时: ${((endTime - startTime) / 1000).floor()}ms'));
    // }
  }

  String? getDestFolderName(ComponentInfo? componentInfo) {
    String? destName = CamelToUnderline(nameList!.first);
    if (folderName != null && folderName!.isNotEmpty) {
      destName = folderName;
    }
    return destName;
  }

  // 指定目标地址
  String getRelativePath(String? destName) =>
      '${output ?? 'example/assets/api/'}${destName}_api.md';

  // 指定widget生成地址
  String getWidgetDirPath(String? destName) =>
      '${output ?? 'example/lib/api/widget_group/'}$destName';
}
