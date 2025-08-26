import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:collection/collection.dart';

import 'model.dart';
import 'util.dart';

typedef OnParsedComponentInfoInfo = void Function(ParsedComponentInfoInfo info);

// ignore_for_file: always_specify_types
class ComponentRule {
  ComponentRule(
      {this.isGrammarParser,
        this.parsedUnitResult,
        this.resolvedUnitResult,
        this.startTime,
        this.nameList,
        this.basePath,
        this.folderName,
        this.isMerge,
        this.sourceFileName});

  final ParsedUnitResult? parsedUnitResult; //词法分析
  final ResolvedUnitResult? resolvedUnitResult; //语法分析
  final List<String>? nameList;
  final String? basePath;
  final String? folderName;
  final String? sourceFileName;
  final int? startTime;
  final bool? isMerge;
  final bool? isGrammarParser;

  List<ParsedComponentInfoInfo> analyse() {
    List<ParsedComponentInfoInfo> parsedComponentInfoList = [];
    int startTime1 = DateTime.now().microsecondsSinceEpoch;
    if (isGrammarParser!) {
      final ComponentVisitor visitor = ComponentVisitor(
          nameList: nameList,
          basePath: basePath,
          onParsedComponentInfoInfo: (ParsedComponentInfoInfo info) {
            parsedComponentInfoList.add(info);
            // print('添加解析结果：${info.componentInfo.name}');
          },
          sourceFileName: sourceFileName);
      resolvedUnitResult!.libraryElement.accept(visitor);
    } else {
      final ComponentAstVisitor visitor = ComponentAstVisitor(
          nameList: nameList,
          basePath: basePath,
          folderName: folderName,
          onParsedComponentInfoInfo: (ParsedComponentInfoInfo info) {
            parsedComponentInfoList.add(info);
            Debug.red('添加解析结果：${info.componentInfo!.name}');
          },
          sourceFileName: sourceFileName);
      parsedUnitResult!.unit.accept(visitor);
    }
    // int endTime1 = DateTime.now().microsecondsSinceEpoch;
    // print('语法分析完毕!  用时: ${((endTime1 - startTime1) / 1000).floor()}ms');
    // analysisResult.unit.accept(visitor);

    int endTime = DateTime.now().microsecondsSinceEpoch;
    print('analyse 执行用时: ${((endTime - startTime1) / 1000).floor()}ms');
    // print('${nameList.join(',')} 生成完毕!  用时: ${((endTime - startTime) / 1000).floor()}ms');
    print('$sourceFileName 生成完毕');
    return parsedComponentInfoList;
  }
}

class ComponentAstVisitor extends RecursiveAstVisitor<void> {
  ComponentAstVisitor({this.onParsedComponentInfoInfo, this.nameList, this.basePath, this.folderName, this.sourceFileName});

