import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;

AnalysisContextCollection testAnalysisContextCollection({
  required List<String> includedPaths,
}) {
  return AnalysisContextCollection(
    includedPaths: includedPaths,
    resourceProvider: PhysicalResourceProvider.INSTANCE,
    sdkPath: _dartSdkPath(),
  );
}

String _dartSdkPath() {
  final String? fromEnv = Platform.environment['DART_SDK'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return p.normalize(fromEnv);
  }

  final String executable = p.normalize(Platform.resolvedExecutable);
  final String executableDir = p.dirname(executable);
  final String executableParent = p.dirname(executableDir);
  if (File(p.join(executableParent, 'version')).existsSync() &&
      Directory(p.join(executableParent, 'lib', '_internal')).existsSync()) {
    return executableParent;
  }

  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    final String candidate = p.normalize(
      p.join(flutterRoot, 'bin', 'cache', 'dart-sdk'),
    );
    if (Directory(candidate).existsSync()) {
      return candidate;
    }
  }

  final String fvmCandidate = p.normalize(
    p.join(executableParent, 'cache', 'dart-sdk'),
  );
  if (Directory(fvmCandidate).existsSync()) {
    return fvmCandidate;
  }

  return executableParent;
}
