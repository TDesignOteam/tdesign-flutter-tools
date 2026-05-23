import 'dart:io';

import 'package:path/path.dart' as p;

/// tdesign-component 根目录。
/// CI 通过环境变量 `TDESIGN_COMPONENT_ROOT` 注入；本地默认可用 ../tdesign-flutter/tdesign-component。
String get tdesignComponentRoot {
  final String? fromEnv = Platform.environment['TDESIGN_COMPONENT_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return p.normalize(fromEnv);
  }

  final List<String> candidates = <String>[
    p.normalize(
      p.join(Directory.current.path, '../tdesign-flutter/tdesign-component'),
    ),
  ];
  for (final String candidate in candidates) {
    if (Directory(candidate).existsSync()) {
      return candidate;
    }
  }

  throw StateError(
    '未找到 tdesign-component。请 clone tdesign-flutter 或设置 TDESIGN_COMPONENT_ROOT。',
  );
}

String componentSourcePath(String relativePath) {
  return p.join(tdesignComponentRoot, relativePath);
}