  final List<String>? nameList;
  final String? basePath;
  final String? folderName;
  final String? sourceFileName;
  final OnParsedComponentInfoInfo? onParsedComponentInfoInfo;
  ComponentInfo? componentInfo;
  List<PropertyInfo> propertyList = [];
  Map<String,PropertyInfo> fieldMap = {};

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    node.visitChildren(this);
    // 无命名构造函数
    // List childEntities = node.childEntities.toList();
    // bool isNormalConstructor = childEntities.isNotEmpty && nameList!.contains(childEntities[0].toString());
    // bool isConstConstructor = childEntities.length >= 2 && childEntities[0].toString() == 'const' && nameList!.contains(childEntities[1].toString());
    if (node.name == null) {
      for (final FormalParameter param in node.parameters.parameters) {
        List<String> strList = [];
        strList.add('identifier:' + (param.name?.lexeme.toString() ?? ""));
        strList.add('isNamed:' + param.isNamed.toString());
        strList.add('isOptional:' + param.isOptional.toString());
        strList.add('isOptionalNamed:' + param.isOptionalNamed.toString());
        strList.add('isOptionalPositional:' + param.isOptionalPositional.toString());
        strList.add('isPositional:' + param.isPositional.toString());
        strList.add('isRequired:' + param.isRequired.toString());
        strList.add('isRequiredNamed:' + param.isRequiredNamed.toString());
        strList.add('isRequiredPositional:' + param.isRequiredPositional.toString());
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
        PropertyInfo item = PropertyInfo();
        item.name = param.name?.lexeme.toString() ?? "";
        item.isRequired = param.isRequired || param.toSource().toString().startsWith('@required');
        item.isNamed = param.isNamed;
        if (param.childEntities.length == 3) {
          item.defaultValue = param.childEntities.toList().last.toString();
        }
        if (tmp.startsWith('Key') && param.beginToken.toString() == 'Key') {
          item.type = 'Key';
        }
        propertyList.add(item);
      }
    } else {
      // 记录工厂构造方法
      StaticMethodInfo staticMethodInfo = new StaticMethodInfo();
      staticMethodInfo.name = node.name.toString();
      staticMethodInfo.introduction = removeDocumentationComment(node.documentationComment?.tokens.join("\n") ?? "");
      // staticMethodInfo.returnType = node.returnType.type.toString();
      node.parameters.parameters.forEach((element) {
        PropertyInfo info = PropertyInfo();
        info.name = element.name?.lexeme.toString() ?? "Null";
        // if (element is SimpleFormalParameter) {
        //   info.type = element.type.toString();
        // } else if(element is DefaultFormalParameter && element.parameter is FieldFormalParameter){
        //   info.type = (element.parameter as FieldFormalParameter).parameters.toString();
        // } else if(element is FieldFormalParameter) {
        //   info.name = element.toString();
        // }

        info.isRequired =
            element.isRequiredNamed || element.isRequiredPositional;
        info.isNamed = element.isNamed;

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
    strList.add(node.parameters.parameters.map((e) => e.name?.lexeme.toString() ?? "").toList().join('|'));
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
    String fieldName = node.fields.variables.join(',');
    if(fieldName.contains("=")){
      fieldName = fieldName.split("=")[0].trim();
    }
    PropertyInfo? item = propertyList.firstWhereOrNull((element) => element.name == fieldName);
    if (item == null) {
      item = PropertyInfo();
      fieldMap[fieldName] = item;
    }
    item.type = node.fields.type.toString();
    if (node.beginToken.toString().startsWith('///')) {
      item.introduction = removeDocumentationComment(node.beginToken.toString());
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
        strList.add(node.getProperty('checked')!.parent!.parent!.beginToken.toString());
      }
      Debug.red('类[$folderName]: ${strList.join(', ')}');
      componentInfo!.name = node.name.toString();
      if (node.documentationComment != null) {
        componentInfo!.introduction = removeDocumentationComment(
            node.documentationComment!.tokens.join("\n"));
      }
      if (onParsedComponentInfoInfo != null) {
        // 按照属性名称的首字母排序
        propertyList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        
        onParsedComponentInfoInfo!(ParsedComponentInfoInfo()
          ..componentInfo = componentInfo
          ..propertyList = propertyList
          ..fieldMap = fieldMap);
      }
    }
    componentInfo = null;
    propertyList = [];
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    super.visitMethodDeclaration(node);
    if(node.isStatic && !node.name.toString().startsWith("_")){
      StaticMethodInfo staticMethodInfo = new StaticMethodInfo();
      staticMethodInfo.name = node.name.toString();
      staticMethodInfo.introduction = removeDocumentationComment(node.documentationComment?.tokens.join("\n") ?? "");
      staticMethodInfo.returnType = node.returnType?.type.toString();
      node.parameters?.parameters.forEach((element) {
        PropertyInfo info = PropertyInfo();
        info.name = element.name?.lexeme.toString() ?? "Null";
        if (element is SimpleFormalParameter) {
          info.type = element.type.toString();
        } else if(element is DefaultFormalParameter && element.parameter is SimpleFormalParameter){
          info.type = (element.parameter as SimpleFormalParameter).type.toString();
        }

        info.isRequired =
            element.isRequiredNamed || element.isRequiredPositional;
        info.isNamed = element.isNamed;

        staticMethodInfo.params.add(info);
      });
      componentInfo ??= ComponentInfo();
      componentInfo!.staticMethodList.add(staticMethodInfo);
    }
  }
}

class ComponentVisitor extends RecursiveElementVisitor<void> {
  ComponentVisitor({this.onParsedComponentInfoInfo, this.nameList, this.basePath, this.folderName, this.sourceFileName});

