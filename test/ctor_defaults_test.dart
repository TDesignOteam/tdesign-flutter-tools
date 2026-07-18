import 'package:analyzer/dart/analysis/results.dart';
import 'package:path/path.dart' as p;
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:test/test.dart';

import 'support/analyzer_context.dart';
import 'support/component_paths.dart';
import 'support/fixture_paths.dart';

List<ParsedComponentInfoInfo> _analysePopupPart(
  List<String> names,
  String partFile,
) {
  const String relDir = 'lib/src/components/popup';
  final String popupDir = p.join(tdesignComponentRoot, relDir);
  final String path = p.join(popupDir, partFile);
  final col = testAnalysisContextCollection(includedPaths: [popupDir]);
  final parsed =
      col.contextFor(path).currentSession.getParsedUnit(path)
          as ParsedUnitResult;
  return ComponentRule(
    parsedUnitResult: parsed,
    nameList: names,
    folderName: 'popup',
    sourceFileName: partFile,
  ).analyse();
}

List<ParsedComponentInfoInfo> _analyseFixture(
  List<String> names,
  String fileName,
) {
  final String path = fixtureSourcePath(fileName);
  final col = testAnalysisContextCollection(includedPaths: [path]);
  final parsed =
      col.contextFor(path).currentSession.getParsedUnit(path)
          as ParsedUnitResult;
  return ComponentRule(
    parsedUnitResult: parsed,
    nameList: names,
    folderName: 'popup',
    sourceFileName: fileName,
  ).analyse();
}

void main() {
  test('TPopupOptions default ctor captures field defaults on develop', () {
    final list = _analysePopupPart(['TPopupOptions'], 't_popup_options.dart');
    final info = list.first;
    final showOverlay = info.propertyList.firstWhere(
      (PropertyInfo p) => p.name == 'showOverlay',
    );
    expect(showOverlay.defaultValue, 'true');
  });

  test('TPopupBasePanel ctor captures field defaults', () {
    final list = _analyseFixture([
      'TPopupBasePanel',
    ], 'popup_super_ctor_fixture.dart');
    final draggable = list.first.propertyList.firstWhere(
      (p) => p.name == 'draggable',
    );
    expect(draggable.defaultValue, 'false');
  });

  test(
    'TPopupBottomDisplayPanel inherits super param defaults when base parsed first',
    () {
      final list = _analyseFixture([
        'TPopupBasePanel',
        'TPopupBottomDisplayPanel',
      ], 'popup_super_ctor_fixture.dart');
      final panel = list.firstWhere(
        (e) => e.componentInfo!.name == 'TPopupBottomDisplayPanel',
      );
      final draggable = panel.propertyList.firstWhere(
        (p) => p.name == 'draggable',
      );
      expect(draggable.defaultValue, 'false');
    },
  );

  test('TPopupBottomDisplayPanel inherits super param defaults', () {
    final list = _analyseFixture([
      'TPopupBottomDisplayPanel',
    ], 'popup_super_ctor_fixture.dart');
    expect(list, isNotEmpty);
    final props = list.first.propertyList;
    final draggable = props.firstWhere((p) => p.name == 'draggable');
    expect(draggable.type, 'bool');
    expect(draggable.defaultValue, 'false');
    final maxHeight = props.firstWhere((p) => p.name == 'maxHeightRatio');
    expect(maxHeight.defaultValue, '0.9');
  });
}
