import 'dart:io';

import 'package:path/path.dart' as p;

String fixtureSourcePath(String fileName) {
  return p.normalize(p.join(Directory.current.path, 'test', 'fixtures', fileName));
}
