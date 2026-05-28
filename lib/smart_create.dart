import 'dart:async';
import 'dart:convert';
import 'dart:io';
// import 'dart:math';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:ansicolor/ansicolor.dart';
import 'package:path/path.dart';
import 'package:analyzer/dart/analysis/results.dart';

import 'component_rule.dart';
import 'documentation.dart';
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
    this.isGrammarParser = false,
  });

  final String? path; //文件相对路径
  final List<String>? nameList; //组件名称
  final String? basePath;
  final String? folderName; // 文件夹名称
  final String? output; // 输出文件夹名称
  final bool? isFileMode; // 是否是单文件模式
  final bool? onlyApi;
  final bool? isGrammarParser; //是否使用语法分析器
  final CommandInfo? commandInfo;

  Future<void> run() async {
    List<String> files = <String>[];
    if (isFileMode!) {
      String filePath = join(basePath!, path);
      filePath = normalize(filePath);
      files.add(filePath);
      File file = File(files[0]);
      if (!file.existsSync()) {
        AnsiPen pen = AnsiPen()..red(bold: true);
        print(pen('源文件路径不对: ${files[0]}'));
        return;
      }
    } else {
      String fullPath = join(basePath!, path);
      fullPath = normalize(fullPath);
      Directory comDir = Directory(fullPath);
      if (comDir.existsSync()) {
        List<FileSystemEntity> filesInDir = comDir.listSync();
        for (final item in filesInDir) {
          files.add(item.path);
        }
      } else {
        AnsiPen pen = AnsiPen()..red(bold: true);
        print(pen('输入的文件夹路径不对: $fullPath'));
      }
    }
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
        for (final FileSystemEntity item in comDir.listSync()) {
          if (item.path.endsWith('.dart')) {
            files.add(item.path);
          }
        }
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
      ParsedUnitResult? unit;
      ResolvedUnitResult? unit2;
      if (isGrammarParser!) {
        final result = await analysisContextCollection
            .contextFor(normalizedPath)
            .currentSession
            .getResolvedUnit(normalizedPath);
        unit2 = result as ResolvedUnitResult?;
      } else {
        final result = analysisContextCollection
            .contextFor(normalizedPath)
            .currentSession
            .getParsedUnit(normalizedPath);
        unit = result as ParsedUnitResult?;
      }
      final ComponentRule issuesInFile = ComponentRule(
        parsedUnitResult: unit,
        resolvedUnitResult: unit2,
        isGrammarParser: isGrammarParser,
        nameList: nameList,
        basePath: basePath,
        folderName: folderName,
        startTime: startTime,
        sourceFileName: basename(filePath),
      );
      if (!quiet) {
        final int endTime = DateTime.now().microsecondsSinceEpoch;
        print(
          '${isGrammarParser! ? "语法分析" : "词法分析"}执行用时: ${((endTime - startTime) / 1000).floor()}ms',
        );
      }
      parsedComponentInfoList.addAll(issuesInFile.analyse());
    }
    reportDuplicateAuxiliaryDefinitions(parsedComponentInfoList);

    int kindOrder(ParsedComponentInfoInfo info) {
      switch (info.componentInfo?.kind) {
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
    String fileContent = '''
## API
''';
    StringBuffer sb = StringBuffer(fileContent);
    for (final apiInfo in parsedComponentInfoList) {
      if (parsedComponentInfoList.indexOf(apiInfo) >= 1) {
        sb.write('\n\n');
      }
      sb.write('### ${apiInfo.componentInfo!.name}');
      final introduction = apiInfo.componentInfo!.introduction ?? '';
      final String introForSummary =
          stripExampleSectionForIntroduction(introduction);
      final String kind = apiInfo.componentInfo?.kind ?? 'class';

      if (kind == 'enum') {
        if (introForSummary.isNotEmpty) {
          sb.write('\n#### 简介\n');
          sb.write(introForSummary);
        }
        final List<EnumMemberInfo> enumMembers =
            apiInfo.componentInfo!.enumMembers;
        final bool isSimpleEnum = apiInfo.componentInfo!.isSimpleEnum;
        if (enumMembers.isNotEmpty) {
          sb.write('\n#### 枚举值\n');
          if (isSimpleEnum) {
            sb.write('''\n
| 名称 |
| --- |\n''');
            for (final EnumMemberInfo member in enumMembers) {
              sb.write('| ${sanitizeTableCell(member.name)} |\n');
            }
          } else {
            sb.write('''\n
| 名称 | 说明 |
| --- | --- |\n''');
            for (final EnumMemberInfo member in enumMembers) {
              final String doc =
                  member.introduction.isEmpty ? '-' : member.introduction;
              sb.write(
                '| ${sanitizeTableCell(member.name)} | ${sanitizeTableCell(doc)} |\n',
              );
            }
          }
        } else if (apiInfo.componentInfo!.enumValues.isNotEmpty) {
          sb.write('\n#### 枚举值\n');
          if (isSimpleEnum) {
            sb.write('''\n
| 名称 |
| --- |\n''');
            for (final String value in apiInfo.componentInfo!.enumValues) {
              sb.write('| ${sanitizeTableCell(value)} |\n');
            }
          } else {
            sb.write('''\n
| 名称 | 说明 |
| --- | --- |\n''');
            for (final String value in apiInfo.componentInfo!.enumValues) {
              sb.write('| ${sanitizeTableCell(value)} | - |\n');
            }
          }
        }
        continue;
      }

      if (kind == 'typedef') {
        if (introForSummary.isNotEmpty) {
          sb.write('\n#### 简介\n');
          sb.write(introForSummary);
        }
        if (apiInfo.componentInfo!.typedefDefinition.isNotEmpty) {
          sb.write('\n#### 类型定义\n\n');
          sb.write(
            '```dart\n${apiInfo.componentInfo!.typedefDefinition}\n```\n',
          );
        }
        continue;
      }

      if (introForSummary.isNotEmpty) {
        sb.write('\n#### 简介\n');
        sb.write(introForSummary);
      }
      StaticMethodInfo? currentMethod;

      void writePropertyTable(
        List<PropertyInfo> items, {
        required String header,
        String nameColumn = '参数',
      }) {
        if (items.isEmpty) {
          return;
        }
        sb.write('\n#### $header');
        sb.write('''\n
| $nameColumn | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |\n''');
        for (final PropertyInfo item in items) {
          sb.write(
            '''| ${sanitizeTableCell(item.name)} | ${sanitizeTableCell(item.type.isEmpty ? '-' : item.type)} | ${sanitizeTableCell(item.defaultValue)} | ${sanitizeTableCell(item.introduction.isEmpty ? '-' : item.introduction)} |\n''',
          );
        }
      }

      PropertyInfo? resolveForwardedParamInfo(
        StaticMethodInfo method,
        PropertyInfo param,
      ) {
        final String? targetName = method.forwardedTargetName;
        final String? targetParamName = method.forwardedParamMap[param.name];
        if (targetName == null ||
            targetName.isEmpty ||
            targetParamName == null ||
            targetParamName.isEmpty) {
          return null;
        }
        ParsedComponentInfoInfo? targetInfo;
        for (final ParsedComponentInfoInfo item in parsedComponentInfoList) {
          if (item.componentInfo?.kind == 'class' &&
              item.componentInfo?.name == targetName) {
            targetInfo = item;
            break;
          }
        }
        if (targetInfo == null) {
          return null;
        }
        final String? constructorName = method.forwardedConstructorName;
        if (constructorName != null && constructorName.isNotEmpty) {
          for (final StaticMethodInfo ctor
              in targetInfo.componentInfo!.constructorMethodList) {
            if (ctor.name != constructorName) {
              continue;
            }
            for (final PropertyInfo item in ctor.params) {
              if (item.name == targetParamName) {
                return item;
              }
            }
            return null;
          }
          return null;
        }
        for (final PropertyInfo item in targetInfo.propertyList) {
          if (item.name == targetParamName) {
            return item;
          }
        }
        return targetInfo.fieldMap[targetParamName];
      }

      void writeMethodParamTable(List<PropertyInfo> params) {
        if (params.isEmpty) {
          return;
        }
        sb.write('''\n
| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |\n''');
        for (final PropertyInfo param in params) {
          PropertyInfo? forwardedParam;
          if (currentMethod != null) {
            forwardedParam = resolveForwardedParamInfo(currentMethod!, param);
          }
          final String type =
              ((param.type.isEmpty || param.type == '-') &&
                      forwardedParam != null &&
                      forwardedParam.type.isNotEmpty &&
                      forwardedParam.type != '-')
                  ? forwardedParam.type
                  : param.type;
          final String introduction =
              param.introduction.isEmpty && forwardedParam != null
                  ? forwardedParam.introduction
                  : param.introduction;
          sb.write(
            '''| ${sanitizeTableCell(param.name)} | ${sanitizeTableCell(type.isEmpty ? '-' : type)} | ${sanitizeTableCell(param.defaultValue)} | ${sanitizeTableCell(introduction.isEmpty ? '-' : introduction)} |\n''',
          );
        }
      }

      void writeMethodDetails(
        List<StaticMethodInfo> methods, {
        required String header,
        bool includeReturnType = false,
        bool compactCommonForwardedParams = false,
      }) {
        if (methods.isEmpty) {
          return;
        }
        sb.write('\n\n#### $header');
        methods.sort(
          (StaticMethodInfo a, StaticMethodInfo b) =>
              a.name!.toLowerCase().compareTo(b.name!.toLowerCase()),
        );
        final Set<String> commonForwardedParams = <String>{};
        if (compactCommonForwardedParams && methods.length > 1) {
          Set<String>? common;
          for (final StaticMethodInfo method in methods) {
            final bool hasForwardedInfo =
                method.forwardedTargetName == apiInfo.componentInfo!.name &&
                (method.forwardedConstructorName == null ||
                    method.forwardedConstructorName!.isEmpty);
            if (!hasForwardedInfo) {
              common = <String>{};
              break;
            }
            final Set<String> forwardedCurrent =
                method.params
                    .where(
                      (PropertyInfo param) =>
                          method.forwardedParamMap[param.name] == param.name,
                    )
                    .map((PropertyInfo p) => p.name)
                    .toSet();
            common = common == null
                ? forwardedCurrent
                : common.intersection(forwardedCurrent);
            if (common.isEmpty) {
              break;
            }
          }
          if (common != null && common.isNotEmpty) {
            commonForwardedParams.addAll(common);
            final List<PropertyInfo> commonParamRows = methods.first.params
                .where((PropertyInfo param) => commonForwardedParams.contains(param.name))
                .toList()
              ..sort(
                (PropertyInfo a, PropertyInfo b) => a.name
                    .toLowerCase()
                    .compareTo(b.name.toLowerCase()),
              );
            currentMethod = methods.first;
            sb.write('\n\n##### 通用参数');
            sb.write('\n\n以下参数由各命名工厂统一透传，含义一致：');
            writeMethodParamTable(commonParamRows);
          }
        }
        for (final StaticMethodInfo item in methods) {
          currentMethod = item;
          sb.write(
            '\n\n##### ${apiInfo.componentInfo!.name}.${sanitizeTableCell(item.name)}',
          );
          if (item.introduction != null && item.introduction!.isNotEmpty) {
            sb.write('\n\n${item.introduction}');
          }
          final String returnType =
              item.returnType == 'null' ? '' : (item.returnType ?? '');
          if (includeReturnType && returnType.isNotEmpty) {
            sb.write('\n\n返回类型：`$returnType`');
          }
          final List<PropertyInfo> params = commonForwardedParams.isEmpty
              ? item.params
              : item.params
                    .where(
                      (PropertyInfo param) =>
                          !commonForwardedParams.contains(param.name),
                    )
                    .toList();
          if (commonForwardedParams.isNotEmpty) {
            sb.write('\n\n其余参数见「通用参数」。');
          }
          writeMethodParamTable(params);
        }
        currentMethod = null;
      }

      // 对外 API 优先：命令式入口 → 命名工厂 → 默认构造 → 字段/成员 → 实例方法
      if (apiInfo.componentInfo?.staticMethodList.isNotEmpty ?? false) {
        writeMethodDetails(
          apiInfo.componentInfo!.staticMethodList,
          header: '静态方法',
          includeReturnType: true,
        );
      }
      final List<StaticMethodInfo> publicNamedConstructors =
          apiInfo.componentInfo!.constructorMethodList
              .where(
                (StaticMethodInfo method) =>
                    !isLibraryPrivateNamedConstructor(method.name),
              )
              .toList();
      if (publicNamedConstructors.isNotEmpty) {
        writeMethodDetails(
          publicNamedConstructors,
          header: '工厂构造方法',
          compactCommonForwardedParams: true,
        );
      }
      if (apiInfo.propertyList.isNotEmpty) {
        // 用 fieldMap 补全构造参数缺失的类型和说明
        for (final PropertyInfo element in apiInfo.propertyList) {
          final PropertyInfo? field = apiInfo.fieldMap[element.name];
          if (field == null) {
            continue;
          }
          if (element.type.isEmpty || element.type == '-') {
            element.type = field.type.isNotEmpty ? field.type : element.type;
          }
          if (element.introduction.isEmpty) {
            element.introduction = field.introduction;
          }
        }
        writePropertyTable(apiInfo.propertyList, header: '默认构造方法');
      }
      writePropertyTable(
        apiInfo.extraPropertyList,
        header: '公开属性',
        nameColumn: '属性',
      );
      writePropertyTable(
        apiInfo.staticMemberList,
        header: '静态成员',
        nameColumn: '名称',
      );
      if (apiInfo.componentInfo?.instanceMethodList.isNotEmpty ?? false) {
        sb.write("\n\n");
        sb.write("#### 方法");
        sb.write('''\n
| 名称 | 返回类型 | 参数 | 说明 |
| --- | --- | --- | --- |\n''');
        for (final item in apiInfo.componentInfo!.instanceMethodList) {
          final returnType =
              item.returnType == "null" ? "" : (item.returnType ?? "");
          sb.write(
            '| ${sanitizeTableCell(item.name)} | ${sanitizeTableCell(returnType)} | ${sanitizeTableCell(formatMethodParams(item.params))} | ${sanitizeTableCell(item.introduction == null || item.introduction!.isEmpty ? '-' : item.introduction)} |\n',
          );
        }
      }
    }
    await file.writeAsString(sb.toString(), encoding: utf8);
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
    if (commandInfo.isUseGrammar) {
      sb.write('isUseGrammar: ${commandInfo.isUseGrammar}\n');
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
