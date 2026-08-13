import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tdesign_flutter_tools/model.dart';
import 'package:tdesign_flutter_tools/smart_create.dart';
import 'package:test/test.dart';

/// 验证 folder 模式下 `_collectSourceFiles()` 对文件列表进行排序，
/// 确保生成的 *_api.md 中类型顺序固定、可复现，不依赖 `Directory.listSync()`
/// 返回的目录顺序（该顺序跨环境/文件系统不保证稳定）。
void main() {
  test('folder mode parses files in sorted (deterministic) order', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'tdesign_folder_order_',
    );
    try {
      // 故意以“与字母序相反”的顺序创建文件，验证工具仍按字母序处理。
      final File zFile = File(p.join(tempDir.path, 'z_widget_file.dart'));
      final File aFile = File(p.join(tempDir.path, 'a_widget_file.dart'));
      await zFile.writeAsString(
        'class ZWidget {}\ntypedef ZTypedef = void Function();\n',
      );
      await aFile.writeAsString(
        'class AWidget {}\ntypedef ATypedef = void Function();\n',
      );

      final SmartCreator creator = SmartCreator(
        isFileMode: false,
        onlyApi: true,
        nameList: <String>['AWidget', 'ZWidget'],
        basePath: tempDir.path,
        path: '',
        folderName: 'order',
      );

      final List<ParsedComponentInfoInfo> parsed =
          await creator.parseOnly(quiet: true);

      final List<String> names = parsed
          .map((ParsedComponentInfoInfo e) => e.componentInfo!.name!)
          .where((String n) => n != null && n.isNotEmpty)
          .toList();

      // 两个目标类都出现，且字母序文件（a 在 z 之前）先生成。
      expect(names, containsAll(<String>['AWidget', 'ZWidget']));
      expect(names.indexOf('AWidget'), lessThan(names.indexOf('ZWidget')));
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
