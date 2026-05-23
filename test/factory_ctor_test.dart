import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:test/test.dart';

const String _componentRoot =
    '/Users/rs/Documents/cursor/tdesign-flutter/tdesign-component';

List<ParsedComponentInfoInfo> _analyse(List<String> names, String relPath) {
  final path = '$_componentRoot/$relPath';
  final col = AnalysisContextCollection(
    includedPaths: [path],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );
  final parsed =
      col.contextFor(path).currentSession.getParsedUnit(path) as ParsedUnitResult;
  return ComponentRule(
    parsedUnitResult: parsed,
    isGrammarParser: false,
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
}
