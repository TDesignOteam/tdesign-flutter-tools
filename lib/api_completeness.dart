import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'api_signature.dart';
import 'model.dart';
import 'smart_create.dart';
import 'util.dart';

/// 完备性检测条目
class CompletenessIssue {
  CompletenessIssue({
    required this.component,
    required this.level,
    required this.category,
    required this.message,
  });

  final String component;
  final String level; // ERROR | WARN | INFO
  final String category; // scope | tool | source | ok
  final String message;
}

/// 单个组件的审计配置（与 demo_tool/all_build.sh 的 --name 对齐）
class ComponentAuditConfig {
  ComponentAuditConfig({
    required this.componentKey,
    required this.classNames,
    required this.sourceFolder,
    required this.folderName,
    this.sourceIsFile = false,
  });

  final String componentKey;
  final List<String> classNames;

  /// 相对 component 根目录，如 lib/src/components/picker
  final String sourceFolder;
  final String folderName;
  final bool sourceIsFile;
}

/// 从 YAML/JSON 配置文件加载审计清单（components 节点）
Future<List<ComponentAuditConfig>> loadAuditConfigsFromFile(String path) async {
  final File file = File(path);
  if (!file.existsSync()) {
    throw ArgumentError('配置文件不存在: $path');
  }
  final String content = await file.readAsString();
  if (path.endsWith('.json')) {
    final dynamic decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic> && decoded['components'] is List) {
      if (decoded['schemaVersion'] != 1)
        throw ArgumentError('Unsupported manifest schema: $path');
      return (decoded['components'] as List).map((dynamic item) {
        final component = Map<String, dynamic>.from(item as Map);
        final source = Map<String, dynamic>.from(component['source'] as Map);
        final api = Map<String, dynamic>.from(component['api'] as Map);
        final names = <String>[
          ...(api['names'] as List).cast<String>(),
          ...?(api['functions'] as List?)?.cast<String>(),
        ];
        if (names.isEmpty || !const {'file', 'folder'}.contains(source['type']))
          throw ArgumentError(
            'Invalid component manifest entry: ${component['slug']}',
          );
        return ComponentAuditConfig(
          componentKey: component['slug'] as String,
          classNames: names,
          sourceFolder: source['path'] as String,
          sourceIsFile: source['type'] == 'file',
          folderName: component['slug'] as String,
        );
      }).toList();
    }
    if (decoded is Map<String, dynamic> && decoded['components'] is Map) {
      return _configsFromMap(
        Map<String, dynamic>.from(decoded['components'] as Map),
      );
    }
    if (decoded is Map<String, dynamic>) {
      return _configsFromMap(decoded);
    }
    throw ArgumentError('JSON 配置格式无效: $path');
  }
  return _configsFromYaml(content);
}

