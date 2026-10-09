import 'api_signature.dart';
import 'documentation.dart';
import 'model.dart';
import 'theme_documentation.dart';
import 'util.dart';

const apiTableHeader = '| 名称 | 类型 | 默认值 | 说明 | 必传 |';
const apiTableDivider = '| --- | --- | --- | --- | --- |';

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
  bool isTheme(ParsedComponentInfoInfo info) => usesThemeConfigurationTable(
    info.componentInfo!.declaration,
    info.componentInfo!.introduction ?? '',
  );
  final orderedInfos = [
    ...documentedInfos.where((info) => !isTheme(info)),
    ...documentedInfos.where(isTheme),
  ];
  for (final apiInfo in orderedInfos) {
    if (orderedInfos.indexOf(apiInfo) >= 1) {
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
    final rawIntroduction = apiInfo.componentInfo!.introduction ?? '';
    final themeConfiguration = usesThemeConfigurationTable(
      apiInfo.componentInfo!.declaration,
      rawIntroduction,
    );
    final introduction = rawIntroduction.replaceAll(componentThemeCategory, '');
    final String introForSummary = _uniformApiTables(
      formatIntroductionForApiSummary(introduction),
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
      if (enumMembers.isNotEmpty ||
          apiInfo.componentInfo!.enumValues.isNotEmpty) {
        sb.write('\n#### 枚举值\n\n$apiTableHeader\n$apiTableDivider\n');
        final type = sanitizeApiType(apiInfo.componentInfo!.name ?? '-');
        if (enumMembers.isNotEmpty) {
          for (final member in enumMembers) {
            sb.write(
              '| ${sanitizeTableCell(member.name)} | $type | - | '
              '${tableDocumentation(member.introduction)} | - |\n',
            );
          }
        } else {
          for (final value in apiInfo.componentInfo!.enumValues) {
            sb.write('| ${sanitizeTableCell(value)} | $type | - | - | - |\n');
          }
        }
      }
      continue;
    }

    if (kind == 'typedef') {
      final info = apiInfo.componentInfo!;
      if (info.typedefDefinition.isEmpty) continue;
      final contract = apiTypedefContract(info.typedefDefinition);
      if (contract.parameters.isNotEmpty) {
        sb.write('\n\n类型参数：`${sanitizeApiType(contract.parameters)}`\n');
      }
      final callback = info.typedefFunction;
      if (callback == null) {
        sb.write(
          '\n\n#### 类型定义\n\n$apiTableHeader\n$apiTableDivider\n'
          '| ${sanitizeTableCell(info.name)} | ${sanitizeApiType(contract.target)} | - | ${tableDocumentation(introduction)} | - |\n',
        );
        continue;
      }
      final documentation = splitApiReturnDocumentation(
        formatDocumentationForApi(callback.introduction ?? ''),
      );
      if (showIntro && documentation.narrative.isNotEmpty) {
        sb.write(
          '\n\n${_uniformApiTables(formatIntroductionForApiSummary(documentation.narrative))}',
        );
      }
      if (contract.callbackParameters.isNotEmpty) {
        sb.write(
          '\n\n回调类型参数：`${sanitizeApiType(contract.callbackParameters)}`\n',
        );
      }
      if (contract.nullable) sb.write('\n\n可空：是。\n');
      final positional = callback.params
          .where((parameter) => !parameter.isNamed)
          .map((parameter) => parameter.name)
          .join(', ');
      if (positional.isNotEmpty) {
        sb.write('\n\n位置参数：`${sanitizeApiType(positional)}`\n');
      }
      sb.write('\n\n#### 回调参数\n\n');
      if (callback.params.isEmpty) {
        sb.write('无参数。\n');
      } else {
        sb.write('$apiTableHeader\n$apiTableDivider\n');
        for (final parameter in callback.params) {
          sb.write(
            '| ${sanitizeTableCell(parameter.name)} | ${sanitizeApiType(parameter.type)} | ${sanitizeApiType(parameter.defaultValue)} | ${tableDocumentation(parameter.introduction)} | ${parameter.isRequired ? '是' : '否'} |\n',
          );
        }
      }
      sb.write(
        '\n\n#### 返回值\n\n$apiTableHeader\n$apiTableDivider\n'
        '| 返回值 | ${sanitizeApiType(callback.returnType ?? 'dynamic')} | - | ${tableDocumentation(documentation.returns)} | - |\n',
      );
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

    void writeReturnValue(String type, String description, {int level = 6}) {
      if (type == 'void') return;
      sb.write(
        '\n\n${'#' * level} 返回值\n\n'
        '$apiTableHeader\n$apiTableDivider\n'
        '| 返回值 | ${sanitizeApiType(type)} | - | ${tableDocumentation(description)} | - |\n',
      );
    }

    if (kind == 'function') {
      final StaticMethodInfo? function =
          apiInfo.componentInfo!.topLevelFunction;
      if (function == null) {
        continue;
      }
      sb.write('\n#### 顶层函数');
      final documentation = splitApiReturnDocumentation(
        formatDocumentationForApi(function.introduction ?? ''),
      );
      if (documentation.narrative.isNotEmpty) {
        sb.write(
          '\n\n${_uniformApiTables(formatDocumentationForApi(documentation.narrative, headingLevel: 5))}',
        );
      }
      writeCallableContract(function.signature, kind: ApiCallableKind.function);
      if (function.params.isEmpty) sb.write('\n\n无参数。');
      if (function.params.isNotEmpty) {
        sb.write('\n\n#### 参数\n\n$apiTableHeader\n$apiTableDivider\n');
        for (final PropertyInfo parameter in function.params) {
          sb.write(
            '| ${sanitizeTableCell(parameter.name)} | ${sanitizeApiType(parameter.type.isEmpty ? '-' : parameter.type)} | ${sanitizeApiType(parameter.defaultValue)} | ${tableDocumentation(parameter.introduction)} | ${parameter.isRequired ? '是' : '否'} |\n',
          );
        }
      }
      writeReturnValue(
        function.returnType ?? 'dynamic',
        documentation.returns,
        level: 4,
      );
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
    }) {
      if (items.isEmpty) {
        return;
      }
      sb.write('\n\n#### $header');
      sb.write('''\n
$apiTableHeader
$apiTableDivider\n''');
      for (final PropertyInfo item in items) {
        sb.write(
          '''| ${sanitizeTableCell(item.name)} | ${sanitizeApiType(item.type.isEmpty ? '-' : item.type)} | ${sanitizeApiType(item.defaultValue)} | ${tableDocumentation(item.introduction)} | - |\n''',
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
$apiTableHeader
$apiTableDivider\n''');
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
        final prose = formatDocumentationForApi(item.introduction ?? '');
        final documentation =
            includeReturnType
                ? splitApiReturnDocumentation(prose)
                : (narrative: prose, returns: '');
        if (documentation.narrative.isNotEmpty) {
          sb.write(
            '\n\n${_uniformApiTables(formatDocumentationForApi(documentation.narrative, headingLevel: 6))}',
          );
        }
        writeMethodParamTable(item.params);
        final String returnType =
            item.returnType == 'null' ? '' : (item.returnType ?? 'dynamic');
        if (includeReturnType && returnType.isNotEmpty) {
          writeReturnValue(returnType, documentation.returns);
        }
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
    if (themeConfiguration) {
      sb.write('\n\n<!-- api-theme: fields -->\n\n#### 配置项\n');
      currentMethod = constructors.where((item) => item.name == '').firstOrNull;
      writeMethodParamTable(apiInfo.propertyList);
      currentMethod = null;
      writeMethodDetails(
        constructors.where((item) => item.name != '').toList(),
        header: '构造方法',
      );
    } else {
      writeMethodDetails(constructors, header: '构造方法');
    }
    writePropertyTable(apiInfo.extraPropertyList, header: '属性');
    writePropertyTable(apiInfo.staticMemberList, header: '静态成员');
    writeMethodDetails(
      apiInfo.componentInfo!.staticMethodList,
      header: '静态方法',
      includeReturnType: true,
    );
    writeMethodDetails(
      apiInfo.componentInfo!.instanceMethodList
          .where(
            (method) =>
                !themeConfiguration ||
                !sharedThemeMethods.contains(method.name),
          )
          .toList(),
      header: '实例方法',
      includeReturnType: true,
    );
  }
  return sb.toString();
}

/// Preserve authored table relationships within the shared API columns.
String _uniformApiTables(String markdown) {
  List<String> cells(String line) {
    final result = <String>[];
    final cell = StringBuffer();
    var slashes = 0;
    for (var i = 1; i < line.length - 1; i++) {
      final char = line[i];
      if (char == '|' && slashes.isEven) {
        result.add(cell.toString().trim());
        cell.clear();
      } else {
        cell.write(char);
      }
      slashes = char == r'\' ? slashes + 1 : 0;
    }
    result.add(cell.toString().trim());
    return result;
  }

  final lines = markdown.split('\n');
  final result = <String>[];
  var inCode = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('```')) inCode = !inCode;
    if (inCode ||
        !line.startsWith('|') ||
        i + 1 >= lines.length ||
        !cells(
          lines[i + 1],
        ).every((cell) => RegExp(r'^:?-+:?$').hasMatch(cell))) {
      result.add(line);
      continue;
    }
    final headers = cells(line);
    result.addAll([
      '<!-- api-table: details -->',
      apiTableHeader,
      apiTableDivider,
    ]);
    i++;
    while (i + 1 < lines.length && lines[i + 1].startsWith('|')) {
      final row = cells(lines[++i]);
      if (row.length != headers.length) {
        throw FormatException(
          'API table column count does not match its header',
          lines[i],
        );
      }
      if (line == apiTableHeader) {
        result.add(lines[i]);
        continue;
      }
      final description = <String>[];
      for (var j = 1; j < row.length; j++) {
        description.add(
          headers[j] == '说明' || headers[j] == '行为' || headers[j] == '结果'
              ? row[j]
              : '${headers[j]}：${row[j]}',
        );
      }
      final name =
          RegExp(r'^[a-z][a-zA-Z0-9_]*$').hasMatch(headers.first)
              ? '${headers.first}：${row.first}'
              : row.first;
      final details = description.isEmpty ? '-' : description.join('；');
      result.add('| $name | - | - | $details | - |');
    }
  }
  return result.join('\n');
}