  final List<String>? nameList;
  final String? basePath;
  final String? folderName;
  final String? sourceFileName;
  final OnParsedComponentInfoInfo? onParsedComponentInfoInfo;

  @override
  void visitClassElement(ClassElement element) {
    element.visitChildren(this);
    // print('分析文件：$sourceFileName  ${element.displayName}');
    if (nameList!.contains(element.displayName)) {
      ComponentInfo componentInfo = parseBaseInfo(element);
      List<PropertyInfo> propertyList = parseApiInfo(element);
      if (onParsedComponentInfoInfo != null) {
        onParsedComponentInfoInfo!(ParsedComponentInfoInfo()
          ..componentInfo = componentInfo
          ..propertyList = propertyList);
      }
    }
  }

  // 解析基本信息
  ComponentInfo parseBaseInfo(ClassElement element) {
    ComponentInfo componentInfo = ComponentInfo();
    componentInfo.name = element.displayName;
    List<String> comments = [];
    if (element.documentationComment != null) {
      comments = element.documentationComment!.split('///');
    }
    for (final String item in comments) {
      if (item.trim().isNotEmpty) {
        // print('注解：$item');
        if (componentInfo.introduction!.isNotEmpty) {
          componentInfo.introduction = '${componentInfo.introduction}  \n';
        }
        componentInfo.introduction = '${componentInfo.introduction}${item.trim()}';
      }
    }
    // print('\n组件基本信息：');
    // print('$componentInfo');
    return componentInfo;
  }

  // 解析属性信息
  List<PropertyInfo> parseApiInfo(ClassElement element) {
    List<PropertyInfo> propertyList = [];
    final parameters = element.unnamedConstructor!.parameters;
    for (final param in parameters) {
      PropertyInfo item = PropertyInfo();
      item.name = param.name;
      item.type = param.type.toString().replaceAll('*', '');
      item.isRequired = param.hasRequired || param.isRequiredNamed || param.isRequiredPositional;
      item.isNamed = param.isNamed;
      String? description = getDescription(param.name, element.fields);
      if (description != null) {
        item.introduction = description;
      }
      if (param.defaultValueCode != null) {
        item.defaultValue = getDefaultValue(param);
      }
      propertyList.add(item);
    }
    // print('\n组件属性信息：');
    // for (final item in propertyList) {
    //   print(item);
    // }
    
    // 按照属性名称的首字母排序
    propertyList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    return propertyList;
  }

  String getDefaultValue(ParameterElement param) {
    bool paramIsString = param.type.getDisplayString(withNullability: false) == 'String';
    String defaultValue = param.defaultValueCode!;
    // if (defaultValue == '\'\'') {
    //   defaultValue = '""';
    // }
    if (defaultValue.startsWith("'")) {
      defaultValue = defaultValue.substring(1, defaultValue.length - 1);
    }
    // print('paramIsString=$paramIsString, defaultValue=$defaultValue');
    return paramIsString ? defaultValue : '$defaultValue';
  }

  String? getDescription(String name, List<FieldElement> fields) {
    final hasField = fields.any((field) => field.name == name);
    if (hasField) {
      final field = fields.firstWhere((element) => element.name == name);
      final hasDocumentation = field.documentationComment != null;

      return hasDocumentation ? removeDocumentationComment(field.documentationComment!) : null;
    }
    return null;
  }
}
