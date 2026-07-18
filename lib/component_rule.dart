import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:collection/collection.dart';

import 'model.dart';
import 'util.dart';

typedef OnParsedComponentInfoInfo = void Function(ParsedComponentInfoInfo info);

String _cleanDocComment(Comment? comment) {
  if (comment == null) {
    return '';
  }
  return comment.tokens
      .map((token) => removeDocumentationComment(token.toString()))
      .where((line) => line.trim().isNotEmpty)
      .join('\n')
      .trim();
}

Map<String, String> _extractParameterDocs(Comment? comment) {
  final Map<String, String> result = <String, String>{};
  final String text = _cleanDocComment(comment);
  if (text.isEmpty) {
    return result;
  }

  String? currentName;
  for (final String rawLine in text.split('\n')) {
    final String line = rawLine.trim();
    final RegExpMatch? match = RegExp(
      r'^\[([^\]]+)\]\s*(.*)$',
    ).firstMatch(line);
    if (match != null) {
      currentName = match.group(1)?.trim();
      final String description = match.group(2)?.trim() ?? '';
      if (currentName != null && currentName.isNotEmpty) {
        result[currentName] = description;
      }
    } else if (currentName != null && line.isNotEmpty) {
      result[currentName] = '${result[currentName]} $line'.trim();
    }
  }
  return result;
}

String _extractMainDoc(Comment? comment) {
  final String text = _cleanDocComment(comment);
  if (text.isEmpty) {
    return '';
  }

  final List<String> lines = <String>[];
  for (final String rawLine in text.split('\n')) {
    final String line = rawLine.trim();
    if (RegExp(r'^\[[^\]]+\]').hasMatch(line)) {
      break;
    }
    if (line.isNotEmpty) {
      lines.add(line);
    }
  }
  return lines.join('\n').trim();
}

FormalParameter _unwrapDefaultParameter(FormalParameter parameter) {
  if (parameter is DefaultFormalParameter) {
    return parameter.parameter;
  }
  return parameter;
}

String _parameterType(FormalParameter parameter) {
  final FormalParameter normalParameter = _unwrapDefaultParameter(parameter);
  if (normalParameter is SimpleFormalParameter) {
    return normalParameter.type?.toSource() ?? '';
  }
  if (normalParameter is FieldFormalParameter) {
    return normalParameter.type?.toSource() ?? '';
  }
  if (normalParameter is SuperFormalParameter) {
    return normalParameter.type?.toSource() ?? '';
  }
  if (normalParameter is FunctionTypedFormalParameter) {
    return normalParameter.returnType?.toSource() ?? 'Function';
  }
  return '';
}

String _parameterDefaultValue(FormalParameter parameter) {
  if (parameter is DefaultFormalParameter && parameter.defaultValue != null) {
    return parameter.defaultValue!.toSource();
  }
  return '-';
}

Comment? _parameterDocumentationComment(FormalParameter parameter) {
  final FormalParameter normalParameter = _unwrapDefaultParameter(parameter);
  if (normalParameter is NormalFormalParameter) {
    return normalParameter.documentationComment;
  }
  return null;
}

PropertyInfo _propertyFromParameter(
  FormalParameter parameter, {
  Map<String, String> parameterDocs = const <String, String>{},
}) {
  final PropertyInfo item = PropertyInfo();
  item.name = parameter.name?.lexeme.toString() ?? '';
  item.type = _parameterType(parameter);
  item.isRequired =
      parameter.isRequired || parameter.toSource().startsWith('@required');
  item.isNamed = parameter.isNamed;
  item.defaultValue = _parameterDefaultValue(parameter);

  final String inlineDoc = _cleanDocComment(
    _parameterDocumentationComment(parameter),
  );
  final String blockDoc = parameterDocs[item.name] ?? '';
  item.introduction = inlineDoc.isNotEmpty ? inlineDoc : blockDoc;
  return item;
}

// ignore_for_file: always_specify_types
class ComponentRule {
  ComponentRule({
    this.parsedUnitResult,
    this.startTime,
    this.nameList,
    this.basePath,
    this.folderName,
    this.isMerge,
    this.sourceFileName,
  });

  final ParsedUnitResult? parsedUnitResult; //词法分析
  final List<String>? nameList;
  final String? basePath;
  final String? folderName;
  final String? sourceFileName;
  final int? startTime;
  final bool? isMerge;

