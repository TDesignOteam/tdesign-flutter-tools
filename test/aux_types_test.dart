import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:test/test.dart';

List<dynamic> _analyse(List<String> names, String path) {
  final col = AnalysisContextCollection(
    includedPaths: [path],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );
  final parsed = col.contextFor(path).currentSession.getParsedUnit(path)
      as ParsedUnitResult;
  return ComponentRule(
    parsedUnitResult: parsed,
    isGrammarParser: false,
    nameList: names,
    folderName: 'popup',
    sourceFileName: path.split('/').last,
  ).analyse();
}

void main() {
  test('auto includes SlideTransitionFrom when parsing TSlidePopupRoute file', () {
    final path =
        '/Users/rs/Documents/cursor/tdesign-flutter/tdesign-component/lib/src/components/popup/t_popup_route.dart';
    final list = _analyse(['TSlidePopupRoute'], path);
    final names = list.map((e) => e.componentInfo!.name).toList();
    expect(names, contains('SlideTransitionFrom'));
    final enumInfo =
        list.firstWhere((e) => e.componentInfo!.name == 'SlideTransitionFrom');
    expect(enumInfo.componentInfo!.kind, 'enum');
    expect(enumInfo.componentInfo!.enumValues,
        containsAll(['top', 'right', 'left', 'bottom', 'center']));
  });

  test('auto includes PopupClick when parsing popup panel file', () {
    final path =
        '/Users/rs/Documents/cursor/tdesign-flutter/tdesign-component/lib/src/components/popup/t_popup_panel.dart';
    final list = _analyse(['TPopupBottomDisplayPanel'], path);
    final names = list.map((e) => e.componentInfo!.name).toList();
    expect(names, contains('PopupClick'));
    final typedefInfo =
        list.firstWhere((e) => e.componentInfo!.name == 'PopupClick');
    expect(typedefInfo.componentInfo!.kind, 'typedef');
    expect(typedefInfo.componentInfo!.typedefDefinition,
        contains('Function()'));
  });
}