List<ComponentAuditConfig> _configsFromMap(Map<String, dynamic> components) {
  final List<ComponentAuditConfig> configs = <ComponentAuditConfig>[];
  for (final MapEntry<String, dynamic> entry in components.entries) {
    if (entry.value is! Map) {
      throw ArgumentError('组件 ${entry.key} 配置无效');
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(
      entry.value as Map,
    );
    final String? folderName = map['folder_name'] as String?;
    final String? sourceFolder = map['source_folder'] as String?;
    final dynamic classesRaw = map['classes'];
    if (folderName == null ||
        sourceFolder == null ||
        classesRaw is! List ||
        classesRaw.isEmpty) {
      throw ArgumentError(
        '组件 ${entry.key} 缺少 folder_name / source_folder / classes',
      );
    }
    configs.add(
      ComponentAuditConfig(
        componentKey: entry.key,
        folderName: folderName,
        sourceFolder: sourceFolder,
        classNames: classesRaw.map((dynamic e) => e.toString()).toList(),
      ),
    );
  }
  return configs;
}

/// 解析 CI 专用 YAML 子集（仅 components / folder_name / source_folder / classes）
List<ComponentAuditConfig> _configsFromYaml(String yaml) {
  final Map<String, Map<String, dynamic>> components =
      <String, Map<String, dynamic>>{};
  String? currentKey;
  String? listKey;

  for (final String rawLine in yaml.split('\n')) {
    final String line = rawLine.split('#').first.trimRight();
    final String trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }

    final RegExpMatch? componentMatch = RegExp(r'^(\w+):$').firstMatch(trimmed);
    if (rawLine.startsWith('  ') &&
        !rawLine.startsWith('    ') &&
        componentMatch != null) {
      currentKey = componentMatch.group(1);
      components[currentKey!] = <String, dynamic>{'classes': <String>[]};
      listKey = null;
      continue;
    }

    if (currentKey == null) {
      continue;
    }

    if (trimmed.startsWith('- ')) {
      if (listKey == 'classes') {
        (components[currentKey]!['classes'] as List<String>).add(
          trimmed.substring(2).trim(),
        );
      }
      continue;
    }

    final RegExpMatch? kvMatch = RegExp(
      r'^(\w+):(?:\s*(.+))?$',
    ).firstMatch(trimmed);
    if (kvMatch == null) {
      continue;
    }
    final String key = kvMatch.group(1)!;
    final String? value = kvMatch.group(2)?.trim();
    if (value == null || value.isEmpty) {
      listKey = key;
      if (key == 'classes') {
        components[currentKey]![key] = <String>[];
      }
    } else {
      listKey = null;
      components[currentKey]![key] = value;
    }
  }

  return _configsFromMap(
    components.map((String k, Map<String, dynamic> v) => MapEntry(k, v)),
  );
}

/// Reuse the consuming component's manifest instead of a separate audit list.
String defaultAuditConfigPath({
  String componentRoot = '../tdesign-flutter/tdesign-component',
}) => p.join(componentRoot, 'tool', 'components.json');

/// 从 Markdown API 文档解析 {类名: section 正文}
Map<String, String> parseMarkdownSections(String markdown) {
  final Map<String, String> sections = <String, String>{};
  for (final String part in markdown.split(RegExp(r'\n(?=### )'))) {
    final RegExpMatch? match = RegExp(r'^### (\S+)\n').firstMatch(part);
    if (match != null) {
      sections[match.group(1)!] = part;
    }
  }
  return sections;
}

/// Accept constructors grouped by name and legacy default-constructor sections.
/// Headings inside declaration code fences do not delimit the section.
String _defaultConstructorBlock(String section) {
  final lines = section.split('\n');
  final owner = RegExp(r'^### (\S+)\n').firstMatch(section)?.group(1);
  final namedStart = lines.indexWhere((line) => line.trim() == '##### $owner');
  final start =
      namedStart >= 0
          ? namedStart
          : lines.indexWhere((line) => line.trim() == '#### 默认构造方法');
  if (start < 0) return '';
  final result = <String>[];
  var inCode = false;
  for (final line in lines.skip(start + 1)) {
    if (line.trimLeft().startsWith('```')) inCode = !inCode;
    if (!inCode) {
      final heading = RegExp(r'^(#{1,5})\s+(.+)$').firstMatch(line);
      if (heading != null &&
          heading.group(1)!.length <= (namedStart >= 0 ? 5 : 4) &&
          line.trim() != '#### 参数') {
        break;
      }
    }
    result.add(line);
  }
  return result.join('\n');
}

/// Filter presentation-only rows before checking parameter contracts.
Iterable<String> _contractLines(String block) sync* {
  var details = false;
  var inTable = false;
  for (final line in block.split('\n')) {
    if (line == '<!-- api-table: details -->') {
      details = true;
      continue;
    }
    if (line.startsWith('|')) {
      inTable = true;
      if (!details) yield line;
    } else {
      if (inTable) details = false;
      inTable = false;
      yield line;
    }
  }
}