  List<ParsedComponentInfoInfo> analyse() {
    List<ParsedComponentInfoInfo> parsedComponentInfoList = [];
    int startTime1 = DateTime.now().microsecondsSinceEpoch;
    final ComponentAstVisitor visitor = ComponentAstVisitor(
      nameList: nameList,
      basePath: basePath,
      folderName: folderName,
      onParsedComponentInfoInfo: (ParsedComponentInfoInfo info) {
        parsedComponentInfoList.add(info);
        Debug.red('添加解析结果：${info.componentInfo!.name}');
      },
      sourceFileName: sourceFileName,
    );
    parsedUnitResult!.unit.accept(visitor);
    // int endTime1 = DateTime.now().microsecondsSinceEpoch;
    // print('分析完毕!  用时: ${((endTime1 - startTime1) / 1000).floor()}ms');
    // analysisResult.unit.accept(visitor);

    int endTime = DateTime.now().microsecondsSinceEpoch;
    print('analyse 执行用时: ${((endTime - startTime1) / 1000).floor()}ms');
    // print('${nameList.join(',')} 生成完毕!  用时: ${((endTime - startTime) / 1000).floor()}ms');
    print('$sourceFileName 生成完毕');
    return parsedComponentInfoList;
  }
}

class ComponentAstVisitor extends RecursiveAstVisitor<void> {
  ComponentAstVisitor({
    this.onParsedComponentInfoInfo,
    this.nameList,
    this.basePath,
    this.folderName,
    this.sourceFileName,
  });

