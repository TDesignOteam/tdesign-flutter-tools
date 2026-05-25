import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
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
        this.sourceFileName});

  final ParsedUnitResult? parsedUnitResult; //词法分析
  final ResolvedUnitResult? resolvedUnitResult; //语法分析
  final List<String>? nameList;
  final String? basePath;
  final String? folderName;
  final String? sourceFileName;
  final int? startTime;
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
          },
          sourceFileName: sourceFileName);
      parsedUnitResult!.unit.accept(visitor);
    }
    int endTime = DateTime.now().microsecondsSinceEpoch;
    print('analyse 执行用时: ${((endTime - startTime1) / 1000).floor()}ms');
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
  List<PropertyInfo> extraPropertyList = [];
  List<PropertyInfo> staticMemberList = [];
  Map<String, PropertyInfo> fieldMap = {};
  final Set<String> _constructorParamNames = {};
  /// 当前文件内所有类的字段快照，用于解析 super.xxx 类型
  final Map<String, Map<String, PropertyInfo>> _allClassFieldMaps = {};
  /// 各类默认构造的形式参数默认值（用于 super.xxx 未显式写默认值时）
  final Map<String, Map<String, String>> _allClassConstructorDefaults = {};
  bool _targetFoundInUnit = false;
  final List<EnumDeclaration> _pendingEnums = [];
  final List<GenericTypeAlias> _pendingTypedefs = [];
  final Set<String> _emittedAuxiliaryNames = {};
  // 当前正在解析的类名（文件内任意类）
  String? _currentClassName;
  String? _currentClassSuperName;
  // 当前正在解析的目标类名（null 表示不在目标类内）
  String? _currentTargetClassName;
  // 当前正在解析的类是否是 abstract class（用于收集实例方法）
  bool _currentClassIsAbstract = false;

  bool get _isInTargetClass => _currentTargetClassName != null;

  void _emitParsedInfo(ParsedComponentInfoInfo info) {
    info.componentInfo?.sourceFile = sourceFileName;
    onParsedComponentInfoInfo?.call(info);
  }

  ParsedComponentInfoInfo _emptyParsedInfo(ComponentInfo componentInfo) {
    return ParsedComponentInfoInfo()
      ..componentInfo = componentInfo
      ..propertyList = <PropertyInfo>[]
      ..extraPropertyList = <PropertyInfo>[]
      ..staticMemberList = <PropertyInfo>[]
      ..fieldMap = <String, PropertyInfo>{};
  }

  void _emitEnum(EnumDeclaration node) {
    final String name = node.name.lexeme;
    if (_emittedAuxiliaryNames.contains(name)) {
      return;
    }
    _emittedAuxiliaryNames.add(name);
    final ComponentInfo componentInfo = ComponentInfo()
      ..name = name
      ..kind = 'enum';
    if (node.documentationComment != null) {
      componentInfo.introduction = removeDocumentationComment(
        node.documentationComment!.tokens.join('\n'),
      );
    }
    for (final EnumConstantDeclaration constant in node.constants) {
      final EnumMemberInfo member = EnumMemberInfo()
        ..name = constant.name.lexeme;
      if (constant.documentationComment != null) {
        member.introduction = removeDocumentationComment(
          constant.documentationComment!.tokens.join('\n'),
        );
      }
      componentInfo.enumMembers.add(member);
    }
    componentInfo.enumValues =
        componentInfo.enumMembers.map((EnumMemberInfo m) => m.name).toList();
    _emitParsedInfo(_emptyParsedInfo(componentInfo));
  }

  void _emitTypedef(GenericTypeAlias node) {
    final String name = node.name.lexeme;
    if (_emittedAuxiliaryNames.contains(name)) {
      return;
    }
    _emittedAuxiliaryNames.add(name);
    final ComponentInfo componentInfo = ComponentInfo()
      ..name = name
      ..kind = 'typedef'
      ..typedefDefinition = 'typedef ${node.name.lexeme} = ${node.type.toSource()};';
    if (node.documentationComment != null) {
      componentInfo.introduction = removeDocumentationComment(
        node.documentationComment!.tokens.join('\n'),
      );
    }
    _emitParsedInfo(_emptyParsedInfo(componentInfo));
  }

  void _flushPendingAuxiliaryTypes() {
    if (!_targetFoundInUnit) {
      return;
    }
    for (final EnumDeclaration node in _pendingEnums) {
      _emitEnum(node);
    }
    for (final GenericTypeAlias node in _pendingTypedefs) {
      _emitTypedef(node);
    }
    _pendingEnums.clear();
    _pendingTypedefs.clear();
  }

  void _resetClassState() {
    componentInfo = null;
    propertyList = [];
    extraPropertyList = [];
    staticMemberList = [];
    fieldMap = {};
    _constructorParamNames.clear();
    _currentTargetClassName = null;
    _currentClassIsAbstract = false;
    _currentClassSuperName = null;
  }

  PropertyInfo _copyPropertyInfo(PropertyInfo source) {
    return PropertyInfo()
      ..name = source.name
      ..type = source.type
      ..isRequired = source.isRequired
      ..isNamed = source.isNamed
      ..introduction = source.introduction
      ..defaultValue = source.defaultValue;
  }

  String? _parseSuperClassName(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause == null) {
      return null;
    }
    final TypeAnnotation superClass = extendsClause.superclass;
    if (superClass is NamedType) {
      return superClass.name2.lexeme;
    }
    return superClass.toString();
  }

  void _saveClassFieldMap(String className) {
    final Map<String, PropertyInfo> snapshot = <String, PropertyInfo>{};
    for (final MapEntry<String, PropertyInfo> entry in fieldMap.entries) {
      snapshot[entry.key] = _copyPropertyInfo(entry.value);
    }
    _allClassFieldMaps[className] = snapshot;
  }

  PropertyInfo _buildPropertyFromParameter(FormalParameter param) {
    final PropertyInfo item = PropertyInfo();
    item.name = formalParameterName(param);
    item.isRequired =
        param.isRequired || param.toSource().toString().startsWith('@required');
    item.isNamed = param.isNamed;
    item.type = extractFormalParameterType(
      param,
      superClassFieldMaps: _allClassFieldMaps[_currentClassSuperName],
    );
    String? rawDefault = extractFormalParameterDefaultValue(param);
    if ((rawDefault == null || rawDefault.trim().isEmpty) &&
        param is SuperFormalParameter &&
        _currentClassSuperName != null) {
      rawDefault = _allClassConstructorDefaults[_currentClassSuperName]?[item.name];
    }
    item.defaultValue = formatDefaultValueForDoc(
      rawDefault,
      paramName: item.name,
      isRequired: item.isRequired,
    );
    return item;
  }

  void _splitFieldsBeyondConstructor() {
    for (final MapEntry<String, PropertyInfo> entry in fieldMap.entries) {
      if (entry.key.startsWith('_')) {
        continue;
      }
      if (_constructorParamNames.contains(entry.key)) {
        continue;
      }
      final PropertyInfo field = _copyPropertyInfo(entry.value)..name = entry.key;
      if (entry.value.isStatic) {
        staticMemberList.add(field);
      } else {
        extraPropertyList.add(field);
      }
    }
    extraPropertyList.sort((PropertyInfo a, PropertyInfo b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    staticMemberList.sort((PropertyInfo a, PropertyInfo b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  void _fillPropertyFromFieldMap(PropertyInfo item) {
    final PropertyInfo? field = fieldMap[item.name];
    if (field != null) {
      if (item.type.isEmpty && field.type.isNotEmpty) {
        item.type = field.type;
      }
      if (item.introduction.isEmpty && field.introduction.isNotEmpty) {
        item.introduction = field.introduction;
      }
    }
    if (item.introduction.isEmpty) {
      item.introduction = fallbackParameterIntroduction(item.name);
    }
  }

  void _finalizeConstructorMethodParams() {
    if (componentInfo == null) {
      return;
    }
    for (final StaticMethodInfo method in componentInfo!.constructorMethodList) {
      for (final PropertyInfo param in method.params) {
        _fillPropertyFromFieldMap(param);
        if ((param.defaultValue == '-' || param.defaultValue.isEmpty) &&
            _currentClassSuperName != null) {
          final String? parentDefault =
              _allClassConstructorDefaults[_currentClassSuperName]?[param.name];
          if (parentDefault != null &&
              parentDefault.isNotEmpty &&
              parentDefault != '-') {
            param.defaultValue = parentDefault;
          }
        }
        if (param.type.isEmpty) {
          param.type = '-';
        }
      }
    }
  }

  void _sortPropertyListPreservingPositional() {
    final List<PropertyInfo> positional =
        propertyList.where((PropertyInfo p) => !p.isNamed).toList();
    final List<PropertyInfo> named = propertyList
        .where((PropertyInfo p) => p.isNamed)
        .toList()
      ..sort((PropertyInfo a, PropertyInfo b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    propertyList
      ..clear()
      ..addAll(positional)
      ..addAll(named);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if (_currentClassName == null) {
      node.visitChildren(this);
      return;
    }
    node.visitChildren(this);
    if (node.name == null) {
      final Map<String, String> ctorDefaults = <String, String>{};
      for (final FormalParameter param in node.parameters.parameters) {
        final PropertyInfo built = _buildPropertyFromParameter(param);
        final String? raw = extractFormalParameterDefaultValue(param);
        if (raw != null && raw.trim().isNotEmpty) {
          ctorDefaults[built.name] = formatDefaultValueForDoc(
            raw,
            paramName: built.name,
            isRequired: built.isRequired,
          );
        }
        if (_isInTargetClass) {
          propertyList.add(built);
          if (built.name.isNotEmpty) {
            _constructorParamNames.add(built.name);
          }
        }
      }
      _allClassConstructorDefaults[_currentClassName!] = ctorDefaults;
    } else if (_isInTargetClass) {
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
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (_currentClassName == null) {
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
    PropertyInfo? item = fieldMap[fieldName];
    item ??= PropertyInfo()..name = fieldName;
    fieldMap[fieldName] = item;
    item.isStatic = node.staticKeyword != null;
    item.type = node.fields.type?.toString() ?? '';
    if (node.documentationComment != null) {
      item.introduction = removeDocumentationComment(
        node.documentationComment!.tokens.join('\n'),
      );
    } else if (node.beginToken.toString().startsWith('///')) {
      item.introduction = removeDocumentationComment(node.beginToken.toString());
    }
  }

  @override
  void visitCompilationUnit(CompilationUnit node) {
    _targetFoundInUnit = false;
    _pendingEnums.clear();
    _pendingTypedefs.clear();
    _emittedAuxiliaryNames.clear();
    super.visitCompilationUnit(node);
    _flushPendingAuxiliaryTypes();
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    final String enumName = node.name.lexeme;
    if (enumName.startsWith('_')) {
      return;
    }
    if (nameList!.contains(enumName)) {
      _emitEnum(node);
    } else {
      _pendingEnums.add(node);
    }
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    final String aliasName = node.name.lexeme;
    if (aliasName.startsWith('_')) {
      return;
    }
    if (nameList!.contains(aliasName)) {
      _emitTypedef(node);
    } else {
      _pendingTypedefs.add(node);
    }
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final String className = node.name.toString();
    final bool isTarget = nameList!.contains(className);
    if (isTarget) {
      _targetFoundInUnit = true;
    }
    final String? previousClassName = _currentClassName;
    final String? previousSuperClassName = _currentClassSuperName;
    final Map<String, PropertyInfo> previousFieldMap = fieldMap;
    final String? previousTargetClassName = _currentTargetClassName;
    final bool previousClassIsAbstract = _currentClassIsAbstract;

    _currentClassName = className;
    fieldMap = <String, PropertyInfo>{};
    _currentClassSuperName = _parseSuperClassName(node);

    if (isTarget) {
      _currentTargetClassName = className;
      _currentClassIsAbstract = node.abstractKeyword != null;
      propertyList = <PropertyInfo>[];
      extraPropertyList = <PropertyInfo>[];
      staticMemberList = <PropertyInfo>[];
      _constructorParamNames.clear();
    }

    node.visitChildren(this);
    _saveClassFieldMap(className);

    if (isTarget) {
      componentInfo ??= ComponentInfo();
      componentInfo!.name = className;
      if (node.documentationComment != null) {
        componentInfo!.introduction = removeDocumentationComment(
            node.documentationComment!.tokens.join('\n'));
      }
      _splitFieldsBeyondConstructor();
      for (final PropertyInfo item in propertyList) {
        _fillPropertyFromFieldMap(item);
        if ((item.defaultValue == '-' || item.defaultValue.isEmpty) &&
            _currentClassSuperName != null) {
          final String? parentDefault =
              _allClassConstructorDefaults[_currentClassSuperName]?[item.name];
          if (parentDefault != null &&
              parentDefault.isNotEmpty &&
              parentDefault != '-') {
            item.defaultValue = parentDefault;
          }
        }
        if (item.type.isEmpty) {
          item.type = '-';
        }
      }
      for (final PropertyInfo item in extraPropertyList) {
        if (item.type.isEmpty) {
          item.type = '-';
        }
      }
      for (final PropertyInfo item in staticMemberList) {
        if (item.type.isEmpty) {
          item.type = '-';
        }
      }
      _finalizeConstructorMethodParams();
      _sortPropertyListPreservingPositional();
      _emitParsedInfo(ParsedComponentInfoInfo()
        ..componentInfo = componentInfo
        ..propertyList = propertyList
        ..extraPropertyList = extraPropertyList
        ..staticMemberList = staticMemberList
        ..fieldMap = fieldMap);
      _resetClassState();
    }

    _currentClassName = previousClassName;
    _currentClassSuperName = previousSuperClassName;
    fieldMap = previousFieldMap;
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
          ..propertyList = propertyList
          ..extraPropertyList = <PropertyInfo>[]
          ..staticMemberList = <PropertyInfo>[]
          ..fieldMap = <String, PropertyInfo>{});
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
      } else {
        item.introduction = fallbackParameterIntroduction(param.name);
      }
      if (param.defaultValueCode != null) {
        item.defaultValue = getDefaultValue(param);
      }
      propertyList.add(item);
    }
    // 按照属性名称的首字母排序
    propertyList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    return propertyList;
  }

  String getDefaultValue(ParameterElement param) {
    String defaultValue = param.defaultValueCode!;
    if (defaultValue == param.name || defaultValue == 'this.${param.name}') {
      return '-';
    }
    return defaultValue;
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