/// 读取「默认构造方法」表格中的参数名（不含公开属性 / 静态成员表）
Set<String> markdownDefaultCtorParamNames(String section) {
  final String block = _defaultConstructorBlock(section);
  final Set<String> names = <String>{};
  for (final String line in _contractLines(block)) {
    if (!line.startsWith('|') || line.startsWith('| ---')) {
      continue;
    }
    final List<String> cols = line
        .trim()
        .replaceFirst('|', '')
        .replaceFirst(RegExp(r'\|$'), '')
        .split('|');
    if (cols.isEmpty) {
      continue;
    }
    final String name = cols.first.trim();
    if (name.isEmpty || name == '参数' || name == '名称' || name == '属性') {
      continue;
    }
    names.add(name);
  }
  return names;
}

/// 构造表中类型列为 `-` 的参数名
List<String> markdownCtorParamsWithEmptyType(String section) {
  final String block = _defaultConstructorBlock(section);
  final List<String> bad = <String>[];
  for (final String line in _contractLines(block)) {
    if (!line.startsWith('|') || line.startsWith('| ---')) {
      continue;
    }
    final List<String> cols = line
        .trim()
        .replaceFirst('|', '')
        .replaceFirst(RegExp(r'\|$'), '')
        .split('|');
    if (cols.length < 2) {
      continue;
    }
    final String name = cols[0].trim();
    final String type = cols[1].trim();
    if (name.isEmpty || name == '参数' || name == '名称' || name == '属性') {
      continue;
    }
    if (type == '-') {
      bad.add(name);
    }
  }
  return bad;
}

/// 读取顶层函数「参数」表中的参数名。
Set<String> markdownFunctionParamNames(String section) {
  const String header = '#### 参数';
  if (!section.contains(header)) {
    return <String>{};
  }
  final String block =
      section.split(header).skip(1).first.split(RegExp(r'\n#### ')).first;
  final Set<String> names = <String>{};
  for (final String line in _contractLines(block)) {
    if (!line.startsWith('|') || line.startsWith('| ---')) {
      continue;
    }
    final List<String> columns = line
        .trim()
        .replaceFirst('|', '')
        .replaceFirst(RegExp(r'\|$'), '')
        .split('|');
    if (columns.isEmpty) {
      continue;
    }
    final String name = columns.first.trim();
    if (name.isNotEmpty && name != '参数' && name != '名称') {
      names.add(name);
    }
  }
  return names;
}

/// Read a return contract without borrowing a neighbouring API's table.
String? markdownReturnType(String section) {
  final headings =
      RegExp(
        r'^#{4,6} 返回值[ \t]*$',
        multiLine: true,
      ).allMatches(section).toList();
  if (headings.isEmpty) {
    return RegExp(
      r'^返回类型：`([^`]+)`',
      multiLine: true,
    ).firstMatch(section)?.group(1);
  }
  if (headings.length != 1) return null;
  final heading = headings.single;
  final depth = heading.group(0)!.split(' ').first.length;
  final tail = section.substring(heading.end);
  final boundary = RegExp('^#{1,$depth} ', multiLine: true).firstMatch(tail);
  final block = boundary == null ? tail : tail.substring(0, boundary.start);
  final lines = block.split('\n');
  final start = lines.indexWhere(
    (line) =>
        line.trim() == '| 类型 | 说明 |' ||
        line.trim() == '| 名称 | 类型 | 默认值 | 说明 | 必传 |',
  );
  if (start < 0) return null;
  final rows = <List<String>>[];
  for (final line in lines.skip(start + 1)) {
    if (!line.startsWith('|') || !line.endsWith('|')) break;
    final cells =
        line
            .substring(1, line.length - 1)
            .split(RegExp(r'(?<!\\)\|'))
            .map((cell) => cell.trim())
            .toList();
    if (cells.every((cell) => RegExp(r'^:?-+:?$').hasMatch(cell))) continue;
    rows.add(cells);
  }
  if (rows.length != 1) {
    return null;
  }
  final compact = lines[start].trim() == '| 类型 | 说明 |';
  final row = rows.single;
  if (compact) {
    return row.length == 2 ? row.first : null;
  }
  return row.length == 5 && row.first == '返回值' && row[2] == '-' && row[4] == '-'
      ? row[1]
      : null;
}

