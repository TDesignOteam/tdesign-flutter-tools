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

void main() {
  test('TCalendarPopup default ctor includes positional context param', () {
    final list = _analyse(
      ['TCalendarPopup'],
      'lib/src/components/calendar/t_calendar_popup.dart',
    );
    final info = list.first;
    expect(info.propertyList.map((PropertyInfo p) => p.name), contains('context'));

    final contextParam = info.propertyList
        .firstWhere((PropertyInfo p) => p.name == 'context');
    expect(contextParam.isNamed, isFalse);
    expect(contextParam.type, 'BuildContext');

    // positional 参数排在命名参数之前
    final firstParam = info.propertyList.first;
    expect(firstParam.name, 'context');
    expect(firstParam.isNamed, isFalse);
  });
}
