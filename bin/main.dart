import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:tdesign_flutter_tools/api_completeness.dart';
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
    argParser.addFlag(
      'get-comments',
      defaultsTo: false,
      help: '输出类的 #### 简介（剥离 **示例** 与代码块）；不加则仅生成参数表等结构',
    );
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

class ValidateCommand extends Command {
  @override
  String name = 'validate';

  @override
  String description =
      '校验 API 文档完备性（使用 analyzer AST，与 generate 同一套解析规则）。';

  ValidateCommand() {
    argParser.addOption(
      'component-root',
      help: 'tdesign-component 根目录路径',
      defaultsTo: '../tdesign-flutter/tdesign-component',
    );
    argParser.addOption(
      'config',
      help: '审计清单 YAML/JSON 路径',
      defaultsTo: '.github/config/tdesign_api.yaml',
    );
    argParser.addMultiOption(
      'components',
      help: '仅检测指定组件，如 button,picker（默认 5 组件全量）',
    );
    argParser.addFlag('verbose', abbr: 'v', help: '打印 analyzer 解析过程');
  }

  @override
  Future<void> run() async {
    final String raw = argResults!['component-root'] as String;
    final String componentRoot = p.isAbsolute(raw)
        ? p.normalize(raw)
        : p.normalize(p.join(Directory.current.path, raw));
    if (!Directory(componentRoot).existsSync()) {
      stderr.writeln('ERROR: component 目录不存在: $componentRoot');
      exitCode = 1;
      return;
    }

    final String configRaw = argResults!['config'] as String;
    final String configPath = p.isAbsolute(configRaw)
        ? p.normalize(configRaw)
        : p.normalize(p.join(Directory.current.path, configRaw));

    List<ComponentAuditConfig> configs;
    try {
      configs = await loadAuditConfigsFromFile(configPath);
    } catch (e) {
      stderr.writeln('ERROR: 无法加载配置 $configPath: $e');
      exitCode = 2;
      return;
    }

    final List<String> only =
        argResults!['components'] as List<String>? ?? <String>[];
    if (only.isNotEmpty) {
      final Set<String> wanted = only.toSet();
      configs = configs
          .where((ComponentAuditConfig c) => wanted.contains(c.componentKey))
          .toList();
    }

    final int errors = await runCompletenessAudit(
      componentRoot: componentRoot,
      configs: configs,
      quiet: !(argResults!['verbose'] as bool? ?? false),
    );
    if (errors > 0) {
      exitCode = 1;
    }
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
  if (Platform.environment['CI'] != 'true') {
    final sb = StringBuffer('命令行参数:\n');
    for (final arg in arguments) {
      sb.writeln(arg);
    }
    print(sb);
  }

  CommandRunner('tdesign_flutter_tools', 'TDesign Flutter component documentation tools.')
    ..addCommand(CreateCommand())
    ..addCommand(ValidateCommand())
    ..addCommand(UpdateCommand())
    ..run(arguments);
}
