import 'package:tdesign_flutter_tools/api_completeness.dart';
import 'package:tdesign_flutter_tools/model.dart';
import 'package:test/test.dart';

ParsedComponentInfoInfo _enumInfo(
  String name,
  List<({String name, String introduction})> members,
) {
  final ComponentInfo componentInfo =
      ComponentInfo()
        ..name = name
        ..kind = 'enum';
  for (final member in members) {
    componentInfo.enumMembers.add(
      EnumMemberInfo()
        ..name = member.name
        ..introduction = member.introduction,
    );
  }
  componentInfo.enumValues =
      componentInfo.enumMembers
          .map((EnumMemberInfo member) => member.name)
          .toList();
  return ParsedComponentInfoInfo()
    ..componentInfo = componentInfo
    ..propertyList = <PropertyInfo>[]
    ..extraPropertyList = <PropertyInfo>[]
    ..staticMemberList = <PropertyInfo>[]
    ..fieldMap = <String, PropertyInfo>{};
}

ParsedComponentInfoInfo _classInfo(String name) {
  return ParsedComponentInfoInfo()
    ..componentInfo =
        (ComponentInfo()
          ..name = name
          ..kind = 'class')
    ..propertyList = <PropertyInfo>[]
    ..extraPropertyList = <PropertyInfo>[]
    ..staticMemberList = <PropertyInfo>[]
    ..fieldMap = <String, PropertyInfo>{};
}

void main() {
  test('enumMemberIntroductionIssues warns when enum members miss docs', () {
    final issues = enumMemberIntroductionIssues(
      'calendar',
      <ParsedComponentInfoInfo>[
        _enumInfo('CalendarType', <({String name, String introduction})>[
          (name: 'solar', introduction: '阳历'),
          (name: 'lunar', introduction: ''),
          (name: 'festival', introduction: '   '),
        ]),
      ],
    );

    expect(issues, hasLength(1));
    expect(issues.first.level, 'WARN');
    expect(issues.first.category, 'source');
    expect(issues.first.message, contains('enum CalendarType'));
    expect(issues.first.message, contains('festival'));
    expect(issues.first.message, contains('lunar'));
    expect(issues.first.message, contains('/// 注释'));
  });

  test('enumMemberIntroductionIssues ignores enums with complete docs', () {
    final issues = enumMemberIntroductionIssues(
      'calendar',
      <ParsedComponentInfoInfo>[
        _enumInfo('CalendarType', <({String name, String introduction})>[
          (name: 'solar', introduction: '阳历'),
          (name: 'lunar', introduction: '阴历'),
        ]),
      ],
    );

    expect(issues, isEmpty);
  });

  test('enumMemberIntroductionIssues ignores non-enum entries', () {
    final issues = enumMemberIntroductionIssues(
      'calendar',
      <ParsedComponentInfoInfo>[_classInfo('TCalendar')],
    );

    expect(issues, isEmpty);
  });
}
