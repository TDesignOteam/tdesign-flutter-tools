import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'model.dart';
import 'util.dart';

// ignore_for_file: always_specify_types
class DemoRule {
  DemoRule({this.analysisResult, this.basePath, this.filePath});

  final ParsedUnitResult? analysisResult;
  final String? basePath; // ui_component 目录的路径
  final String? filePath; // 组件demo的dart文件路径

  DemoInfo analyse() {
    // int startTime1 = DateTime.now().microsecondsSinceEpoch;
    final DemoVisitor visitor = DemoVisitor(
      basePath: basePath,
      filePath: filePath,
    );
    // analysisResult.libraryElement.accept(visitor);
    analysisResult!.unit.accept(visitor);
    // int endTime = DateTime.now().microsecondsSinceEpoch;
    // print('analyse 执行用时: ${((endTime - startTime1) / 1000).floor()}ms');
    // print('${basename(filePath)} 生成完毕');
    return visitor.demoInfo;
  }
}

class DemoVisitor extends RecursiveAstVisitor<void> {
  DemoVisitor({
    this.basePath,
    this.filePath,
  });

  final String? basePath;
  final String? filePath;
  DemoInfo demoInfo = DemoInfo();

  @override
  void visitAnnotation(Annotation node) {
    node.visitChildren(this);
    // print('注解[${basename(filePath)}]: ${node.typeArguments?.length ?? 0}, ${node.name}, ${node.runtimeType},${node.childEntities.length}, ');
    if (node.name.toString() == 'Priority' && node.childEntities.isNotEmpty) {
      demoInfo.isValid = true;
      for (final item in node.childEntities) {
        // print('${item.runtimeType}, $item');
        if (item is ArgumentList) {
          // print('注解的值：${item.arguments[0]}, $item');
          try {
            demoInfo.priority = int.parse(item.arguments[0].toString());
          } catch (e) {
            print('Priority 解析失败');
          }
        }
      }
    } else if (node.name.toString() == 'DemoItemStyle' && node.childEntities.isNotEmpty) {
      demoInfo.isValid = true;
      for (final item in node.childEntities) {
        // print('${item.runtimeType}, $item');
        if (item is ArgumentList) {
          // print('注解的值：${item.arguments[0]}, $item');
          // demoInfo.displayStyle = item.arguments[0].toString().replaceAll('ItemStyle.', '');
        }
      }
    }
  }

  @override
  void visitComment(Comment node) {
    node.visitChildren(this);
    List<String> introductions = node.tokens.map((e) => removeDocumentationComment(e.toString())).toList();
    demoInfo.introductions = introductions;
    // String tmp = '';
    // if (node.childEntities.isNotEmpty) {
    //   tmp = node.childEntities.map((e) => e.toString()).toList().join('|');
    // }
    // List<String> strList = [];
    // strList.add(node.isDocumentation.toString());
    // strList.add(token);
    // strList.add(node.runtimeType.toString());
    // strList.add(node.childEntities.length.toString());
    // strList.add(tmp);
    // print('注释[]: ${strList.join(', ')}');
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    node.visitChildren(this);
    // print('类[${basename(filePath)}]: ${node.name}');
    if (isValidDemoClass(node.name.toString()) && demoInfo.isValid) {
      demoInfo.name = node.name.toString();
    }
  }
}
