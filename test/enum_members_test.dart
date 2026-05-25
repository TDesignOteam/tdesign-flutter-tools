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
    isGrammarParser: false,
    nameList: names,
    sourceFileName: relPath.split('/').last,
  ).analyse();
}

void main() {
  test('TCalendarDateType enum members include /// documentation', () {
    final list = _analyse(
      ['TCalendarDateType'],
      'lib/src/components/calendar/t_lunar_date.dart',
    );
    final info = list.first;
    expect(info.componentInfo!.kind, 'enum');
    expect(info.componentInfo!.enumMembers.length, 2);

    final solar = info.componentInfo!.enumMembers
        .firstWhere((EnumMemberInfo m) => m.name == 'solar');
    final lunar = info.componentInfo!.enumMembers
        .firstWhere((EnumMemberInfo m) => m.name == 'lunar');

    expect(solar.introduction, contains('阳历'));
    expect(lunar.introduction, contains('阴历'));
  });
}
