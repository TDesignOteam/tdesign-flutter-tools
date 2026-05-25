import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'model.dart';
import 'smart_create.dart';

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
  });

  final String componentKey;
  final List<String> classNames;
  /// 相对 component 根目录，如 lib/src/components/picker
  final String sourceFolder;
  final String folderName;
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
    if (decoded is Map<String, dynamic> && decoded['components'] is Map) {
      return _configsFromMap(
          Map<String, dynamic>.from(decoded['components'] as Map));
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
    final Map<String, dynamic> map =
        Map<String, dynamic>.from(entry.value as Map);
    final String? folderName = map['folder_name'] as String?;
    final String? sourceFolder = map['source_folder'] as String?;
    final dynamic classesRaw = map['classes'];
    if (folderName == null ||
        sourceFolder == null ||
        classesRaw is! List ||
        classesRaw.isEmpty) {
      throw ArgumentError('组件 ${entry.key} 缺少 folder_name / source_folder / classes');
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

    final RegExpMatch? componentMatch =
        RegExp(r'^(\w+):$').firstMatch(trimmed);
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
        (components[currentKey]!['classes'] as List<String>)
            .add(trimmed.substring(2).trim());
      }
      continue;
    }

    final RegExpMatch? kvMatch =
        RegExp(r'^(\w+):(?:\s*(.+))?$').firstMatch(trimmed);
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

/// 默认审计配置路径（相对 tools 仓库根目录）
String defaultAuditConfigPath() => '.github/config/tdesign_api.yaml';

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

/// 读取「默认构造方法」表格中的参数名（不含公开属性 / 静态成员表）
Set<String> markdownDefaultCtorParamNames(String section) {
  const String header = '#### 默认构造方法';
  if (!section.contains(header)) {
    return <String>{};
  }
  final String block =
      section.split(header).skip(1).first.split(RegExp(r'\n#### ')).first;
  final Set<String> names = <String>{};
  for (final String line in block.split('\n')) {
    if (!line.startsWith('|') || line.startsWith('| ---')) {
      continue;
    }
    final List<String> cols =
        line.trim().replaceFirst('|', '').replaceFirst(RegExp(r'\|$'), '').split('|');
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
  const String header = '#### 默认构造方法';
  if (!section.contains(header)) {
    return <String>[];
  }
  final String block =
      section.split(header).skip(1).first.split(RegExp(r'\n#### ')).first;
  final List<String> bad = <String>[];
  for (final String line in block.split('\n')) {
    if (!line.startsWith('|') || line.startsWith('| ---')) {
      continue;
    }
    final List<String> cols =
        line.trim().replaceFirst('|', '').replaceFirst(RegExp(r'\|$'), '').split('|');
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
        message:
            '源码重复定义 $kindLabel `$typeName`: ${uniqueFiles.join(', ')}',
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
  final String apiPath =
      p.join(root, 'example/assets/api/${config.folderName}_api.md');
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

  final Map<String, String> sections =
      parseMarkdownSections(await apiFile.readAsString());

  final String basePath = root.endsWith(Platform.pathSeparator)
      ? root
      : '$root${Platform.pathSeparator}';

  final List<ParsedComponentInfoInfo> parsed = await SmartCreator(
    isFileMode: false,
    onlyApi: true,
    nameList: config.classNames,
    basePath: basePath,
    path: config.sourceFolder,
    folderName: config.folderName,
    isGrammarParser: false,
  ).parseOnly(quiet: quiet);

  final Map<String, ParsedComponentInfoInfo> parsedByName =
      <String, ParsedComponentInfoInfo>{
    for (final ParsedComponentInfoInfo item in parsed)
      if (item.componentInfo?.name != null) item.componentInfo!.name!: item,
  };

  issues.addAll(duplicateAuxiliaryIssues(config.componentKey, parsed));

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
      if (!section.contains('#### 类型定义')) {
        issues.add(
          CompletenessIssue(
            component: config.componentKey,
            level: 'WARN',
            category: 'tool',
            message: 'typedef $className 缺少类型定义',
          ),
        );
      }
      continue;
    }

  final Set<String> srcCtorParams =
      info.propertyList.map((PropertyInfo e) => e.name).where((n) => n.isNotEmpty).toSet();
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
        message:
            '$className 文档缺少构造参数: ${missingInDoc.toList()..sort()}',
      ),
    );
  }
  if (extraInDoc.isNotEmpty) {
    issues.add(
      CompletenessIssue(
        component: config.componentKey,
        level: 'WARN',
        category: 'tool',
        message:
            '$className 文档多出非构造参数: ${extraInDoc.toList()..sort()}',
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
  final List<ComponentAuditConfig> auditConfigs = configs ??
      await loadAuditConfigsFromFile(
        p.join(Directory.current.path, defaultAuditConfigPath()),
      );
  int errorCount = 0;
  int warnCount = 0;

  stdout.writeln('=' * 60);
  stdout.writeln('API 文档完备性检测（analyzer AST，5 组件）');
  stdout.writeln('=' * 60);

  for (final ComponentAuditConfig config in auditConfigs) {
    final List<CompletenessIssue> issues = await auditComponent(
      componentRoot: componentRoot,
      config: config,
      quiet: quiet,
    );
    final String apiPath =
        p.join(componentRoot, 'example/assets/api/${config.folderName}_api.md');
    Map<String, String> sections = <String, String>{};
    if (File(apiPath).existsSync()) {
      sections = parseMarkdownSections(await File(apiPath).readAsString());
    }

    stdout.writeln('\n## ${config.componentKey}');
    stdout.writeln(
      '   文档条目 (${sections.length}): ${sections.keys.take(8).join(', ')}${sections.length > 8 ? '...' : ''}',
    );

    final bool hasOk =
        issues.any((CompletenessIssue i) => i.category == 'ok');
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
