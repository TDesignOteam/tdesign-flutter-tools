import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:tdesign_flutter_tools/smart_create.dart';
import 'package:tdesign_flutter_tools/smart_update.dart';

// ignore_for_file: always_specify_types
class CreateCommand extends Command {
  @override
  String name = 'generate';

  @override
  String description = 'Create component demo files.';

  CreateCommand() {
    // [argParser] is automatically created by the parent class.
    argParser.addOption('file', help: '相对ui_component目录的组件文件路径');
    argParser.addOption('folder', help: '相对ui_component目录的组件文件夹路径');
    argParser.addOption('name', help: '组件名，多个组件名之间用英文,分割');
    argParser.addOption('folder-name', help: '[可选]生成的组件示例文件夹名称,默认文件夹名称是第一项name的下划线表示');
    argParser.addOption('output', help: '文件输出路径');
    argParser.addFlag('only-api', defaultsTo: false, help: '是否只生成api文件');
    argParser.addFlag('use-grammar', defaultsTo: false, help: '是否采用语法分析器,默认采用词法分析');
    argParser.addFlag('get-comments', defaultsTo: false, help: '是否获取类的注释');
  }

  CommandInfo getCommandInfo() {
    CommandInfo commandInfo = CommandInfo();
    String? path = argResults!['file'];
    String? folderName = argResults!['folder-name'];
    commandInfo.file = path;
    if (argResults!['folder'] != null) {
      path = argResults!['folder'];
      commandInfo.folder = path;
    }
    commandInfo.folderName = folderName;
    commandInfo.output = argResults!['output'];
    bool onlyApi = argResults!['only-api'] ?? false;
    commandInfo.isOnlyApi = onlyApi;
    bool isGrammarParser = argResults!['use-grammar'] ?? false;
    commandInfo.isUseGrammar = isGrammarParser;
    commandInfo.widgetNames = argResults!['name'].toString();
    commandInfo.isGetComments = argResults!['get-comments'] ?? false;
    return commandInfo;
  }

  // [run] may also return a Future.
  @override
  void run() async {
    // [argResults] is set before [run()] is called and contains the options
    // passed to this command.
    // print('path=${argResults['path']}');
    // print('name=${argResults['name']}');
    String? path = argResults!['file'];
    String? folderName = argResults!['folder-name'];
    bool isFileMode = true;
    if (argResults!['folder'] != null) {
      path = argResults!['folder'];
      isFileMode = false;
    }
    bool? onlyApi = argResults!['only-api'];
    bool? isGrammarParser = argResults!['use-grammar'];
    print('${DateTime.now().toLocal()}  ${argResults!['name']} 正在生成组件文档...');
    // print('原始命令：${getCommandInfo()}');
    SmartCreator creator = SmartCreator(
        isFileMode: isFileMode,
        // isMerge: isMerge,
        onlyApi: onlyApi,
        nameList: argResults!['name'].toString().split(','),
        basePath: '${Directory.current.path}/',
        path: path,
        output: argResults!['output'],
        isGrammarParser: isGrammarParser,
        commandInfo: getCommandInfo(),
        folderName: folderName);
    await creator.run();
  }
}

class UpdateCommand extends Command {
  @override
  String name = 'update';

  @override
  String description = 'Update component demo files.';

  UpdateCommand() {
    // [argParser] is automatically created by the parent class.
    argParser.addOption('folder-name', help: '[可选]需要更新的组件示例文件夹名称,默认全量更新');
  }

  // [run] may also return a Future.
  @override
  void run() async {
    // [argResults] is set before [run()] is called and contains the options
    // passed to this command.
    List<String> folderNameList = [];
    if (argResults!['folder-name'] != null) {
      String folderName = argResults!['folder-name'];
      folderNameList = folderName.split(',');
    }
    print('${DateTime.now().toLocal()}  正在更新组件示例... ${folderNameList.join("|")}');
    SmartUpdater creator = SmartUpdater(
      basePath: '${Directory.current.path}/',
      folderNameList: folderNameList,
    );
    await creator.run();
  }
}

void main(List<String> arguments) {
  // generate --file lib/src/components/text/td_text.dart --name TDText --folder-name text --only-api
  // arguments = [
  //   'generate',
  //   '--file',
  //   '/Users/x/WorkSpace/flutter/tdesign_group/tdesign-flutter/demo_tool/../lib/src/components/text/td_text.dart',
  //   '--name',
  //   'TDTextSpan',
  //   '--folder-name',
  //   'text',
  //   '--output',
  //   '/Users/x/WorkSpace/flutter/tdesign_group/tdesign-flutter/demo_tool/../example/assets/api/',
  //   '--only-api',
  //   '--get-comments'
  // ];
  // arguments = [
  //   'generate',
  //   '--file',
  //   '/Users/x/WorkSpace/flutter/tdesign_group/tdesign-flutter/demo_tool/../lib/src/components/toast/td_toast.dart',
  //   '--name',
  //   'TDToast',
  //   '--folder-name',
  //   'toast',
  //   '--output',
  //   '/Users/x/WorkSpace/flutter/tdesign_group/tdesign-flutter/demo_tool/../example/assets/api/',
  //   '--only-api',
  //   '--get-comments'
  // ];
  // arguments = [
  //   'generate',
  //   '--folder',
  //   '/Users/x/WorkSpace/flutter/tdesign_group/tdesign-mobile-flutter/tdesign-component/demo_tool/../lib/src/components/tag',
  //   '--name',
  //   'TDTagStyle',
  //   '--folder-name',
  //   'tag',
  //   '--output',
  //   '/Users/x/WorkSpace/flutter/tdesign_group/tdesign-mobile-flutter/tdesign-component/demo_tool/../example/assets/api2/',
  //   '--only-api'
  // ];

  // generate
  // --folder
  // ../lib/src/components/tag
  // --name
  // TDTag,TDSelectTag,TDTagStyle
  // --folder-name
  // tag
  // --output
  // ../example/assets/api/
  // --only-api

  StringBuffer sb = StringBuffer();
  sb.writeln("命令行参数:");
  arguments.forEach((element) {
    sb.writeln(element);
  });
  print(sb);

  CommandRunner('demo', 'Tencent AI Education Component Tools.')
    ..addCommand(CreateCommand())
    ..addCommand(UpdateCommand())
    ..run(arguments);
}
