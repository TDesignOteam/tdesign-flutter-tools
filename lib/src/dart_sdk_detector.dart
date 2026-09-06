import 'dart:io';

import 'package:path/path.dart' as p;

typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

/// Locates a structurally valid Dart SDK for analyzer contexts.
class DartSdkDetector {
  DartSdkDetector({
    Map<String, String>? environment,
    ProcessRunner? processRunner,
    String? resolvedExecutable,
  }) : _environment = environment ?? Platform.environment,
       _processRunner = processRunner ?? Process.run,
       _resolvedExecutable = resolvedExecutable ?? Platform.resolvedExecutable;

  final Map<String, String> _environment;
  final ProcessRunner _processRunner;
  final String _resolvedExecutable;

  Future<String?> detect() async {
    final String? configuredSdk = _environment['DART_SDK'];
    if (configuredSdk != null && configuredSdk.isNotEmpty) {
      final String? validSdk = _validSdkPath(configuredSdk);
      if (validSdk != null) return validSdk;
    }

    final String? flutterRoot =
        _environment['FLUTTER_ROOT'] ?? _environment['FLUTTER_HOME'];
    if (flutterRoot != null && flutterRoot.isNotEmpty) {
      final String? flutterSdk = _validSdkPath(
        p.join(flutterRoot, 'bin', 'cache', 'dart-sdk'),
      );
      if (flutterSdk != null) return flutterSdk;
    }

    try {
      final ProcessResult result = await _processRunner(
        Platform.isWindows ? 'where.exe' : 'which',
        <String>['dart'],
      );
      if (result.exitCode == 0) {
        final String output = result.stdout.toString().trim();
        final String dartExecutable = output.split(RegExp(r'\r?\n')).first;
        final String? sdk = _sdkFromDartExecutable(dartExecutable.trim());
        if (sdk != null) return sdk;
      }
    } on ProcessException {
      // Continue with the current process executable fallback.
    }

    return _sdkFromDartExecutable(_resolvedExecutable);
  }

  String? _sdkFromDartExecutable(String executable) {
    if (executable.isEmpty) return null;
    final String parent = p.dirname(p.dirname(executable));
    return _validSdkPath(p.join(parent, 'bin', 'cache', 'dart-sdk')) ??
        _validSdkPath(parent);
  }

  String? _validSdkPath(String path) {
    final String candidate = p.normalize(path);
    return Directory(p.join(candidate, 'lib', '_internal')).existsSync()
        ? candidate
        : null;
  }
}
