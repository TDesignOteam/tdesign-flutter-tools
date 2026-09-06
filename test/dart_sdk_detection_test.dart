import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tdesign_flutter_tools/src/dart_sdk_detector.dart';

void main() {
  test('detects the cached Dart SDK behind a Flutter or FVM wrapper', () async {
    final Directory fixture = Directory.systemTemp.createTempSync(
      'tdesign_tools_sdk_detection_',
    );
    addTearDown(() => fixture.deleteSync(recursive: true));

    final String flutterRoot = p.join(fixture.path, 'flutter');
    final String dartSdk = p.join(flutterRoot, 'bin', 'cache', 'dart-sdk');
    Directory(p.join(dartSdk, 'lib', '_internal')).createSync(recursive: true);

    final DartSdkDetector detector = DartSdkDetector(
      environment: <String, String>{},
      processRunner: (String executable, List<String> arguments) async {
        return ProcessResult(
          1,
          0,
          '${p.join(flutterRoot, 'bin', 'dart')}\n',
          '',
        );
      },
      resolvedExecutable: p.join(fixture.path, 'invalid', 'dart'),
    );

    expect(await detector.detect(), dartSdk);
  });

  test(
    'ignores an invalid configured SDK and falls back to which dart',
    () async {
      final Directory fixture = Directory.systemTemp.createTempSync(
        'tdesign_tools_sdk_fallback_',
      );
      addTearDown(() => fixture.deleteSync(recursive: true));

      final String dartSdk = p.join(fixture.path, 'dart-sdk');
      Directory(
        p.join(dartSdk, 'lib', '_internal'),
      ).createSync(recursive: true);

      final DartSdkDetector detector = DartSdkDetector(
        environment: <String, String>{
          'DART_SDK': p.join(fixture.path, 'missing'),
        },
        processRunner: (String executable, List<String> arguments) async {
          return ProcessResult(2, 0, p.join(dartSdk, 'bin', 'dart'), '');
        },
        resolvedExecutable: p.join(fixture.path, 'invalid', 'dart'),
      );

      expect(await detector.detect(), dartSdk);
    },
  );
}
