import 'api_signature.dart';
import 'documentation.dart';
import 'model.dart';
import 'util.dart';

/// Render parsed API models without I/O or mutations of the input models.
String renderApiMarkdown(
  List<ParsedComponentInfoInfo> parsedComponentInfoList, {
  required List<String> names,
  bool strictNames = false,
  bool includeIntroduction = false,
}) {
  String fileContent = '''
## API

默认值列展示源码声明的默认值；`-` 表示未显式声明。运行时的 Theme / Token 回退见说明，参数是否必填见「必填」列。

''';
  StringBuffer sb = StringBuffer(fileContent);
  final List<ParsedComponentInfoInfo> documentedInfos =
      strictNames
          ? parsedComponentInfoList
              .where((info) => names.contains(info.componentInfo?.name))
              .toList()
          : parsedComponentInfoList;
  for (final apiInfo in documentedInfos) {
    if (documentedInfos.indexOf(apiInfo) >= 1) {
      sb.write('\n\n');
    }
    sb.write('### ${apiInfo.componentInfo!.name}');
    final introduction = apiInfo.componentInfo!.introduction ?? '';
    final String introForSummary = formatIntroductionForApiSummary(
      introduction,
    );
    final bool showIntro = includeIntroduction;
    final String kind = apiInfo.componentInfo?.kind ?? 'class';

    if (kind == 'enum') {
      if (showIntro && introForSummary.isNotEmpty) {
        sb.write('\n#### 简介\n');
        sb.write(introForSummary);
      }
      final List<EnumMemberInfo> enumMembers =
          apiInfo.componentInfo!.enumMembers;
      final bool isSimpleEnum =
          apiInfo.componentInfo!.isSimpleEnum && !showIntro;
      if (enumMembers.isNotEmpty) {
        sb.write('\n#### 枚举值\n');
        if (isSimpleEnum) {
          sb.write('''\n
| 名称 |
| --- |\n''');
          for (final EnumMemberInfo member in enumMembers) {
            sb.write('| ${sanitizeTableCell(member.name)} |\n');
          }
        } else {
          sb.write('''\n
| 名称 | 说明 |
| --- | --- |\n''');
          for (final EnumMemberInfo member in enumMembers) {
            final String doc =
                member.introduction.isEmpty ? '-' : member.introduction;
            sb.write(
              '| ${sanitizeTableCell(member.name)} | ${sanitizeTableCell(doc)} |\n',
            );
          }
        }
      } else if (apiInfo.componentInfo!.enumValues.isNotEmpty) {
        sb.write('\n#### 枚举值\n');
        if (isSimpleEnum) {
          sb.write('''\n
| 名称 |
| --- |\n''');
          for (final String value in apiInfo.componentInfo!.enumValues) {
            sb.write('| ${sanitizeTableCell(value)} |\n');
          }
        } else {
          sb.write('''\n
| 名称 | 说明 |
| --- | --- |\n''');
          for (final String value in apiInfo.componentInfo!.enumValues) {
            sb.write('| ${sanitizeTableCell(value)} | - |\n');
          }
        }
      }
      continue;
    }

    if (kind == 'typedef') {
      if (showIntro && introForSummary.isNotEmpty) {
        sb.write('\n#### 简介\n');
        sb.write(introForSummary);
      }
      if (apiInfo.componentInfo!.typedefDefinition.isNotEmpty) {
        sb.write('\n#### 类型定义\n\n');
        sb.write('```dart\n${apiInfo.componentInfo!.typedefDefinition}\n```\n');
      }
      continue;
    }

    if (kind == 'function') {
      final StaticMethodInfo? function =
          apiInfo.componentInfo!.topLevelFunction;
      if (function == null) {
        continue;
      }
      sb.write('\n#### 顶层函数');
      if (function.introduction?.isNotEmpty ?? false) {
        sb.write('\n\n${function.introduction}');
      }
      final String returnType = function.returnType ?? 'dynamic';
      sb.write('\n\n返回类型：`$returnType`');
      if (function.signature.isNotEmpty)
        sb.write('\n\n```dart\n${function.signature}\n```\n');
      if (function.params.isNotEmpty) {
        sb.write(
          '\n\n#### 参数\n\n'
          '| 参数 | 类型 | 默认值 | 说明 | 必填 |\n'
          '| --- | --- | --- | --- | --- |\n',
        );
        for (final PropertyInfo parameter in function.params) {
          sb.write(
            '| ${sanitizeTableCell(parameter.name)} | ${sanitizeApiType(parameter.type.isEmpty ? '-' : parameter.type)} | ${sanitizeApiType(parameter.defaultValue)} | ${sanitizeTableCell(parameter.introduction.isEmpty ? '-' : parameter.introduction)} | ${parameter.isRequired ? '是' : '否'} |\n',
          );
        }
      }
      continue;
    }

    if (showIntro && introForSummary.isNotEmpty) {
      sb.write('\n#### 简介\n');
      sb.write(introForSummary);
    }
    if (apiInfo.componentInfo!.declaration.isNotEmpty)
      sb.write(
        '\n\n#### 声明\n\n```dart\n${apiInfo.componentInfo!.declaration}\n```\n',
      );
    void writeSignature(
      String signature, {
      ApiCallableKind kind = ApiCallableKind.method,
      bool isExternal = false,
    }) {
      if (signature.isEmpty) return;
      final code = formatApiSignature(
        signature,
        ownerDeclaration: apiInfo.componentInfo!.declaration,
        kind: kind,
        isExternal: isExternal,
      );
      sb.write('\n\n```dart\n$code\n```\n');
    }

    StaticMethodInfo? currentMethod;

    void writePropertyTable(
      List<PropertyInfo> items, {
      required String header,
      String nameColumn = '参数',
      int headingLevel = 4,
      bool showRequired = false,
    }) {
      if (items.isEmpty) {
        return;
      }
      sb.write('\n${'#' * headingLevel} $header');
      sb.write('''\n
| $nameColumn | 类型 | 默认值 | 说明 |${showRequired ? ' 必填 |' : ''}
| --- | --- | --- | --- |${showRequired ? ' --- |' : ''}\n''');
      for (final PropertyInfo item in items) {
        sb.write(
          '''| ${sanitizeTableCell(item.name)} | ${sanitizeApiType(item.type.isEmpty ? '-' : item.type)} | ${sanitizeApiType(item.defaultValue)} | ${sanitizeTableCell(item.introduction.isEmpty ? '-' : item.introduction)} |${showRequired ? ' ${item.isRequired ? '是' : '否'} |' : ''}\n''',
        );
      }
    }

    PropertyInfo? resolveForwardedParamInfo(
      StaticMethodInfo method,
      PropertyInfo param,
    ) {
      final String? targetName = method.forwardedTargetName;
      final String? targetParamName = method.forwardedParamMap[param.name];
      if (targetName == null ||
          targetName.isEmpty ||
          targetParamName == null ||
          targetParamName.isEmpty) {
        return null;
      }
      ParsedComponentInfoInfo? targetInfo;
      for (final ParsedComponentInfoInfo item in parsedComponentInfoList) {
        if (item.componentInfo?.kind == 'class' &&
            item.componentInfo?.name == targetName) {
          targetInfo = item;
          break;
        }
      }
      if (targetInfo == null) {
        return null;
      }
      final String? constructorName = method.forwardedConstructorName;
      if (constructorName != null && constructorName.isNotEmpty) {
        for (final StaticMethodInfo ctor
            in targetInfo.componentInfo!.constructorMethodList) {
          if (ctor.name != constructorName) {
            continue;
          }
          for (final PropertyInfo item in ctor.params) {
            if (item.name == targetParamName) {
              return item;
            }
          }
          return null;
        }
        return null;
      }
      for (final PropertyInfo item in targetInfo.propertyList) {
        if (item.name == targetParamName) {
          return item;
        }
      }
      return targetInfo.fieldMap[targetParamName];
    }

    void writeMethodParamTable(List<PropertyInfo> params) {
      if (params.isEmpty) {
        return;
      }
      sb.write('''\n
| 参数 | 类型 | 默认值 | 说明 | 必填 |
| --- | --- | --- | --- | --- |\n''');
      for (final PropertyInfo param in params) {
        PropertyInfo? forwardedParam;
        if (currentMethod != null) {
          forwardedParam = resolveForwardedParamInfo(currentMethod!, param);
        }
        final String type =
            ((param.type.isEmpty || param.type == '-') &&
                    forwardedParam != null &&
                    forwardedParam.type.isNotEmpty &&
                    forwardedParam.type != '-')
                ? forwardedParam.type
                : param.type;
        final String introduction =
            param.introduction.isEmpty && forwardedParam != null
                ? forwardedParam.introduction
                : param.introduction;
        sb.write(
          '''| ${sanitizeTableCell(param.name)} | ${sanitizeApiType(type.isEmpty ? '-' : type)} | ${sanitizeApiType(param.defaultValue)} | ${sanitizeTableCell(introduction.isEmpty ? '-' : introduction)} | ${param.isRequired ? '是' : '否'} |\n''',
        );
      }
    }

    void writeMethodDetails(
      List<StaticMethodInfo> methods, {
      required String header,
      bool includeReturnType = false,
    }) {
      if (methods.isEmpty) {
        return;
      }
      sb.write('\n\n#### $header');
      final orderedMethods = List<StaticMethodInfo>.of(methods);
      orderedMethods.sort(
        (StaticMethodInfo a, StaticMethodInfo b) =>
            a.name!.toLowerCase().compareTo(b.name!.toLowerCase()),
      );
      for (final StaticMethodInfo item in orderedMethods) {
        currentMethod = item;
        sb.write(
          '\n\n##### ${apiInfo.componentInfo!.name}.${sanitizeTableCell(item.name)}',
        );
        writeSignature(
          item.signature,
          kind: item.callableKind,
          isExternal: item.isExternal,
        );
        if (item.introduction != null && item.introduction!.isNotEmpty) {
          sb.write('\n\n${item.introduction}');
        }
        final String returnType =
            item.returnType == 'null' ? '' : (item.returnType ?? '');
        if (includeReturnType && returnType.isNotEmpty) {
          sb.write('\n\n返回类型：`$returnType`');
        }
        writeMethodParamTable(item.params);
      }
      currentMethod = null;
    }

    // 对外 API 优先：命令式入口 → 命名工厂 → 默认构造 → 字段/成员 → 实例方法
    if (apiInfo.componentInfo?.staticMethodList.isNotEmpty ?? false) {
      writeMethodDetails(
        apiInfo.componentInfo!.staticMethodList,
        header: '静态方法',
        includeReturnType: true,
      );
    }
    final List<StaticMethodInfo> publicNamedConstructors =
        apiInfo.componentInfo!.constructorMethodList
            .where(
              (StaticMethodInfo method) =>
                  !isLibraryPrivateNamedConstructor(method.name),
            )
            .toList();
    if (publicNamedConstructors.isNotEmpty) {
      writeMethodDetails(
        publicNamedConstructors.where((method) => method.isFactory).toList(),
        header: '工厂构造方法',
      );
    }
    writeMethodDetails(
      publicNamedConstructors.where((method) => !method.isFactory).toList(),
      header: '命名构造方法',
    );
    if (apiInfo.componentInfo!.hasDefaultConstructor &&
        apiInfo.propertyList.isEmpty) {
      sb.write('\n#### 默认构造方法\n');
      writeSignature(
        apiInfo.componentInfo!.defaultConstructorSignature,
        kind: apiInfo.componentInfo!.defaultConstructorKind,
        isExternal: apiInfo.componentInfo!.defaultConstructorIsExternal,
      );
      final String docs = apiInfo.componentInfo!.defaultConstructorIntroduction;
      if (docs.isNotEmpty) sb.write('\n$docs\n');
    }
    if (apiInfo.propertyList.isNotEmpty) {
      sb.write('\n#### 默认构造方法\n');
      writeSignature(
        apiInfo.componentInfo!.defaultConstructorSignature,
        kind: apiInfo.componentInfo!.defaultConstructorKind,
        isExternal: apiInfo.componentInfo!.defaultConstructorIsExternal,
      );
      final docs = apiInfo.componentInfo!.defaultConstructorIntroduction;
      if (docs.isNotEmpty) sb.write('\n$docs\n');
      writePropertyTable(
        apiInfo.propertyList,
        header: '参数',
        headingLevel: 5,
        showRequired: true,
      );
    }
    writePropertyTable(
      apiInfo.extraPropertyList,
      header: '公开属性（字段与访问器）',
      nameColumn: '属性',
    );
    writePropertyTable(
      apiInfo.staticMemberList,
      header: '静态成员',
      nameColumn: '名称',
    );
    writeMethodDetails(
      apiInfo.componentInfo!.instanceMethodList,
      header: '实例方法',
      includeReturnType: true,
    );
  }
  return sb.toString();
}
