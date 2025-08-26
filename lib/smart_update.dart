import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:ansicolor/ansicolor.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:dart_style/dart_style.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart';
// import 'package:smart_cli/smart_create.dart';

import 'demo_rule.dart';
import 'model.dart';
import 'smart_create.dart';
import 'util.dart';

// ignore_for_file: always_specify_types
class SmartUpdater {
  SmartUpdater({
    this.basePath,
    this.folderNameList = const [],
  });

  final String? basePath; // ui_component 目录的路径
  final List<String> folderNameList;

  Future<void> run() async {
    String groupPath = join(basePath!, 'example/lib/widget_group');
    Directory groupDir = Directory(groupPath);
    List<FileSystemEntity> groupFiles = groupDir.listSync();
    ComponentConfig componentConfig = ComponentConfig();
    for (final comDir in groupFiles) {
      if (folderNameList.length > 0 && !folderNameList.contains(comDir.path.split('/').last)) {
        continue;
      }
      if (comDir is Directory) {
        List<String> demoFiles = <String>[];
        List<FileSystemEntity> files = comDir.listSync();
        for (final item in files) {
          String filename = basename(item.path);
          if (isValidDemoFile(filename)) {
            demoFiles.add(item.path);
          }
        }
        ComponentInfo componentInfo = await getComponentInfo(comDir.path);
        int startTime = DateTime.now().microsecondsSinceEpoch;
        if (demoFiles.isNotEmpty) {
          AnalysisContextCollection analysisContextCollection = AnalysisContextCollection(
            includedPaths: demoFiles,
            excludedPaths: [],
            resourceProvider: PhysicalResourceProvider.INSTANCE,
          );
          List<DemoInfo> demoList = await analyseFile(analysisContextCollection, demoFiles, startTime, comDir.path);
          await migrateComFiles(comDir.path);
          await migrateDemoCodeFile(demoList);
          componentInfo.demoList!.addAll(demoList);
          //根据优先级排序
          componentInfo.demoList!.sort((DemoInfo a, DemoInfo b) {
            return a.priority! > b.priority! ? 1 : 0;
          });
        }
        if (componentInfo.commandInfo != null && componentInfo.commandInfo!.isValid()) {
          bool isFileMode = componentInfo.commandInfo!.isFileMode();
          // AnsiPen pen = AnsiPen()..red(bold: true);
          // print(pen('更新api: ${componentInfo.commandInfo!.getCommand()}'));
          // print(pen('信息：${componentInfo.commandInfo!.toString()}'));
          SmartCreator creator = SmartCreator(
              isFileMode: isFileMode,
              onlyApi: true,
              nameList: componentInfo.commandInfo!.widgetNames!.split(','),
              basePath: basePath,
              path: isFileMode ? componentInfo.commandInfo!.file : componentInfo.commandInfo!.folder,
              isGrammarParser: false,
              folderName: componentInfo.commandInfo!.folderName);
          await creator.run();
        }
        if (componentInfo.name!.isNotEmpty) {
          int endTime = DateTime.now().microsecondsSinceEpoch;
          AnsiPen pen = AnsiPen()..green(bold: true);
          print(pen(
              '更新组件信息 ${componentInfo.name}: 示例 ${componentInfo.demoList!.map((e) => e.name).toList().join("|")}   用时: ${((endTime - startTime) / 1000).floor()}ms'));
          componentConfig.componentList!.add(componentInfo);
        }
      }
    }
    await updateRegisterFile(componentConfig);
  }

