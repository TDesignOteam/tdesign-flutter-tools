import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;
import 'package:tdesign_flutter_tools/component_rule.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:tdesign_flutter_tools/smart_create.dart';
import 'package:test/test.dart';

List<ParsedComponentInfoInfo> _analyseFile(String path, List<String> names) {
  final AnalysisContextCollection col = AnalysisContextCollection(
    includedPaths: <String>[path],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );
  final ParsedUnitResult parsed =
      col.contextFor(path).currentSession.getParsedUnit(path)
          as ParsedUnitResult;
  return ComponentRule(
    parsedUnitResult: parsed,
    isGrammarParser: false,
    nameList: names,
    sourceFileName: p.basename(path),
  ).analyse();
}

void main() {
  test('doc-simple-enum marker is parsed from regular comment', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'tdesign_simple_enum_parse_',
    );
    final File file = File(p.join(tempDir.path, 'avatar_enum.dart'));

    try {
      await file.writeAsString('''
// doc-simple-enum
/// 头像尺寸
enum TAvatarSize {
  small,
  medium,
  large,
}
''');

      final ParsedComponentInfoInfo info =
          _analyseFile(file.path, <String>['TAvatarSize']).first;

      expect(info.componentInfo!.kind, 'enum');
      expect(info.componentInfo!.isSimpleEnum, isTrue);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'generateApiInfoFile renders simple enum without description column',
    () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'tdesign_simple_enum_doc_',
      );

      try {
        final ComponentInfo componentInfo =
            ComponentInfo()
              ..name = 'TAvatarSize'
              ..kind = 'enum'
              ..isSimpleEnum = true
              ..introduction = '头像尺寸';
        componentInfo.enumMembers.addAll(<EnumMemberInfo>[
          EnumMemberInfo()..name = 'large',
          EnumMemberInfo()..name = 'medium',
          EnumMemberInfo()..name = 'small',
        ]);
        componentInfo.enumValues =
            componentInfo.enumMembers
                .map((EnumMemberInfo member) => member.name)
                .toList();

        final ParsedComponentInfoInfo parsed =
            ParsedComponentInfoInfo()
              ..componentInfo = componentInfo
              ..propertyList = <PropertyInfo>[]
              ..extraPropertyList = <PropertyInfo>[]
              ..staticMemberList = <PropertyInfo>[]
              ..fieldMap = <String, PropertyInfo>{};

        final SmartCreator creator = SmartCreator(
          nameList: <String>['TAvatarSize'],
          basePath: tempDir.path,
          folderName: 'avatar',
          output: '',
          isFileMode: true,
          onlyApi: true,
          isGrammarParser: false,
        );

        await creator.generateApiInfoFile(<ParsedComponentInfoInfo>[parsed]);

        final String content =
            await File(p.join(tempDir.path, 'avatar_api.md')).readAsString();
        expect(content, contains('### TAvatarSize'));
        expect(content, contains('| 名称 |'));
        expect(content, isNot(contains('| 名称 | 说明 |')));
        expect(content, contains('| large |'));
        expect(content, isNot(contains('| large | - |')));
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
  );
}
