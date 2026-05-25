import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:test/test.dart';

import 'support/component_paths.dart';

List<ParsedComponentInfoInfo> _analyse(List<String> names, String relPath) {
  final String path = componentSourcePath(relPath);
  final col = AnalysisContextCollection(
    includedPaths: [path],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );
  final parsed =
      col.contextFor(path).currentSession.getParsedUnit(path) as ParsedUnitResult;
  return ComponentRule(
    parsedUnitResult: parsed,
    nameList: names,
    sourceFileName: relPath.split('/').last,
  ).analyse();
}

PropertyInfo? _factoryParam(
  ParsedComponentInfoInfo info,
  String factoryName,
  String paramName,
) {
  final StaticMethodInfo method = info.componentInfo!.constructorMethodList
      .firstWhere((StaticMethodInfo m) => m.name == factoryName);
  for (final PropertyInfo param in method.params) {
    if (param.name == paramName) {
      return param;
    }
  }
  return null;
}

void main() {
  test('TAlertDialog.vertical factory params get types from fieldMap', () {
    final list = _analyse(
      ['TAlertDialog'],
      'lib/src/components/dialog/t_alert_dialog.dart',
    );
    final info = list.first;
    final backgroundColor = _factoryParam(info, 'vertical', 'backgroundColor');
    final title = _factoryParam(info, 'vertical', 'title');
    expect(backgroundColor, isNotNull);
    expect(backgroundColor!.type, 'Color?');
    expect(title, isNotNull);
    expect(title!.type, 'String?');
  });

  test('key gets fallback introduction when source has no comment', () {
    final list = _analyse(
      ['TAlertDialog'],
      'lib/src/components/dialog/t_alert_dialog.dart',
    );
    final info = list.first;
    final key = info.propertyList.firstWhere((PropertyInfo p) => p.name == 'key');
    final factoryKey = _factoryParam(info, 'vertical', 'key');

    expect(key.introduction, '组件标识，用于区分或保留组件状态。');
    expect(factoryKey, isNotNull);
    expect(factoryKey!.introduction, '组件标识，用于区分或保留组件状态。');
  });
}