/// 校验一个顶层函数的生成文档是否完整。
List<CompletenessIssue> functionDocumentationIssues(
  String componentKey,
  ComponentInfo function,
  String section,
) {
  final List<CompletenessIssue> issues = <CompletenessIssue>[];
  final String functionName = function.name ?? '';
  final StaticMethodInfo? signature = function.topLevelFunction;
  if (signature == null) {
    return <CompletenessIssue>[
      CompletenessIssue(
        component: componentKey,
        level: 'ERROR',
        category: 'tool',
        message: '顶层函数 $functionName 缺少解析后的签名',
      ),
    ];
  }
  if (!section.contains('#### 顶层函数')) {
    issues.add(
      CompletenessIssue(
        component: componentKey,
        level: 'ERROR',
        category: 'tool',
        message: '顶层函数 $functionName 缺少函数说明',
      ),
    );
  }
  final returnType = markdownReturnType(section);
  final hasReturnContract = RegExp(
    r'^#{4,6} 返回值[ \t]*$|^返回类型：`',
    multiLine: true,
  ).hasMatch(section);
  if (!(signature.returnType == 'void' && !hasReturnContract) &&
      (returnType == null ||
          returnType
                  .replaceAll('&lt;', '<')
                  .replaceAll('&gt;', '>')
                  .replaceAll(RegExp(r'\s+'), '') !=
              (signature.returnType ?? 'dynamic').replaceAll(
                RegExp(r'\s+'),
                '',
              ))) {
    issues.add(
      CompletenessIssue(
        component: componentKey,
        level: 'ERROR',
        category: 'tool',
        message: '顶层函数 $functionName 缺少或错误的返回类型',
      ),
    );
  }

  final Set<String> sourceParams =
      signature.params
          .map((PropertyInfo parameter) => parameter.name)
          .where((String name) => name.isNotEmpty)
          .toSet();
  final Set<String> documentedParams = markdownFunctionParamNames(section);
  final Set<String> missing = sourceParams.difference(documentedParams);
  final Set<String> extra = documentedParams.difference(sourceParams);
  if (missing.isNotEmpty) {
    issues.add(
      CompletenessIssue(
        component: componentKey,
        level: 'ERROR',
        category: 'tool',
        message: '顶层函数 $functionName 文档缺少参数: ${missing.toList()..sort()}',
      ),
    );
  }
  if (extra.isNotEmpty) {
    issues.add(
      CompletenessIssue(
        component: componentKey,
        level: 'WARN',
        category: 'tool',
        message: '顶层函数 $functionName 文档多出参数: ${extra.toList()..sort()}',
      ),
    );
  }
  return issues;
}

/// Check structured alias tables without borrowing presentation-only rows.
List<CompletenessIssue> typedefDocumentationIssues(
  String componentKey,
  ComponentInfo alias,
  String section,
) {
  final failures = <String>[];
  final contract = apiTypedefContract(alias.typedefDefinition);
  bool matchesInline(String label, String expected) {
    final actual = RegExp(
      '^$label：`([^`]+)`',
      multiLine: true,
    ).firstMatch(section)?.group(1);
    return expected.isEmpty
        ? actual == null
        : actual == sanitizeApiType(expected);
  }

  final rows = <List<String>>[];
  var inReturns = false;
  for (final line in _contractLines(section)) {
    if (line.startsWith('#### 返回值'))
      inReturns = true;
    else if (line.startsWith('#### '))
      inReturns = false;
    if (!inReturns && line.startsWith('|') && line.endsWith('|')) {
      final cells = apiTableCells(line);
      if (cells.isNotEmpty &&
          cells.first != '名称' &&
          cells.first.replaceAll('-', '').isNotEmpty)
        rows.add(cells);
    }
  }
  if (!matchesInline('类型参数', contract.parameters)) failures.add('类型参数');
  final callback = alias.typedefFunction;
  if (callback == null) {
    if (rows.length != 1 ||
        rows.single.length != 5 ||
        rows.single[0] != alias.name ||
        rows.single[1] != sanitizeApiType(contract.target) ||
        rows.single[2] != '-' ||
        rows.single[4] != '-')
      failures.add('目标类型');
  } else {
    final shape = callback.params
        .where((parameter) => !parameter.isNamed)
        .map((parameter) => parameter.name)
        .join(', ');
    if (!section.contains('#### 回调参数\n')) failures.add('回调参数');
    if (!matchesInline('位置参数', shape)) failures.add('位置参数');
    if (!matchesInline('回调类型参数', contract.callbackParameters))
      failures.add('回调类型参数');
    if (section.contains('可空：是。') != contract.nullable) failures.add('可空性');
    if (markdownReturnType(section) !=
        sanitizeApiType(callback.returnType ?? 'dynamic'))
      failures.add('返回值');
    if (rows.length != callback.params.length) failures.add('参数数量');
    for (var index = 0; index < callback.params.length; index++) {
      final parameter = callback.params[index];
      if (index >= rows.length ||
          rows[index].length != 5 ||
          rows[index][0] != parameter.name ||
          rows[index][1] != sanitizeApiType(parameter.type) ||
          rows[index][2] != sanitizeApiType(parameter.defaultValue) ||
          rows[index][4] != (parameter.isRequired ? '是' : '否'))
        failures.add('参数 ${parameter.name}');
    }
  }
  return failures
      .map(
        (failure) => CompletenessIssue(
          component: componentKey,
          level: 'ERROR',
          category: 'tool',
          message: 'typedef ${alias.name} 缺少或错误的$failure',
        ),
      )
      .toList();
}

