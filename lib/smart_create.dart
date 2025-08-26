import 'dart:async';
import 'dart:io';
// import 'dart:math';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:ansicolor/ansicolor.dart';
import 'package:path/path.dart';
import 'package:analyzer/dart/analysis/results.dart';

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
    this.isMerge = false,
    this.onlyApi = false,
    this.isGrammarParser = false,
  });

  final String? path; //文件相对路径
  final List<String>? nameList; //组件名称
  final String? basePath;
  final String? folderName; // 文件夹名称
  final String? output; // 输出文件夹名称
  final bool? isFileMode; // 是否是单文件模式
  final bool isMerge; // 是否合并在一个文件夹中
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
    AnalysisContextCollection analysisContextCollection = AnalysisContextCollection(
      includedPaths: files,
      excludedPaths: [],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );
    return analyseFile(analysisContextCollection, files, startTime);
  }

  Future<void> analyseFile(AnalysisContextCollection analysisContextCollection, List<String> paths, int startTime) async {
    // print('${DateTime.now().toLocal()}  analyseFile');
    List<ParsedComponentInfoInfo> parsedComponentInfoList = [];
    for (final String filePath in paths) {
      print('\n\n${DateTime.now().toLocal()}  开始分析 ${basename(filePath)}');
      String normalizedPath = normalize(filePath);
      ParsedUnitResult? unit;
      ResolvedUnitResult? unit2;
      if (isGrammarParser!) {
        // 在新版本的analyzer中，getResolvedUnit方法返回的是SomeResolvedUnitResult
        var result = await analysisContextCollection.contextFor(normalizedPath).currentSession.getResolvedUnit(normalizedPath);
        // 将SomeResolvedUnitResult转换为ResolvedUnitResult
        unit2 = result as ResolvedUnitResult?;
      } else {
        // 在新版本的analyzer中，getParsedUnit方法返回的是SomeParsedUnitResult
        var result = analysisContextCollection.contextFor(normalizedPath).currentSession.getParsedUnit(normalizedPath);
        // 将SomeParsedUnitResult转换为ParsedUnitResult
        unit = result as ParsedUnitResult?;
      }
      ComponentRule issuesInFile = ComponentRule(
        parsedUnitResult: unit,
        resolvedUnitResult: unit2,
        isGrammarParser: isGrammarParser,
        nameList: nameList,
        basePath: basePath,
        folderName: folderName,
        startTime: startTime,
        isMerge: isMerge,
        sourceFileName: basename(filePath),
      );
      int endTime = DateTime.now().microsecondsSinceEpoch;
      print('${isGrammarParser! ? "语法分析" : "词法分析"}执行用时: ${((endTime - startTime) / 1000).floor()}ms');
      // print('${DateTime.now().toLocal()}  开始解析 ${basename(filePath)}');

      List<ParsedComponentInfoInfo> items = issuesInFile.analyse();
      parsedComponentInfoList.addAll(items);
    }
    await generateApiInfoFile(parsedComponentInfoList);
    if (!onlyApi! && parsedComponentInfoList.isNotEmpty) {
      await generateBaseInfoFile(parsedComponentInfoList.first.componentInfo!, commandInfo!);
      await generateDemoFile(parsedComponentInfoList.first.componentInfo);
      await copyCoverFile(parsedComponentInfoList.first.componentInfo);
    }
    print('全部生成完毕, 共 ${parsedComponentInfoList.length} 个');
    // print('${parsedComponentInfoList.map((e) => e.componentInfo.name).toList().join(",")}');
  }

  // 生成 api 信息文件
  Future<void> generateApiInfoFile(List<ParsedComponentInfoInfo> parsedComponentInfoList) async {
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
## API''';
    StringBuffer sb = StringBuffer(fileContent);
    for (final apiInfo in parsedComponentInfoList) {
      if (parsedComponentInfoList.length > 0) {
        sb.write('\n');
        if (parsedComponentInfoList.indexOf(apiInfo) >= 1) {
          sb.write('''```\n```\n ''');
        }
        sb.write('### ${apiInfo.componentInfo!.name}');
        if (commandInfo?.isGetComments ?? false) {
          sb.write('\n#### 简介\n');
          sb.write('${apiInfo.componentInfo!.introduction}');
        }
      }
      if (apiInfo.propertyList.isNotEmpty) {

        // 填充introduction
        apiInfo.propertyList.forEach((element) {
          if(element.introduction.isEmpty){
            element.type = apiInfo.fieldMap[element.name]?.type ?? '';
            element.introduction = apiInfo.fieldMap[element.name]?.introduction ?? '';
          }
        });
        sb.write('\n#### 默认构造方法');
        sb.write('''\n
| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |\n''');
        for (final item in apiInfo.propertyList) {
          sb.write('''| ${item.name} | ${item.type} | ${item.defaultValue} | ${item.introduction} |\n''');
        }
      }
      if(apiInfo.componentInfo?.constructorMethodList.isNotEmpty ?? false){
        sb.write("\n\n");
        sb.write("#### 工厂构造方法");
        sb.write('''\n
| 名称  | 说明 |
| --- |  --- |\n''');
        // 按照方法名称的首字母排序
        apiInfo.componentInfo!.constructorMethodList.sort((a, b) => a.name!.toLowerCase().compareTo(b.name!.toLowerCase()));
        for (final item in apiInfo.componentInfo!.constructorMethodList) {
          sb.write('''| ${apiInfo.componentInfo!.name}.${item.name}  | ${item.introduction} |\n''');
        }
      }
      if(apiInfo.componentInfo?.staticMethodList.isNotEmpty ?? false){
        sb.write("\n\n");
        sb.write("#### 静态方法");
        sb.write('''\n
| 名称 | 返回类型 | 参数 | 说明 |
| --- | --- | --- | --- |\n''');
        // 按照方法名称的首字母排序
        apiInfo.componentInfo!.staticMethodList.sort((a, b) => a.name!.toLowerCase().compareTo(b.name!.toLowerCase()));
        for (final item in apiInfo.componentInfo!.staticMethodList) {
          StringBuffer paramsSb = StringBuffer();
          item.params.forEach((element) {
            paramsSb.write("  ${element.isRequired ? "required " : ""}${element.type} ${element.name},");
          });
          sb.write('''| ${item.name} | ${item.returnType == "null" ? "" : item.returnType} | ${paramsSb.toString()} | ${item.introduction?.replaceAll("\n", "  ")} |\n''');
        }
      }
    }
    await file.writeAsString(sb.toString());
    int endTime = DateTime.now().microsecondsSinceEpoch;
    AnsiPen pen = AnsiPen()..green(bold: true);
    print(pen('$relativePath 生成完毕!  用时: ${((endTime - startTime) / 1000).floor()}ms'));
  }

  // 生成基本信息文件
  Future<void> generateBaseInfoFile(ComponentInfo componentInfo, CommandInfo commandInfo) async {
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
    await file.writeAsString(fileContent);
    int endTime = DateTime.now().microsecondsSinceEpoch;
    AnsiPen pen = AnsiPen()..green(bold: true);
    print(pen('${join(relativePath, '$destName.md')} 生成完毕!  用时: ${((endTime - startTime) / 1000).floor()}ms'));
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
      await file.writeAsString(fileContent);
      int endTime = DateTime.now().microsecondsSinceEpoch;
      AnsiPen pen = AnsiPen()..green(bold: true);
      print(pen('${join(relativePath, 'demo1.dart')} 生成完毕!  用时: ${((endTime - startTime) / 1000).floor()}ms'));
    }
  }

  // 拷贝默认的组件封面图
  Future<void> copyCoverFile(ComponentInfo? componentInfo) async {
    int startTime = DateTime.now().microsecondsSinceEpoch;
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
  String getRelativePath(String? destName) => '${output ?? 'example/assets/api/'}${destName}_api.md';

// 指定widget生成地址
  String getWidgetDirPath(String? destName) => '${output ?? 'example/lib/api/widget_group/'}$destName';
}