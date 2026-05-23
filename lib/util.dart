import 'package:analyzer/dart/ast/ast.dart';
import 'package:ansicolor/ansicolor.dart';

import 'model.dart';

// 驼峰转下划线
String CamelToUnderline(String input) {
  RegExp exp = RegExp(r'(?<=[a-z])[A-Z]');
  return input.replaceAllMapped(exp, (Match m) => ('_' + m.group(0)!)).toLowerCase();
}

// 移除注释中的///
String removeDocumentationComment(String element) {
  final regex = RegExp(r'\/{3}');
  return element.replaceAll(regex, '').trim();
}

/// 获取形式参数名称（兼容 DefaultFormalParameter 包裹 FieldFormalParameter）
String formalParameterName(FormalParameter param) {
  if (param is DefaultFormalParameter) {
    return formalParameterName(param.parameter);
  }
  return param.name?.lexeme ?? '';
}

/// 从构造/方法参数 AST 提取类型字符串
String extractFormalParameterType(
  FormalParameter param, {
  Map<String, PropertyInfo>? superClassFieldMaps,
}) {
  FormalParameter target = param;
  if (param is DefaultFormalParameter) {
    target = param.parameter;
  }
  if (target is SimpleFormalParameter) {
    return target.type?.toString() ?? '';
  }
  if (target is FieldFormalParameter) {
    return target.type?.toString() ?? '';
  }
  if (target is SuperFormalParameter) {
    final String? explicitType = target.type?.toString();
    if (explicitType != null && explicitType.isNotEmpty) {
      return explicitType;
    }
    final String? superParamName = formalParameterName(target);
    if (superParamName != null &&
        superClassFieldMaps != null &&
        superClassFieldMaps.containsKey(superParamName)) {
      final String parentType = superClassFieldMaps[superParamName]!.type;
      if (parentType.isNotEmpty) {
        return parentType;
      }
    }
    // `super.key` 未写显式类型时，文档统一展示为 Key?
    if (superParamName == 'key') {
      return 'Key?';
    }
    return '';
  }
  return '';
}

/// 从构造/方法参数 AST 提取默认值源码
String? extractFormalParameterDefaultValue(FormalParameter param) {
  if (param is DefaultFormalParameter) {
    return param.defaultValue?.toSource();
  }
  return null;
}

/// 规范化 API 文档中的默认值展示
String formatDefaultValueForDoc(
  String? raw, {
  required String paramName,
  required bool isRequired,
}) {
  if (raw == null || raw.trim().isEmpty) {
    return '-';
  }
  var value = raw.trim();
  // `this.fieldName` 会被误识别为默认值
  if (value == paramName || value == 'this.$paramName') {
    return '-';
  }
  if ((value.startsWith("'") && value.endsWith("'")) ||
      (value.startsWith('"') && value.endsWith('"'))) {
    if (value.length >= 2) {
      value = value.substring(1, value.length - 1);
    }
  }
  return value;
}

/// 清理 Markdown 表格单元格，避免破坏表格结构
String sanitizeTableCell(String? text) {
  if (text == null || text.isEmpty) {
    return '-';
  }
  return text
      .replaceAll('|', '\\|')
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// 格式化方法参数列表，便于写入 Markdown 表格
String formatMethodParams(List<PropertyInfo> params) {
  if (params.isEmpty) {
    return '-';
  }
  final buffer = StringBuffer();
  for (final PropertyInfo element in params) {
    final isRequired = element.isRequired;
    final type = element.type;
    final name = element.name;
    if (type.isNotEmpty) {
      buffer.write('${isRequired ? 'required ' : ''}$type $name');
    } else {
      buffer.write('${isRequired ? 'required ' : ''}$name');
    }
    buffer.write(', ');
  }
  final result = buffer.toString().trim();
  if (result.endsWith(',')) {
    return result.substring(0, result.length - 1).trim();
  }
  return result.isEmpty ? '-' : result;
}

/// 检测 folder 模式下跨文件重复的 enum/typedef 定义（源码规范问题，不去重掩盖）
void reportDuplicateAuxiliaryDefinitions(List<ParsedComponentInfoInfo> items) {
  final Map<String, List<String>> locations = <String, List<String>>{};
  for (final ParsedComponentInfoInfo item in items) {
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
  final AnsiPen pen = AnsiPen()..yellow(bold: true);
  for (final MapEntry<String, List<String>> entry in locations.entries) {
    if (entry.value.length <= 1) {
      continue;
    }
    final List<String> parts = entry.key.split(':');
    final String kindLabel = parts[0] == 'enum' ? 'enum' : 'typedef';
    final String typeName = parts.length > 1 ? parts[1] : entry.key;
    final String files = entry.value.toSet().join(', ');
    print(pen(
      'Warning: 源码重复定义 $kindLabel `$typeName`，出现在: $files',
    ));
    print(pen('  建议: 将 `$typeName` 收敛到单一文件定义，避免文档重复与维护漂移'));
  }
}

// 是否是demo文件
bool isValidDemoFile(String fileName) {
  final regex = RegExp(r'demo[0-9]+.dart');
  return regex.hasMatch(fileName);
}

// 是否是demo类
bool isValidDemoClass(String className) {
  final regex = RegExp(r'.*Demo[0-9]+$');
  return regex.hasMatch(className);
}