/// 跨文件重复 enum/typedef（返回 issue，不打印）
List<CompletenessIssue> duplicateAuxiliaryIssues(
  String componentKey,
  List<ParsedComponentInfoInfo> parsed,
) {
  final Map<String, List<String>> locations = <String, List<String>>{};
  for (final ParsedComponentInfoInfo item in parsed) {
    final String? kind = item.componentInfo?.kind;
    if (kind != 'enum' && kind != 'typedef') {
      continue;
    }
    final String? name = item.componentInfo?.name;
    if (name == null || name.isEmpty) {
      continue;
    }
    final String file = item.componentInfo?.sourceFile ?? 'unknown';
    locations.putIfAbsent('$kind:$name', () => <String>[]).add(file);
  }

  final List<CompletenessIssue> issues = <CompletenessIssue>[];
  for (final MapEntry<String, List<String>> entry in locations.entries) {
    final Set<String> uniqueFiles = entry.value.toSet();
    if (uniqueFiles.length <= 1) {
      continue;
    }
    final List<String> parts = entry.key.split(':');
    final String kindLabel = parts[0] == 'enum' ? 'enum' : 'typedef';
    final String typeName = parts.length > 1 ? parts[1] : entry.key;
    issues.add(
      CompletenessIssue(
        component: componentKey,
        level: 'ERROR',
        category: 'source',
        message: '源码重复定义 $kindLabel `$typeName`: ${uniqueFiles.join(', ')}',
      ),
    );
  }
  return issues;
}

/// enum 成员缺少源码注释（返回 issue，不打印）
List<CompletenessIssue> enumMemberIntroductionIssues(
  String componentKey,
  List<ParsedComponentInfoInfo> parsed,
) {
  final List<CompletenessIssue> issues = <CompletenessIssue>[];
  for (final ParsedComponentInfoInfo item in parsed) {
    final ComponentInfo? componentInfo = item.componentInfo;
    if (componentInfo?.kind != 'enum') {
      continue;
    }
    if (componentInfo?.isSimpleEnum ?? false) {
      continue;
    }
    final String enumName = componentInfo?.name ?? '';
    if (enumName.isEmpty) {
      continue;
    }
    final List<String> missingMembers =
        componentInfo!.enumMembers
            .where(
              (EnumMemberInfo member) =>
                  member.name.isNotEmpty && member.introduction.trim().isEmpty,
            )
            .map((EnumMemberInfo member) => member.name)
            .toList()
          ..sort();
    if (missingMembers.isEmpty) {
      continue;
    }
    issues.add(
      CompletenessIssue(
        component: componentKey,
        level: 'WARN',
        category: 'source',
        message: 'enum $enumName 的枚举成员缺少说明，请在源码中补充 /// 注释: $missingMembers',
      ),
    );
  }
  return issues;
}

