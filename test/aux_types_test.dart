import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:test/test.dart';

import 'support/component_paths.dart';
import 'support/fixture_paths.dart';

List<dynamic> _analyseFixture(List<String> names, String fileName) {
  final String path = fixtureSourcePath(fileName);
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
    sourceFileName: fileName,
  ).analyse();
}

/// develop 上 popup 为 library + part，辅助类型在独立 part 文件中，需在 --name 中显式列出。
List<dynamic> _analysePopupPart(List<String> names, String partFile) {
  const String relDir = 'lib/src/components/popup';
  final String popupDir = p.join(tdesignComponentRoot, relDir);
  final String path = p.join(popupDir, partFile);
  final col = AnalysisContextCollection(
    includedPaths: [popupDir],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );
  final parsed =
      col.contextFor(path).currentSession.getParsedUnit(path) as ParsedUnitResult;
  return ComponentRule(
    parsedUnitResult: parsed,
    isGrammarParser: false,
    nameList: names,
    folderName: 'popup',
    sourceFileName: partFile,
  ).analyse();
}

void main() {
  test('auto includes enum and typedef in the same source file as target class', () {
    final list = _analyseFixture(
      ['TargetWidget'],
      'popup_aux_types_fixture.dart',
    );
    final names = list.map((e) => e.componentInfo!.name).toList();
    expect(names, containsAll(['TargetWidget', 'AutoIncludedEnum', 'AutoIncludedTypedef']));
    final enumInfo =
        list.firstWhere((e) => e.componentInfo!.name == 'AutoIncludedEnum');
    expect(enumInfo.componentInfo!.kind, 'enum');
    expect(enumInfo.componentInfo!.enumValues, containsAll(['top', 'bottom']));
    final typedefInfo =
        list.firstWhere((e) => e.componentInfo!.name == 'AutoIncludedTypedef');
    expect(typedefInfo.componentInfo!.kind, 'typedef');
    expect(typedefInfo.componentInfo!.typedefDefinition, contains('Function'));
  });

  test('develop popup: TPopupPlacement parses from types part file', () {
    final list = _analysePopupPart(['TPopupPlacement'], 't_popup_types.dart');
    final names = list.map((e) => e.componentInfo!.name).toList();
    expect(names, contains('TPopupPlacement'));
    final enumInfo =
        list.firstWhere((e) => e.componentInfo!.name == 'TPopupPlacement');
    expect(enumInfo.componentInfo!.kind, 'enum');
    expect(enumInfo.componentInfo!.enumValues,
        containsAll(['top', 'left', 'right', 'bottom', 'center']));
  });

  test('develop popup: TPopupSlotBuilder parses from types part file', () {
    final list = _analysePopupPart(['TPopupSlotBuilder'], 't_popup_types.dart');
    final names = list.map((e) => e.componentInfo!.name).toList();
    expect(names, contains('TPopupSlotBuilder'));
    final typedefInfo =
        list.firstWhere((e) => e.componentInfo!.name == 'TPopupSlotBuilder');
    expect(typedefInfo.componentInfo!.kind, 'typedef');
    expect(typedefInfo.componentInfo!.typedefDefinition, contains('Function'));
  });
}
