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
  final StringBuffer sb = StringBuffer('## API\n\n');
  String tableDocumentation(String text) {
    final prose = formatDocumentationForApi(text);
    return sanitizeTableCell(prose.isEmpty ? '-' : prose);
  }

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
    final typeContract = apiTypeContract(apiInfo.componentInfo!.declaration);
    if (typeContract.parameters.isNotEmpty) {
      sb.write('\n\n类型参数：`${sanitizeApiType(typeContract.parameters)}`\n');
    }
    if (typeContract.onType.isNotEmpty) {
      sb.write('\n\n适用类型：`${sanitizeApiType(typeContract.onType)}`\n');
    }
    final introduction = apiInfo.componentInfo!.introduction ?? '';
    final String introForSummary = formatIntroductionForApiSummary(
      introduction,
    );
    final bool showIntro = includeIntroduction;
    final String kind = apiInfo.componentInfo?.kind ?? 'class';

    if (kind == 'enum') {
      if (showIntro && introForSummary.isNotEmpty) {
        sb.write('\n\n');
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
              '| ${sanitizeTableCell(member.name)} | ${tableDocumentation(doc)} |\n',
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
        sb.write('\n\n');
        sb.write(introForSummary);
      }
      if (apiInfo.componentInfo!.typedefDefinition.isNotEmpty) {
        sb.write('\n#### 类型定义\n\n');
        sb.write('```dart\n${apiInfo.componentInfo!.typedefDefinition}\n```\n');
      }
      continue;
    }

    void writeCallableContract(
      String signature, {
      ApiCallableKind kind = ApiCallableKind.method,
      bool isExternal = false,
    }) {
      final contract = apiCallableContract(
        signature,
        ownerDeclaration:
            kind == ApiCallableKind.function
                ? ''
                : apiInfo.componentInfo!.declaration,
        kind: kind,
        isExternal: isExternal,
      );
      if (contract.typeParameters.isNotEmpty) {
        sb.write('\n\n类型参数：`${sanitizeApiType(contract.typeParameters)}`\n');
      }
      if (contract.shape.isNotEmpty) {
        sb.write('\n\n位置参数：`${sanitizeApiType(contract.shape)}`\n');
      }
    }

    if (kind == 'function') {
      final StaticMethodInfo? function =
          apiInfo.componentInfo!.topLevelFunction;
      if (function == null) {
        continue;
      }
      sb.write('\n#### 顶层函数');
      if (function.introduction?.isNotEmpty ?? false) {
        sb.write(
          '\n\n${formatDocumentationForApi(function.introduction!, headingLevel: 5)}',
        );
      }
      final String returnType = function.returnType ?? 'dynamic';
      sb.write('\n\n返回类型：`$returnType`');
      writeCallableContract(function.signature, kind: ApiCallableKind.function);
      if (function.params.isEmpty) sb.write('\n\n无参数。');
      if (function.params.isNotEmpty) {
        sb.write(
          '\n\n#### 参数\n\n'
          '| 名称 | 类型 | 默认值 | 说明 | 必传 |\n'
          '| --- | --- | --- | --- | --- |\n',
        );
        for (final PropertyInfo parameter in function.params) {
          sb.write(
            '| ${sanitizeTableCell(parameter.name)} | ${sanitizeApiType(parameter.type.isEmpty ? '-' : parameter.type)} | ${sanitizeApiType(parameter.defaultValue)} | ${tableDocumentation(parameter.introduction)} | ${parameter.isRequired ? '是' : '否'} |\n',
          );
        }
      }
      continue;
    }

    if (showIntro && introForSummary.isNotEmpty) {
      sb.write('\n\n');
      sb.write(introForSummary);
    }
    StaticMethodInfo? currentMethod;

    void writePropertyTable(
      List<PropertyInfo> items, {
      required String header,
      String nameColumn = '参数',
    }) {
      if (items.isEmpty) {
        return;
      }
      sb.write('\n\n#### $header');
      sb.write('''\n
| $nameColumn | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |\n''');
      for (final PropertyInfo item in items) {
        sb.write(
          '''| ${sanitizeTableCell(item.name)} | ${sanitizeApiType(item.type.isEmpty ? '-' : item.type)} | ${sanitizeApiType(item.defaultValue)} | ${tableDocumentation(item.introduction)} |\n''',
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
| 名称 | 类型 | 默认值 | 说明 | 必传 |
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
          '''| ${sanitizeTableCell(param.name)} | ${sanitizeApiType(type.isEmpty ? '-' : type)} | ${sanitizeApiType(param.defaultValue)} | ${tableDocumentation(introduction)} | ${param.isRequired ? '是' : '否'} |\n''',
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
          '\n\n##### ${apiInfo.componentInfo!.name}${item.name!.isEmpty ? '' : '.${sanitizeTableCell(item.name)}'}',
        );
        writeCallableContract(
          item.signature,
          kind: item.callableKind,
          isExternal: item.isExternal,
        );
        if (item.params.isEmpty) {
          sb.write('\n\n无参数。');
        }
        if (item.introduction != null && item.introduction!.isNotEmpty) {
          sb.write(
            '\n\n${formatDocumentationForApi(item.introduction!, headingLevel: 6)}',
          );
        }
        final String returnType =
            item.returnType == 'null' ? '' : (item.returnType ?? 'dynamic');
        if (includeReturnType && returnType.isNotEmpty) {
          sb.write('\n\n返回类型：`$returnType`');
        }
        writeMethodParamTable(item.params);
      }
      currentMethod = null;
    }

    // 类型说明 → 构造方法 → 属性/静态成员 → 静态/实例方法。
    // 默认构造使用相同正文渲染，不复制参数或说明格式。
    final constructors = <StaticMethodInfo>[
      if (apiInfo.componentInfo!.hasDefaultConstructor)
        StaticMethodInfo()
          ..name = ''
          ..signature = apiInfo.componentInfo!.defaultConstructorSignature
          ..callableKind = apiInfo.componentInfo!.defaultConstructorKind
          ..isExternal = apiInfo.componentInfo!.defaultConstructorIsExternal
          ..params = apiInfo.propertyList
          ..introduction =
              apiInfo.componentInfo!.defaultConstructorIntroduction,
      ...apiInfo.componentInfo!.constructorMethodList.where(
        (method) => !isLibraryPrivateNamedConstructor(method.name),
      ),
    ];
    writeMethodDetails(constructors, header: '构造方法');
    writePropertyTable(
      apiInfo.extraPropertyList,
      header: '属性',
      nameColumn: '属性',
    );
    writePropertyTable(
      apiInfo.staticMemberList,
      header: '静态成员',
      nameColumn: '名称',
    );
    writeMethodDetails(
      apiInfo.componentInfo!.staticMethodList,
      header: '静态方法',
      includeReturnType: true,
    );
    writeMethodDetails(
      apiInfo.componentInfo!.instanceMethodList,
      header: '实例方法',
      includeReturnType: true,
    );
  }
  return sb.toString();
}