  Future<List<DemoInfo>> analyseFile(AnalysisContextCollection analysisContextCollection, List<String> paths, int startTime, String comDirPath) async {
    // AnsiPen pen = AnsiPen()..green(bold: true);
    // print(pen('analyseFile：$comDirPath'));

    List<DemoInfo> demoList = [];
    for (final String filePath in paths) {
      String normalizedPath = normalize(filePath);
      // 在新版本的analyzer中，getParsedUnit方法返回的是SomeParsedUnitResult
      var result = analysisContextCollection.contextFor(normalizedPath).currentSession.getParsedUnit(normalizedPath);
      // 将SomeParsedUnitResult转换为ParsedUnitResult
      ParsedUnitResult unit = result as ParsedUnitResult;
      DemoRule issuesInFile = DemoRule(analysisResult: unit, basePath: basePath, filePath: filePath);
      DemoInfo demoInfo = issuesInFile.analyse();
      demoInfo.fileName = basename(filePath);
      if (demoInfo.isValid) {
        demoInfo.filePath = filePath;
        DemoInfo? doubleDemoInfo = demoList.firstWhereOrNull((element) => element.name == demoInfo.name);
        // print('demoList=${demoList.length}, ${demoInfo.name}');
        if (doubleDemoInfo != null) {
          AnsiPen pen = AnsiPen()..red(bold: true);
          String folderName = comDirPath.split('/').last;
          print(pen('组件示例类名重复：$folderName/${demoInfo.fileName}  ${demoInfo.name}'));
        } else if (demoInfo.name!.isNotEmpty) {
          demoList.add(demoInfo);
        }
      }
    }
    int endTime = DateTime.now().microsecondsSinceEpoch;
    Debug('${comDirPath.split("/").last} 组件示例分析完毕 ${demoList.map((e) => e.name).toList().join(" | ")}  用时: ${((endTime - startTime) / 1000).floor()}ms');
    // for (final item in demoList) {
    //   print('$item');
    // }
    return demoList;
  }

// 迁移demo的code文件
  Future<void> migrateDemoCodeFile(List<DemoInfo> demoList) async {
    int startTime = DateTime.now().microsecondsSinceEpoch;
    for (final demoInfo in demoList) {
      String destName = CamelToUnderline(demoInfo.name!);
      String fullPath = join(basePath!, 'example/assets/code/$destName.code');
      File file = File(demoInfo.filePath);
      List<String> lines = await file.readAsLines();
      List<String> linesNew = [];
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('@Priority') || lines[i].contains('@DemoItemStyle') || lines[i].contains('///')) {
          continue;
        } else {
          linesNew.add(lines[i]);
        }
      }
      File destFile = File(fullPath);
      await destFile.writeAsString(linesNew.join('\n'));
      int endTime = DateTime.now().microsecondsSinceEpoch;
      Debug('${demoInfo.name} 示例代码迁移成功！ 用时: ${((endTime - startTime) / 1000).floor()}ms');
    }
  }

  // 迁移组件文件
  Future<void> migrateComFiles(String comDirPath) async {
    int startTime = DateTime.now().microsecondsSinceEpoch;
    Directory comDir = Directory(comDirPath);
    List<FileSystemEntity> files = comDir.listSync();
    for (final item in files) {
      String filename = basename(item.path);
      if (filename.endsWith('.md')) {
        // 迁移组件介绍
        File comMarkdownFile = item as File;
        String relativePath = 'example/assets/doc/$filename';
        await comMarkdownFile.copy(join(basePath!, relativePath));
        Debug('$relativePath 组件介绍文档更新成功');
      } else if (filename.endsWith('.png')) {
        // 迁移组件封面图
        File comPreviewFile = item as File;
        String relativePath = 'example/assets/preview/$filename';
        await comPreviewFile.copy(join(basePath!, relativePath));
        Debug('$relativePath 组件封面图更新成功');
      }
    }
    int endTime = DateTime.now().microsecondsSinceEpoch;
    Debug('组件文档迁移完毕! 用时: ${((endTime - startTime) / 1000).floor()}ms');
  }

  Future<ComponentInfo> getComponentInfo(String comDirPath) async {
    ComponentInfo componentInfo = ComponentInfo();
    componentInfo.folderName = comDirPath.split('/').last;
    Directory comDir = Directory(comDirPath);
    List<FileSystemEntity> filesInDir = comDir.listSync();
    for (final markdownFile in filesInDir) {
      if (!markdownFile.path.endsWith('.md')) {
        continue;
      }
      File configFile = markdownFile as File;
      String markdown = await configFile.readAsString();
      var document = md.Document(
          encodeHtml: false,
          extensionSet: md.ExtensionSet(
            md.ExtensionSet.gitHubWeb.blockSyntaxes,
            [md.EmojiSyntax(), ...md.ExtensionSet.gitHubWeb.inlineSyntaxes],
          ));
      final List<String> lines = LineSplitter().convert(markdown);
      final List<md.Node> astNodes = document.parseLines(lines);
      bool nextIntroduction = false;
      for (final item in astNodes) {
        // print('*****\n\n[${astNodes.indexOf(item) + 1}/${astNodes.length}][${item.runtimeType}] ${item.textContent}');
        if (item is md.Element) {
          int cLen = item.children?.length ?? 0;
          // print('\nid= ${item.generatedId}, ${item.tag}, ${item.attributes}, ${item.children?.length ?? 0}');
          if (item.tag == 'h2' && item.textContent.contains('介绍')) {
            nextIntroduction = true;
            // print('准备解析 介绍');
            continue;
          }
          if (cLen > 0) {
            final cItem = item.children!.first;
            // print('\n子节点[${item.children.indexOf(cItem) + 1}/$cLen][${cItem.runtimeType}] ${cItem.textContent}');
            if (cItem is md.Text) {
              if (cItem.text.contains('group') && cItem.text.contains('name') && cItem.text.contains('subtitle') && cItem.text.contains('owner')) {
                List<String> values = cItem.text.split('\n');
                String group = '';
                String name = '';
                String subtitle = '';
                String owner = '';
                CommandInfo commandInfo = CommandInfo();
                for (final val in values) {
                  if (val.startsWith('group')) {
                    group = val.replaceAll('group:', '').trim();
                  }
                  if (val.startsWith('name')) {
                    name = val.replaceAll('name:', '').trim();
                  }
                  if (val.startsWith('subtitle')) {
                    subtitle = val.replaceAll('subtitle:', '').trim();
                  }
                  if (val.startsWith('owner')) {
                    owner = val.replaceAll('owner:', '').trim();
                  }
                  if (val.startsWith('file')) {
                    commandInfo.file = val.replaceAll('file:', '').trim();
                  }
                  if (val.startsWith('folderName')) {
                    commandInfo.folderName = val.replaceAll('folderName:', '').trim();
                  } else if (val.startsWith('folder')) {
                    commandInfo.folder = val.replaceAll('folder:', '').trim();
                  }
                  if (val.startsWith('widgetNames')) {
                    commandInfo.widgetNames = val.replaceAll('widgetNames:', '').trim();
                  }
                }
                // print('$name | $group | $subtitle | $owner');
                componentInfo.owner = owner;
                componentInfo.name = name;
                componentInfo.group = group;
                componentInfo.subtitle = subtitle;
                componentInfo.commandInfo = commandInfo;
              }
              if (nextIntroduction) {
                nextIntroduction = false;
                componentInfo.introduction = cItem.text;
                // print('introduction=$introduction');
                break;
              }
            }
          }
        }
      }
      break;
    }
    return componentInfo;
  }

  //更新注册表
  Future<void> updateRegisterFile(ComponentConfig componentConfig) async {
    List<String> importList = [];
    List<String> componentGroupList = [];
    Set<String?> displayGroupList = componentConfig.componentList!.map((e) => e.group).toSet();
    Debug('全部分类：$displayGroupList');
    for (final groupType in displayGroupList) {
      List<String> componentInfoList = [];
      if (componentConfig.componentList!.isNotEmpty) {
        List<ComponentInfo> comList = componentConfig.componentList?.where((element) => element.group == groupType).toList() ?? [];
        for (final com in comList) {
          List<String> demoWidgetItemInfoList = [];
          for (final demo in com.demoList!) {
            String importText = '''
            import 'package:ui_component_example/widget_group/${demo.getParentDirName()}/${demo.fileName}';
            ''';
            importList.add(importText);
            List<String> introductionsInfoList = [];
            for (final introduction in demo.introductions) {
              String introductionText = '''
            '$introduction',
            ''';
              introductionsInfoList.add(introductionText);
            }
            String demoWidgetItemInfoText = '''
                DemoWidgetItemInfo(codeFileName: '${CamelToUnderline(demo.name!)}.code', child: ${demo.name}(), style: ItemStyle.{demo.displayStyle}, introductions: [${introductionsInfoList.join('\n')}]),
                ''';
            demoWidgetItemInfoList.add(demoWidgetItemInfoText);
          }
          String componentInfoText = '''      
          ComponentInfo(
            name: '${com.name} ${com.subtitle}',
            owner: '${com.owner}',
            folderName: '${com.folderName}',
            routePath: '${CamelToUnderline(com.name!)}',
            introduction: '${com.introduction}',
            demoWidgetList: [
              ${demoWidgetItemInfoList.join('\n')}
            ],
          ),
          ''';
          componentInfoList.add(componentInfoText);
        }
      }
      String componentInfoText = '''
      ComponentGroupInfo(
        groupTitle: '$groupType',
        children: [
          ${componentInfoList.join('\n')}
        ],
      ),
      ''';
      componentGroupList.add(componentInfoText);
    }

    String registerPath = join(basePath!, 'example/lib/config/register_component.dart');
    File registerFile = File(registerPath);
    registerFile.createSync(recursive: false);
    String fileContent = '''
    // **************************************************************************
    // 本文件是自动生成的 - 请勿手工编辑
    // **************************************************************************
    import 'package:ui_component_example/model/model.dart';
    ${importList.join('')}
    
    List<ComponentGroupInfo> componentGroupList = [
    ${componentGroupList.join('\n')}
    ];
    ''';
    final dartFormatter = DartFormatter();
    await registerFile.writeAsString(dartFormatter.format(fileContent));
    // print('$name 组件示例注册成功');
  }
}
