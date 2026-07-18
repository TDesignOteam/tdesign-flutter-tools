import 'package:tdesign_flutter_tools/model.dart';
import 'package:tdesign_flutter_tools/util.dart';
import 'package:test/test.dart';

void main() {
  test('reportDuplicateAuxiliaryDefinitions warns on cross-file enum dup', () {
    final items = [
      ParsedComponentInfoInfo()
        ..componentInfo =
            (ComponentInfo()
              ..name = 'CalendarTrigger'
              ..kind = 'enum'
              ..sourceFile = 't_calendar.dart')
        ..propertyList = []
        ..extraPropertyList = []
        ..staticMemberList = []
        ..fieldMap = {},
      ParsedComponentInfoInfo()
        ..componentInfo =
            (ComponentInfo()
              ..name = 'CalendarTrigger'
              ..kind = 'enum'
              ..sourceFile = 't_calendar_popup.dart')
        ..propertyList = []
        ..extraPropertyList = []
        ..staticMemberList = []
        ..fieldMap = {},
    ];
    expect(
      () => reportDuplicateAuxiliaryDefinitions(items),
      prints(
        allOf(
          contains('CalendarTrigger'),
          contains('t_calendar.dart'),
          contains('t_calendar_popup.dart'),
        ),
      ),
    );
  });
}