/// 用 analyzer AST 解析源码，对比已生成的 *_api.md
Future<List<CompletenessIssue>> auditComponent({
  required String componentRoot,
  required ComponentAuditConfig config,
  bool quiet = true,
}) async {
  final List<CompletenessIssue> issues = <CompletenessIssue>[];
  final String root = p.normalize(componentRoot);
  final String apiPath = p.join(
    root,
    'example/assets/api/${config.folderName}_api.md',
  );
  final File apiFile = File(apiPath);

  if (!apiFile.existsSync()) {
    issues.add(
      CompletenessIssue(
        component: config.componentKey,
        level: 'ERROR',
        category: 'scope',
        message: '缺少文档文件 ${p.basename(apiPath)}',
      ),
    );
    return issues;
  }

  final Map<String, String> sections = parseMarkdownSections(
    await apiFile.readAsString(),
  );

  final String basePath =
      root.endsWith(Platform.pathSeparator)
          ? root
          : '$root${Platform.pathSeparator}';

  final List<ParsedComponentInfoInfo> parsed = await SmartCreator(
    isFileMode: config.sourceIsFile,
    onlyApi: true,
    nameList: config.classNames,
    basePath: basePath,
    path: config.sourceFolder,
    folderName: config.folderName,
  ).parseOnly(quiet: quiet);

  final Map<String, ParsedComponentInfoInfo> parsedByName =
      <String, ParsedComponentInfoInfo>{
        for (final ParsedComponentInfoInfo item in parsed)
          if (item.componentInfo?.name != null) item.componentInfo!.name!: item,
      };

  issues.addAll(duplicateAuxiliaryIssues(config.componentKey, parsed));
  issues.addAll(enumMemberIntroductionIssues(config.componentKey, parsed));

  for (final String className in config.classNames) {
    if (!sections.containsKey(className)) {
      final ParsedComponentInfoInfo? info = parsedByName[className];
      if (info == null) {
        issues.add(
          CompletenessIssue(
            component: config.componentKey,
            level: 'ERROR',
            category: 'scope',
            message: '--name 中的 $className 未出现在文档且 AST 未解析到定义',
          ),
        );
      } else {
        final String kind = info.componentInfo?.kind ?? 'class';
        issues.add(
          CompletenessIssue(
            component: config.componentKey,
            level: kind == 'enum' || kind == 'typedef' ? 'WARN' : 'ERROR',
            category: 'scope',
            message: '--name 中的 $className 未出现在文档',
          ),
        );
      }
      continue;
    }

    final ParsedComponentInfoInfo? info = parsedByName[className];
    if (info == null) {
      issues.add(
        CompletenessIssue(
          component: config.componentKey,
          level: 'WARN',
          category: 'source',
          message: '$className 在配置中但 AST 未在当前目录解析到定义',
        ),
      );
      continue;
    }

    final String kind = info.componentInfo?.kind ?? 'class';
    final String section = sections[className]!;

    if (kind == 'enum') {
      if (!section.contains('#### 枚举值')) {
        issues.add(
          CompletenessIssue(
            component: config.componentKey,
            level: 'WARN',
            category: 'tool',
            message: 'enum $className 缺少枚举值表',
          ),
        );
      }
      continue;
    }

    if (kind == 'typedef') {
      issues.addAll(
        typedefDocumentationIssues(
          config.componentKey,
          info.componentInfo!,
          section,
        ),
      );
      continue;
    }

    if (kind == 'function') {
      issues.addAll(
        functionDocumentationIssues(
          config.componentKey,
          info.componentInfo!,
          section,
        ),
      );
      continue;
    }

    final Set<String> srcCtorParams =
        info.propertyList
            .map((PropertyInfo e) => e.name)
            .where((n) => n.isNotEmpty)
            .toSet();
    final bool hasInstanceMethods =
        info.componentInfo?.instanceMethodList.isNotEmpty ?? false;

    if (srcCtorParams.isEmpty) {
      if (hasInstanceMethods) {
        issues.add(
          CompletenessIssue(
            component: config.componentKey,
            level: 'INFO',
            category: 'source',
            message: '$className 无默认构造参数（如 abstract class），跳过构造参数对比',
          ),
        );
      }
      continue;
    }

    final Set<String> docCtorParams = markdownDefaultCtorParamNames(section);
    final Set<String> missingInDoc = srcCtorParams.difference(docCtorParams);
    final Set<String> extraInDoc = docCtorParams.difference(srcCtorParams);

    if (missingInDoc.isNotEmpty) {
      issues.add(
        CompletenessIssue(
          component: config.componentKey,
          level: 'ERROR',
          category: 'tool',
          message: '$className 文档缺少构造参数: ${missingInDoc.toList()..sort()}',
        ),
      );
    }
    if (extraInDoc.isNotEmpty) {
      issues.add(
        CompletenessIssue(
          component: config.componentKey,
          level: 'WARN',
          category: 'tool',
          message: '$className 文档多出非构造参数: ${extraInDoc.toList()..sort()}',
        ),
      );
    }

    final List<String> emptyTypes = markdownCtorParamsWithEmptyType(section);
    if (emptyTypes.isNotEmpty) {
      issues.add(
        CompletenessIssue(
          component: config.componentKey,
          level: 'WARN',
          category: 'tool',
          message: '$className 构造参数类型未解析(-): $emptyTypes',
        ),
      );
    }
  }

  if (issues.where((CompletenessIssue i) => i.category != 'ok').isEmpty) {
    issues.add(
      CompletenessIssue(
        component: config.componentKey,
        level: 'INFO',
        category: 'ok',
        message: '未发现完备性问题',
      ),
    );
  }

  return issues;
}