  final List<String>? nameList;
  final String? basePath;
  final String? folderName;
  final String? sourceFileName;
  final OnParsedComponentInfoInfo? onParsedComponentInfoInfo;
  ComponentInfo? componentInfo;
  List<PropertyInfo> propertyList = [];
  Map<String, PropertyInfo> fieldMap = {};

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    node.visitChildren(this);
    // 无命名构造函数
    // List childEntities = node.childEntities.toList();
    // bool isNormalConstructor = childEntities.isNotEmpty && nameList!.contains(childEntities[0].toString());
    // bool isConstConstructor = childEntities.length >= 2 && childEntities[0].toString() == 'const' && nameList!.contains(childEntities[1].toString());
    final Map<String, String> parameterDocs = _extractParameterDocs(
      node.documentationComment,
    );
    if (node.name == null) {
      for (final FormalParameter param in node.parameters.parameters) {
        List<String> strList = [];
        strList.add('identifier:' + (param.name?.lexeme.toString() ?? ""));
        strList.add('isNamed:' + param.isNamed.toString());
        strList.add('isOptional:' + param.isOptional.toString());
        strList.add('isOptionalNamed:' + param.isOptionalNamed.toString());
        strList.add(
          'isOptionalPositional:' + param.isOptionalPositional.toString(),
        );
        strList.add('isPositional:' + param.isPositional.toString());
        strList.add('isRequired:' + param.isRequired.toString());
        strList.add('isRequiredNamed:' + param.isRequiredNamed.toString());
        strList.add(
          'isRequiredPositional:' + param.isRequiredPositional.toString(),
        );
        strList.add('requiredKeyword:' + param.requiredKeyword.toString());
        strList.add('declaredElement:' + param.declaredElement.toString());
        strList.add('parent:' + param.toSource().toString());
        strList.add('beginToken:' + param.beginToken.toString());
        strList.add('endToken:' + param.endToken.toString());
        String tmp = '';
        if (param.childEntities.isNotEmpty) {
          tmp = param.childEntities.map((e) => e.toString()).toList().join('|');
        }
        strList.add('childEntities:' + tmp);
        Debug.yellow('构造参数[$folderName]: ${strList.join(', ')}');
        PropertyInfo item = _propertyFromParameter(
          param,
          parameterDocs: parameterDocs,
        );
        propertyList.add(item);
      }
    } else if (!node.name.toString().startsWith('_')) {
      // 记录工厂构造方法
      StaticMethodInfo staticMethodInfo = new StaticMethodInfo();
      staticMethodInfo.name = node.name.toString();
      staticMethodInfo.introduction = _extractMainDoc(
        node.documentationComment,
      );
      // staticMethodInfo.returnType = node.returnType.type.toString();
      node.parameters.parameters.forEach((element) {
        PropertyInfo info = _propertyFromParameter(
          element,
          parameterDocs: parameterDocs,
        );
        staticMethodInfo.params.add(info);
      });
      componentInfo ??= ComponentInfo();
      componentInfo!.constructorMethodList.add(staticMethodInfo);
    }
    String tmp = '';
    if (node.childEntities.isNotEmpty) {
      tmp = node.childEntities.map((e) => e.toString()).toList().join('|');
    }
    List<String> strList = [];
    strList.add(node.firstTokenAfterCommentAndMetadata.toString());
    strList.add(
      node.parameters.parameters
          .map((e) => e.name?.lexeme.toString() ?? "")
          .toList()
          .join('|'),
    );
    strList.add(node.childEntities.length.toString());
    strList.add(tmp);
    strList.add(node.beginToken.toString());
    strList.add(node.name.toString());
    // strList.add(node.toSource());
    Debug.green('构造函数[$folderName]: ${strList.join(', ')}');
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    node.visitChildren(this);
    String tmp = '';
    if (node.childEntities.isNotEmpty) {
      tmp = node.childEntities.map((e) => e.toString()).toList().join('|');
    }
    List<String> strList = [];
    strList.add(node.childEntities.length.toString());
    strList.add(tmp);
    strList.add(node.beginToken.toString());
    strList.add(node.toSource());
    strList.add('type:' + node.fields.type.toString());
    strList.add('fields:' + node.fields.variables.join(',').toString());
    Debug.blue('成员变量[$folderName]: ${strList.join(', ')}');
    for (final VariableDeclaration variable in node.fields.variables) {
      final String fieldName = variable.name.lexeme;
      PropertyInfo? item = propertyList.firstWhereOrNull(
        (element) => element.name == fieldName,
      );
      if (item == null) {
        item = PropertyInfo();
        fieldMap[fieldName] = item;
      }
      item.type = node.fields.type.toString();
      final String fieldDoc = _cleanDocComment(node.documentationComment);
      if (fieldDoc.isNotEmpty) {
        item.introduction = fieldDoc;
      }
    }
  }

  @override
  void visitComment(Comment node) {
    node.visitChildren(this);
    String token = node.tokens.map((e) => e.toString()).toList().join('|');
    String tmp = '';
    if (node.childEntities.isNotEmpty) {
      tmp = node.childEntities.map((e) => e.toString()).toList().join('|');
    }
    List<String> strList = [];
    strList.add(node.isDocumentation.toString());
    strList.add(token);
    strList.add(node.runtimeType.toString());
    strList.add(node.childEntities.length.toString());
    strList.add(tmp);
    Debug('注释[$folderName]: ${strList.join(', ')}');
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    node.visitChildren(this);
    if (nameList!.contains(node.name.toString())) {
      componentInfo ??= ComponentInfo();
      List<String> strList = [];
      strList.add(node.name.toString());
      strList.add(node.beginToken.toString());
      if (node.name.toString() == 'TECheckBox') {
        // strList.add(node.getField('checked')!.parent!.parent!.beginToken.toString());
        strList.add(
          node.getProperty('checked')!.parent!.parent!.beginToken.toString(),
        );
      }
      Debug.red('类[$folderName]: ${strList.join(', ')}');
      componentInfo!.name = node.name.toString();
      if (node.documentationComment != null) {
        componentInfo!.introduction = _cleanDocComment(
          node.documentationComment,
        );
      }
      if (onParsedComponentInfoInfo != null) {
        // 按照属性名称的首字母排序
        propertyList.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

        onParsedComponentInfoInfo!(
          ParsedComponentInfoInfo()
            ..componentInfo = componentInfo
            ..propertyList = propertyList
            ..fieldMap = fieldMap,
        );
      }
    }
    componentInfo = null;
    propertyList = [];
    fieldMap = {};
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    super.visitMethodDeclaration(node);
    if (node.isStatic && !node.name.toString().startsWith("_")) {
      StaticMethodInfo staticMethodInfo = new StaticMethodInfo();
      staticMethodInfo.name = node.name.toString();
      staticMethodInfo.introduction = _extractMainDoc(
        node.documentationComment,
      );
      staticMethodInfo.returnType = node.returnType?.toSource();
      final Map<String, String> parameterDocs = _extractParameterDocs(
        node.documentationComment,
      );
      node.parameters?.parameters.forEach((element) {
        PropertyInfo info = _propertyFromParameter(
          element,
          parameterDocs: parameterDocs,
        );
        staticMethodInfo.params.add(info);
      });
      componentInfo ??= ComponentInfo();
      componentInfo!.staticMethodList.add(staticMethodInfo);
    }
  }
}
