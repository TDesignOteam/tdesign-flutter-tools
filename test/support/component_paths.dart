import 'dart:io';

import 'package:path/path.dart' as p;

/// tdesign-component 根目录。
/// CI 通过环境变量 `TDESIGN_COMPONENT_ROOT` 注入；本地优先使用 ../tdesign-flutter-v1/tdesign-component。
String get tdesignComponentRoot {
  final String? fromEnv = Platform.environment['TDESIGN_COMPONENT_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return p.normalize(fromEnv);
  }

  final List<String> candidates = <String>[
    p.normalize(
      p.join(Directory.current.path, '../tdesign-flutter-v1/tdesign-component'),
    ),
    p.normalize(p.join(Directory.current.path, '../tdesign-component')),
  ];
  for (final String candidate in candidates) {
    if (Directory(candidate).existsSync()) {
      return candidate;
    }
  }

  throw StateError(
    '未找到 tdesign-component。请设置 TDESIGN_COMPONENT_ROOT 或放置 ../tdesign-flutter-v1/tdesign-component。',
  );
}

String componentSourcePath(String relativePath) {
  return p.join(tdesignComponentRoot, relativePath);
}
