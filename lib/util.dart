import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
// import 'package:analyzer/dart/element/element.dart';
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

/// 从构造/方法参数 AST 提取类型字符串
String extractFormalParameterType(FormalParameter param) {
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
    // `super.key` 未写显式类型时，文档统一展示为 Key?
    if (target.name?.lexeme == 'key') {
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

bool isEnum(DartType targetType) => targetType is InterfaceType && targetType.element.kind.name == 'ENUM';

bool hasType(List<InterfaceType> superTypes, String type) => superTypes.any((superType) => superType.getDisplayString(withNullability: false) == type);

bool isWidget(List<InterfaceType> superTypes) => hasType(superTypes, 'Widget');

class Debug {
  bool isEnable = false;

  Debug(String msg) {
    if (isEnable) {
      print(msg);
    }
  }

  Debug.green(String msg) {
    if (isEnable) {
      AnsiPen pen = AnsiPen()..green(bold: true);
      print(pen(msg));
    }
  }

  Debug.red(String msg) {
    if (isEnable) {
      AnsiPen pen = AnsiPen()..red(bold: true);
      print(pen(msg));
    }
  }

  Debug.yellow(String msg) {
    if (isEnable) {
      AnsiPen pen = AnsiPen()..yellow(bold: true);
      print(pen(msg));
    }
  }

  Debug.black(String msg) {
    if (isEnable) {
      AnsiPen pen = AnsiPen()..black(bold: true);
      print(pen(msg));
    }
  }

  Debug.white(String msg) {
    if (isEnable) {
      AnsiPen pen = AnsiPen()..white(bold: true);
      print(pen(msg));
    }
  }

  Debug.blue(String msg) {
    if (isEnable) {
      AnsiPen pen = AnsiPen()..blue(bold: true);
      print(pen(msg));
    }
  }
}
