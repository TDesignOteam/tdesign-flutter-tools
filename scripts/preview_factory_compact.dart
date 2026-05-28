import 'dart:io';

import 'package:tdesign_flutter_tools/smart_create.dart';

Future<void> main() async {
  final Directory tempDir = await Directory.systemTemp.createTemp(
    'tdesign_factory_compact_preview_',
  );
  final File source = File('${tempDir.path}/demo_options.dart');
  await source.writeAsString('''
/// 用于预览 factory 参数合并输出的最小例子。
class DemoOptions {
  /// 默认构造：这里的字段注释将作为“通用参数”的说明来源。
  const DemoOptions({this.a, this.b, this.c});

  /// 通用参数 A
  final int? a;

  /// 通用参数 B
  final int? b;

  /// 仅 bottom 独有（由 onlyBottom 转发）
  final int? c;

  /// bottom 工厂：a/b 是通用，onlyBottom 仅此方向独有
  factory DemoOptions.bottom({int? a, int? b, int? onlyBottom}) =>
      DemoOptions(a: a, b: b, c: onlyBottom);

  /// top 工厂：只有 a/b
  factory DemoOptions.top({int? a, int? b}) => DemoOptions(a: a, b: b);
}
''');

  final Directory outDir = Directory('${tempDir.path}/out');
  await outDir.create(recursive: true);

  final SmartCreator creator = SmartCreator(
    isFileMode: true,
    onlyApi: true,
    nameList: const <String>['DemoOptions'],
    basePath: '${tempDir.path}/',
    path: 'demo_options.dart',
    folderName: 'demo',
    output: 'out/',
    isGrammarParser: false,
  );
  await creator.run();

  final File md = File('${outDir.path}/demo_api.md');
  if (!md.existsSync()) {
    stderr.writeln('ERROR: markdown not generated: ${md.path}');
    exitCode = 1;
    return;
  }
  stdout.writeln('Generated: ${md.path}');
  stdout.writeln(await md.readAsString());
}

