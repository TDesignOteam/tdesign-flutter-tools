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
  // 当前正在解析的目标类名（null 表示不在目标类内）
  String? _currentTargetClassName;
  // 当前正在解析的类是否是 abstract class（用于收集实例方法）
  bool _currentClassIsAbstract = false;

  bool get _isInTargetClass => _currentTargetClassName != null;

  void _resetClassState() {
    componentInfo = null;
    propertyList = [];
    fieldMap = {};
    _currentTargetClassName = null;
    _currentClassIsAbstract = false;
  }

  PropertyInfo _buildPropertyFromParameter(FormalParameter param) {
    final PropertyInfo item = PropertyInfo();
    item.name = param.name?.lexeme.toString() ?? '';
    item.isRequired =
        param.isRequired || param.toSource().toString().startsWith('@required');
    item.isNamed = param.isNamed;
    item.type = extractFormalParameterType(param);
    item.defaultValue = formatDefaultValueForDoc(
      extractFormalParameterDefaultValue(param),
      paramName: item.name,
      isRequired: item.isRequired,
    );
    return item;
  }

  void _mergeExtraFieldsIntoPropertyList() {
    for (final MapEntry<String, PropertyInfo> entry in fieldMap.entries) {
      if (entry.key.startsWith('_')) {
        continue;
      }
      final bool exists =
          propertyList.any((PropertyInfo element) => element.name == entry.key);
      if (!exists) {
        final PropertyInfo field = entry.value;
        field.name = entry.key;
        propertyList.add(field);
      }
    }
  }

  void _fillPropertyFromFieldMap(PropertyInfo item) {
    final PropertyInfo? field = fieldMap[item.name];
    if (field == null) {
      return;
    }
    if (item.type.isEmpty && field.type.isNotEmpty) {
      item.type = field.type;
    }
    if (item.introduction.isEmpty && field.introduction.isNotEmpty) {
      item.introduction = field.introduction;
    }
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if (!_isInTargetClass) {
      node.visitChildren(this);
      return;
    }
    node.visitChildren(this);
    if (node.name == null) {
      for (final FormalParameter param in node.parameters.parameters) {
        Debug.yellow('构造参数[$folderName]: ${param.toSource()}');
        propertyList.add(_buildPropertyFromParameter(param));
      }
    } else {
      // 记录工厂构造方法
      final StaticMethodInfo staticMethodInfo = StaticMethodInfo();
      staticMethodInfo.name = node.name.toString();
      staticMethodInfo.introduction = removeDocumentationComment(
          node.documentationComment?.tokens.join('\n') ?? '');
      for (final FormalParameter element in node.parameters.parameters) {
        staticMethodInfo.params.add(_buildPropertyFromParameter(element));
      }
      componentInfo ??= ComponentInfo();
      componentInfo!.constructorMethodList.add(staticMethodInfo);
    }
    Debug.green(
        '构造函数[$folderName]: ${node.name ?? 'default'} | ${node.parameters.parameters.map((FormalParameter e) => e.name?.lexeme).join('|')}');
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (!_isInTargetClass) {
      node.visitChildren(this);
      return;
    }
    node.visitChildren(this);
    String fieldName = node.fields.variables.join(',');
    if (fieldName.contains('=')) {
      fieldName = fieldName.split('=')[0].trim();
    }
    if (fieldName.startsWith('_')) {
      return;
    }
    PropertyInfo? item =
        propertyList.firstWhereOrNull((PropertyInfo element) => element.name == fieldName);
    item ??= PropertyInfo()..name = fieldName;
    fieldMap[fieldName] = item;
    item.type = node.fields.type.toString();
    if (node.documentationComment != null) {
      item.introduction = removeDocumentationComment(
        node.documentationComment!.tokens.join('\n'),
      );
    } else if (node.beginToken.toString().startsWith('///')) {
      item.introduction = removeDocumentationComment(node.beginToken.toString());
    }
    Debug.blue('成员变量[$folderName]: $fieldName | ${item.type}');
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
    final bool isTarget = nameList!.contains(node.name.toString());
    final String? previousTargetClassName = _currentTargetClassName;
    final bool previousClassIsAbstract = _currentClassIsAbstract;
    if (isTarget) {
      _currentTargetClassName = node.name.toString();
      _currentClassIsAbstract = node.abstractKeyword != null;
    }
    node.visitChildren(this);
    if (isTarget) {
      componentInfo ??= ComponentInfo();
      componentInfo!.name = node.name.toString();
      if (node.documentationComment != null) {
        componentInfo!.introduction = removeDocumentationComment(
            node.documentationComment!.tokens.join('\n'));
      }
      _mergeExtraFieldsIntoPropertyList();
      for (final PropertyInfo item in propertyList) {
        _fillPropertyFromFieldMap(item);
        if (item.type.isEmpty) {
          item.type = '-';
        }
      }
      propertyList.sort(
          (PropertyInfo a, PropertyInfo b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (onParsedComponentInfoInfo != null) {
        onParsedComponentInfoInfo!(ParsedComponentInfoInfo()
          ..componentInfo = componentInfo
          ..propertyList = propertyList
          ..fieldMap = fieldMap);
      }
      _resetClassState();
    }
    _currentTargetClassName = previousTargetClassName;
    _currentClassIsAbstract = previousClassIsAbstract;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (!_isInTargetClass) {
      super.visitMethodDeclaration(node);
      return;
    }
    super.visitMethodDeclaration(node);
    final String methodName = node.name.toString();
    // 私有方法不收录
    if (methodName.startsWith('_')) {
      return;
    }

    StaticMethodInfo methodInfo = StaticMethodInfo();
    methodInfo.name = methodName;
    methodInfo.introduction = removeDocumentationComment(
        node.documentationComment?.tokens.join('\n') ?? '');
    methodInfo.returnType = node.returnType?.toSource();
    node.parameters?.parameters.forEach((FormalParameter element) {
      methodInfo.params.add(_buildPropertyFromParameter(element));
    });

    componentInfo ??= ComponentInfo();
    if (node.isStatic) {
      componentInfo!.staticMethodList.add(methodInfo);
    } else if (_currentClassIsAbstract) {
      // abstract class 的实例方法（含 abstract 方法和带默认实现的可覆写方法）
      componentInfo!.instanceMethodList.add(methodInfo);
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
    if (element.documentationComment != null) {
      componentInfo.introduction = removeDocumentationComment(
          element.documentationComment!);
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
    final bool paramIsString =
        param.type.getDisplayString(withNullability: false) == 'String';
    String defaultValue = param.defaultValueCode!;
    if (defaultValue == param.name || defaultValue == 'this.${param.name}') {
      return '-';
    }
    if (defaultValue.startsWith("'")) {
      defaultValue = defaultValue.substring(1, defaultValue.length - 1);
    }
    return paramIsString ? defaultValue : defaultValue;
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
