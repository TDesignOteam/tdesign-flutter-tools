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

void main() {
  test('string default values keep quotes', () {
    final list = _analyse(
      ['TPickerKeys'],
      'lib/src/components/picker/t_picker_keys.dart',
    );
    final ParsedComponentInfoInfo info = list.first;
    final PropertyInfo label =
        info.propertyList.firstWhere((PropertyInfo p) => p.name == 'label');
    final PropertyInfo children =
        info.propertyList.firstWhere((PropertyInfo p) => p.name == 'children');

    expect(label.defaultValue, "'label'");
    expect(children.defaultValue, "'children'");
  });
}