/// 批量审计并打印报告；返回 ERROR 数量
Future<int> runCompletenessAudit({
  required String componentRoot,
  List<ComponentAuditConfig>? configs,
  bool quiet = true,
}) async {
  final List<ComponentAuditConfig> auditConfigs =
      configs ??
      await loadAuditConfigsFromFile(
        defaultAuditConfigPath(componentRoot: componentRoot),
      );
  int errorCount = 0;
  int warnCount = 0;

  stdout.writeln('=' * 60);
  stdout.writeln('API 文档完备性检测（analyzer AST，${auditConfigs.length} 组件）');
  stdout.writeln('=' * 60);

  for (final ComponentAuditConfig config in auditConfigs) {
    final List<CompletenessIssue> issues = await auditComponent(
      componentRoot: componentRoot,
      config: config,
      quiet: quiet,
    );
    final String apiPath = p.join(
      componentRoot,
      'example/assets/api/${config.folderName}_api.md',
    );
    Map<String, String> sections = <String, String>{};
    if (File(apiPath).existsSync()) {
      sections = parseMarkdownSections(await File(apiPath).readAsString());
    }

    stdout.writeln('\n## ${config.componentKey}');
    stdout.writeln(
      '   文档条目 (${sections.length}): ${sections.keys.take(8).join(', ')}${sections.length > 8 ? '...' : ''}',
    );

    final bool hasOk = issues.any((CompletenessIssue i) => i.category == 'ok');
    if (hasOk) {
      stdout.writeln('   ✅ 未发现完备性问题');
    }
    for (final CompletenessIssue issue in issues) {
      if (issue.category == 'ok') {
        continue;
      }
      final String icon = switch (issue.level) {
        'ERROR' => '❌',
        'WARN' => '⚠️',
        _ => 'ℹ️',
      };
      stdout.writeln('   $icon [${issue.category}] ${issue.message}');
      if (issue.level == 'ERROR') {
        errorCount++;
      } else if (issue.level == 'WARN') {
        warnCount++;
      }
    }
  }

  stdout.writeln('\n${'=' * 60}');
  stdout.writeln('汇总: ERROR=$errorCount, WARN=$warnCount');
  stdout.writeln('=' * 60);
  return errorCount;
}
