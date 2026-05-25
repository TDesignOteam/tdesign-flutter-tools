import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:test/test.dart';

import 'support/component_paths.dart';

List<dynamic> _analyse(List<String> names) {
  const String relPath = 'lib/src/components/popup/t_popup_panel.dart';
  final String path = componentSourcePath(relPath);
  final col = AnalysisContextCollection(
    includedPaths: [path],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );
  final parsed = col.contextFor(path).currentSession.getParsedUnit(path)
      as ParsedUnitResult;
  final rule = ComponentRule(
    parsedUnitResult: parsed,
    nameList: names,
    folderName: 'popup',
    sourceFileName: 't_popup_panel.dart',
  );
  return rule.analyse();
}

void main() {
  test('TPopupBasePanel ctor captures field defaults', () {
    final list = _analyse(['TPopupBasePanel']);
    final draggable =
        list.first.propertyList.firstWhere((p) => p.name == 'draggable');
    expect(draggable.defaultValue, 'false');
  });

  test('TPopupBottomDisplayPanel inherits super param defaults when base parsed first', () {
    final list = _analyse(['TPopupBasePanel', 'TPopupBottomDisplayPanel']);
    final panel = list.firstWhere((e) => e.componentInfo!.name == 'TPopupBottomDisplayPanel');
    final draggable =
        panel.propertyList.firstWhere((p) => p.name == 'draggable');
    expect(draggable.defaultValue, 'false');
  });

  test('TPopupBottomDisplayPanel inherits super param defaults', () {
    final list = _analyse(['TPopupBottomDisplayPanel']);
    expect(list, isNotEmpty);
    final props = list.first.propertyList;
    final draggable = props.firstWhere((p) => p.name == 'draggable');
    expect(draggable.type, 'bool');
    expect(draggable.defaultValue, 'false');
    final maxHeight = props.firstWhere((p) => p.name == 'maxHeightRatio');
    expect(maxHeight.defaultValue, '0.9');
  });
}
