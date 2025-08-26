import 'package:analyzer/dart/element/type.dart';
// import 'package:analyzer/dart/element/element.dart';
import 'package:ansicolor/ansicolor.dart';

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
