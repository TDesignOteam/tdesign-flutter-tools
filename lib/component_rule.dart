import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'documentation.dart';
import 'model.dart';
import 'util.dart';

typedef OnParsedComponentInfoInfo = void Function(ParsedComponentInfoInfo info);

// ignore_for_file: always_specify_types
class ComponentRule {
  ComponentRule({
    this.isGrammarParser,
    this.parsedUnitResult,
    this.resolvedUnitResult,
    this.startTime,
    this.nameList,
    this.basePath,
    this.folderName,
    this.sourceFileName,
  });

  final ParsedUnitResult? parsedUnitResult; //词法分析
  final ResolvedUnitResult? resolvedUnitResult; //语法分析
  final List<String>? nameList;
  final String? basePath;
  final String? folderName;
  final String? sourceFileName;
  final int? startTime;
  final bool? isGrammarParser;

  Set<String> _loadSimpleEnumNames() {
    final String? path = parsedUnitResult?.path ?? resolvedUnitResult?.path;
    if (path == null || path.isEmpty) {
      return <String>{};
    }
    final File file = File(path);
    if (!file.existsSync()) {
      return <String>{};
    }
    final String content = file.readAsStringSync();
    final RegExp marker = RegExp(
      r'^[ \t]*//[ \t]*doc-simple-enum[ \t]*\r?\n(?:(?:[ \t]*///.*\r?\n)|(?:[ \t]*@.*\r?\n)|(?:[ \t]*\r?\n))*[ \t]*enum[ \t]+([A-Za-z_]\w*)',
      multiLine: true,
    );
    return marker
        .allMatches(content)
        .map((Match match) => match.group(1) ?? '')
        .where((String name) => name.isNotEmpty)
        .toSet();
  }

  List<ParsedComponentInfoInfo> analyse() {
    List<ParsedComponentInfoInfo> parsedComponentInfoList = [];
    int startTime1 = DateTime.now().microsecondsSinceEpoch;
    final Set<String> simpleEnumNames = _loadSimpleEnumNames();
    if (isGrammarParser!) {
      final ComponentVisitor visitor = ComponentVisitor(
        nameList: nameList,
        basePath: basePath,
        onParsedComponentInfoInfo: (ParsedComponentInfoInfo info) {
          parsedComponentInfoList.add(info);
        },
        sourceFileName: sourceFileName,
      );
      resolvedUnitResult!.libraryElement.accept(visitor);
    } else {
      final ComponentAstVisitor visitor = ComponentAstVisitor(
        nameList: nameList,
        basePath: basePath,
        folderName: folderName,
        simpleEnumNames: simpleEnumNames,
        onParsedComponentInfoInfo: (ParsedComponentInfoInfo info) {
          parsedComponentInfoList.add(info);
        },
        sourceFileName: sourceFileName,
      );
      parsedUnitResult!.unit.accept(visitor);
    }
    int endTime = DateTime.now().microsecondsSinceEpoch;
    print('analyse 执行用时: ${((endTime - startTime1) / 1000).floor()}ms');
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
    this.simpleEnumNames = const <String>{},
  });

  final List<String>? nameList;
  final String? basePath;
  final String? folderName;
  final String? sourceFileName;
  final Set<String> simpleEnumNames;
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
    final ComponentInfo componentInfo =
        ComponentInfo()
          ..name = name
          ..kind = 'enum'
          ..isSimpleEnum = simpleEnumNames.contains(name);
    if (node.documentationComment != null) {
      componentInfo.introduction = formatDocumentationForMarkdown(
        node.documentationComment!.tokens.join('\n'),
      );
    }
    for (final EnumConstantDeclaration constant in node.constants) {
      final EnumMemberInfo member =
          EnumMemberInfo()..name = constant.name.lexeme;
      if (constant.documentationComment != null) {
        member.introduction = formatDocumentationForMarkdown(
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
    final ComponentInfo componentInfo =
        ComponentInfo()
          ..name = name
          ..kind = 'typedef'
          ..typedefDefinition =
              'typedef ${node.name.lexeme} = ${node.type.toSource()};';
    if (node.documentationComment != null) {
      componentInfo.introduction = formatDocumentationForMarkdown(
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
      rawDefault =
          _allClassConstructorDefaults[_currentClassSuperName]?[item.name];
    }
    item.defaultValue = formatDefaultValueForDoc(
      rawDefault,
      paramName: item.name,
      isRequired: item.isRequired,
    );
    return item;
  }

  void _captureExplicitForwarding(
    MethodDeclaration node,
    StaticMethodInfo methodInfo,
  ) {
    if (node.body is EmptyFunctionBody) {
      return;
    }
    final Set<String> methodParamNames =
        methodInfo.params
            .map((PropertyInfo p) => p.name)
            .where((String name) => name.isNotEmpty)
            .toSet();
    if (methodParamNames.isEmpty) {
      return;
    }
    final _ConstructorLikeCallCollector collector =
        _ConstructorLikeCallCollector(knownTypeNames: nameList!.toSet());
    node.body.accept(collector);
    final Map<String, _ForwardingCandidate> candidates =
        <String, _ForwardingCandidate>{};
    for (final _ConstructorLikeCall call in collector.calls) {
      final _ForwardingCandidate? candidate = _buildForwardingCandidate(
        call,
        node,
        methodParamNames,
      );
      if (candidate == null) {
        continue;
      }
      final List<String> sortedKeys = candidate.paramMap.keys.toList()..sort();
      final String mappingKey = sortedKeys
          .map((String key) => '$key:${candidate.paramMap[key]}')
          .join(',');
      final String dedupeKey =
          '${candidate.targetClassName}|${candidate.targetConstructorName ?? ''}|$mappingKey';
      candidates.putIfAbsent(dedupeKey, () => candidate);
    }
    _applyBestForwardingCandidate(candidates, methodInfo);
  }

  void _captureConstructorExplicitForwarding(
    ConstructorDeclaration node,
    StaticMethodInfo methodInfo,
  ) {
    if (node.body is EmptyFunctionBody) {
      return;
    }
    final Set<String> constructorParamNames =
        methodInfo.params
            .map((PropertyInfo p) => p.name)
            .where((String name) => name.isNotEmpty)
            .toSet();
    if (constructorParamNames.isEmpty) {
      return;
    }
    final _ConstructorLikeCallCollector collector =
        _ConstructorLikeCallCollector(knownTypeNames: nameList!.toSet());
    node.body.accept(collector);
    final Map<String, _ForwardingCandidate> candidates =
        <String, _ForwardingCandidate>{};
    for (final _ConstructorLikeCall call in collector.calls) {
      final _ForwardingCandidate? candidate = _buildConstructorForwardingCandidate(
        call,
        node,
        constructorParamNames,
      );
      if (candidate == null) {
        continue;
      }
      final List<String> sortedKeys = candidate.paramMap.keys.toList()..sort();
      final String mappingKey = sortedKeys
          .map((String key) => '$key:${candidate.paramMap[key]}')
          .join(',');
      final String dedupeKey =
          '${candidate.targetClassName}|${candidate.targetConstructorName ?? ''}|$mappingKey';
      candidates.putIfAbsent(dedupeKey, () => candidate);
    }
    _applyBestForwardingCandidate(candidates, methodInfo);
  }

  void _applyBestForwardingCandidate(
    Map<String, _ForwardingCandidate> candidates,
    StaticMethodInfo methodInfo,
  ) {
    if (candidates.isEmpty) {
      return;
    }
    int bestScore = 0;
    final List<_ForwardingCandidate> best = <_ForwardingCandidate>[];
    for (final _ForwardingCandidate candidate in candidates.values) {
      final int score = candidate.paramMap.length;
      if (score > bestScore) {
        bestScore = score;
        best
          ..clear()
          ..add(candidate);
      } else if (score == bestScore) {
        best.add(candidate);
      }
    }
    if (bestScore <= 0 || best.length != 1) {
      return;
    }
    methodInfo.forwardedTargetName = best.first.targetClassName;
    methodInfo.forwardedConstructorName = best.first.targetConstructorName;
    methodInfo.forwardedParamMap = Map<String, String>.from(
      best.first.paramMap,
    );
  }

  _ForwardingCandidate? _buildForwardingCandidate(
    _ConstructorLikeCall call,
    MethodDeclaration ownerMethod,
    Set<String> methodParamNames,
  ) {
    final String targetClassName = call.targetClassName;
    if (targetClassName.startsWith('_') ||
        !nameList!.contains(targetClassName)) {
      return null;
    }
    final Map<String, String> paramMap = <String, String>{};
    for (final Expression argument in call.argumentList.arguments) {
      if (argument is! NamedExpression) {
        continue;
      }
      final String? sourceParamName = _extractDirectMethodParameterReference(
        argument.expression,
        ownerMethod,
        methodParamNames,
      );
      if (sourceParamName == null) {
        continue;
      }
      final String targetParamName = argument.name.label.name;
      final String? previousTarget = paramMap[sourceParamName];
      if (previousTarget != null && previousTarget != targetParamName) {
        return null;
      }
      paramMap[sourceParamName] = targetParamName;
    }
    if (paramMap.isEmpty) {
      return null;
    }
    return _ForwardingCandidate(
      targetClassName: targetClassName,
      targetConstructorName: call.targetConstructorName,
      paramMap: paramMap,
    );
  }

  _ForwardingCandidate? _buildConstructorForwardingCandidate(
    _ConstructorLikeCall call,
    ConstructorDeclaration ownerConstructor,
    Set<String> constructorParamNames,
  ) {
    final String targetClassName = call.targetClassName;
    if (targetClassName.startsWith('_') ||
        !nameList!.contains(targetClassName)) {
      return null;
    }
    final Map<String, String> paramMap = <String, String>{};
    for (final Expression argument in call.argumentList.arguments) {
      if (argument is! NamedExpression) {
        continue;
      }
      final String? sourceParamName = _extractDirectConstructorParameterReference(
        argument.expression,
        ownerConstructor,
        constructorParamNames,
      );
      if (sourceParamName == null) {
        continue;
      }
      final String targetParamName = argument.name.label.name;
      final String? previousTarget = paramMap[sourceParamName];
      if (previousTarget != null && previousTarget != targetParamName) {
        return null;
      }
      paramMap[sourceParamName] = targetParamName;
    }
    if (paramMap.isEmpty) {
      return null;
    }
    return _ForwardingCandidate(
      targetClassName: targetClassName,
      targetConstructorName: call.targetConstructorName,
      paramMap: paramMap,
    );
  }

  String? _extractDirectMethodParameterReference(
    Expression expression,
    MethodDeclaration ownerMethod,
    Set<String> methodParamNames,
  ) {
    if (expression is! SimpleIdentifier) {
      return null;
    }
    final String name = expression.name;
    if (!methodParamNames.contains(name)) {
      return null;
    }
    if (_isShadowedByEnclosingFunction(expression, ownerMethod)) {
      return null;
    }
    return name;
  }

  bool _isShadowedByEnclosingFunction(
    SimpleIdentifier identifier,
    MethodDeclaration ownerMethod,
  ) {
    final String name = identifier.name;
    AstNode? current = identifier.parent;
    while (current != null && current != ownerMethod) {
      if (current is FunctionExpression &&
          _functionParametersContainName(current.parameters, name)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  String? _extractDirectConstructorParameterReference(
    Expression expression,
    ConstructorDeclaration ownerConstructor,
    Set<String> constructorParamNames,
  ) {
    if (expression is! SimpleIdentifier) {
      return null;
    }
    final String name = expression.name;
    if (!constructorParamNames.contains(name)) {
      return null;
    }
    if (_isShadowedByEnclosingFunctionInConstructor(
      expression,
      ownerConstructor,
    )) {
      return null;
    }
    return name;
  }

  bool _isShadowedByEnclosingFunctionInConstructor(
    SimpleIdentifier identifier,
    ConstructorDeclaration ownerConstructor,
  ) {
    final String name = identifier.name;
    AstNode? current = identifier.parent;
    while (current != null && current != ownerConstructor) {
      if (current is FunctionExpression &&
          _functionParametersContainName(current.parameters, name)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  bool _functionParametersContainName(
    FormalParameterList? params,
    String name,
  ) {
    if (params == null) {
      return false;
    }
    for (final FormalParameter param in params.parameters) {
      if (formalParameterName(param) == name) {
        return true;
      }
    }
    return false;
  }

  void _splitFieldsBeyondConstructor() {
    for (final MapEntry<String, PropertyInfo> entry in fieldMap.entries) {
      if (entry.key.startsWith('_')) {
        continue;
      }
      if (_constructorParamNames.contains(entry.key)) {
        continue;
      }
      final PropertyInfo field = _copyPropertyInfo(entry.value)
        ..name = entry.key;
      if (entry.value.isStatic) {
        staticMemberList.add(field);
      } else {
        extraPropertyList.add(field);
      }
    }
    extraPropertyList.sort(
      (PropertyInfo a, PropertyInfo b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    staticMemberList.sort(
      (PropertyInfo a, PropertyInfo b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
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
    _finalizeMethodParams(
      componentInfo!.constructorMethodList,
      inheritParentDefault: true,
    );
  }

  void _finalizeCallableMethodParams() {
    if (componentInfo == null) {
      return;
    }
    _finalizeMethodParams(componentInfo!.staticMethodList);
    _finalizeMethodParams(componentInfo!.instanceMethodList);
  }

  void _finalizeMethodParams(
    List<StaticMethodInfo> methods, {
    bool inheritParentDefault = false,
  }) {
    for (final StaticMethodInfo method in methods) {
      for (final PropertyInfo param in method.params) {
        _fillPropertyFromFieldMap(param);
        if ((param.defaultValue == '-' || param.defaultValue.isEmpty) &&
            inheritParentDefault &&
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
    final List<PropertyInfo> named =
        propertyList.where((PropertyInfo p) => p.isNamed).toList()..sort(
          (PropertyInfo a, PropertyInfo b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
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
      final String constructorName = node.name!.lexeme;
      if (isLibraryPrivateNamedConstructor(constructorName)) {
        return;
      }
      // 记录命名/工厂构造方法
      final StaticMethodInfo staticMethodInfo = StaticMethodInfo();
      staticMethodInfo.name = constructorName;
      staticMethodInfo.introduction =
          node.documentationComment?.tokens.join('\n') ?? '';
      for (final FormalParameter element in node.parameters.parameters) {
        staticMethodInfo.params.add(_buildPropertyFromParameter(element));
      }
      applyCallableDocumentation(staticMethodInfo);
      _captureConstructorExplicitForwarding(node, staticMethodInfo);
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
      item.introduction = formatDocumentationForMarkdown(
        node.documentationComment!.tokens.join('\n'),
      );
    } else if (node.beginToken.toString().startsWith('///')) {
      item.introduction = formatDocumentationForMarkdown(
        node.beginToken.toString(),
      );
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
        componentInfo!.introduction = formatDocumentationForMarkdown(
          node.documentationComment!.tokens.join('\n'),
        );
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
      _finalizeCallableMethodParams();
      _sortPropertyListPreservingPositional();
      _emitParsedInfo(
        ParsedComponentInfoInfo()
          ..componentInfo = componentInfo
          ..propertyList = propertyList
          ..extraPropertyList = extraPropertyList
          ..staticMemberList = staticMemberList
          ..fieldMap = fieldMap,
      );
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
    methodInfo.introduction =
        node.documentationComment?.tokens.join('\n') ?? '';
    methodInfo.returnType = node.returnType?.toSource();
    node.parameters?.parameters.forEach((FormalParameter element) {
      methodInfo.params.add(_buildPropertyFromParameter(element));
    });
    applyCallableDocumentation(methodInfo);
    _captureExplicitForwarding(node, methodInfo);

    componentInfo ??= ComponentInfo();
    if (node.isStatic) {
      componentInfo!.staticMethodList.add(methodInfo);
    } else if (_currentClassIsAbstract) {
      // abstract class 的实例方法（含 abstract 方法和带默认实现的可覆写方法）
      componentInfo!.instanceMethodList.add(methodInfo);
    }
  }
}

class _ForwardingCandidate {
  _ForwardingCandidate({
    required this.targetClassName,
    required this.targetConstructorName,
    required this.paramMap,
  });

  final String targetClassName;
  final String? targetConstructorName;
  final Map<String, String> paramMap;
}

class _ConstructorLikeCall {
  _ConstructorLikeCall({
    required this.targetClassName,
    required this.targetConstructorName,
    required this.argumentList,
  });

  final String targetClassName;
  final String? targetConstructorName;
  final ArgumentList argumentList;
}

class _ConstructorLikeCallCollector extends RecursiveAstVisitor<void> {
  _ConstructorLikeCallCollector({required this.knownTypeNames});

  final Set<String> knownTypeNames;
  final List<_ConstructorLikeCall> calls = <_ConstructorLikeCall>[];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    calls.add(
      _ConstructorLikeCall(
        targetClassName: node.constructorName.type.name2.lexeme,
        targetConstructorName: node.constructorName.name?.name,
        argumentList: node.argumentList,
      ),
    );
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final Expression? target = node.target;
    if (target == null) {
      final String name = node.methodName.name;
      if (_looksLikeTypeName(name) && knownTypeNames.contains(name)) {
        calls.add(
          _ConstructorLikeCall(
            targetClassName: name,
            targetConstructorName: null,
            argumentList: node.argumentList,
          ),
        );
      }
    } else if (target is SimpleIdentifier) {
      final String className = target.name;
      if (_looksLikeTypeName(className) && knownTypeNames.contains(className)) {
        calls.add(
          _ConstructorLikeCall(
            targetClassName: className,
            targetConstructorName: node.methodName.name,
            argumentList: node.argumentList,
          ),
        );
      }
    }
    super.visitMethodInvocation(node);
  }

  bool _looksLikeTypeName(String name) {
    if (name.isEmpty) {
      return false;
    }
    return name[0].toUpperCase() == name[0];
  }
}

class ComponentVisitor extends RecursiveElementVisitor<void> {
  ComponentVisitor({
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

  @override
  void visitClassElement(ClassElement element) {
    element.visitChildren(this);
    // print('分析文件：$sourceFileName  ${element.displayName}');
    if (nameList!.contains(element.displayName)) {
      ComponentInfo componentInfo = parseBaseInfo(element);
      List<PropertyInfo> propertyList = parseApiInfo(element);
      if (onParsedComponentInfoInfo != null) {
        onParsedComponentInfoInfo!(
          ParsedComponentInfoInfo()
            ..componentInfo = componentInfo
            ..propertyList = propertyList
            ..extraPropertyList = <PropertyInfo>[]
            ..staticMemberList = <PropertyInfo>[]
            ..fieldMap = <String, PropertyInfo>{},
        );
      }
    }
  }

  // 解析基本信息
  ComponentInfo parseBaseInfo(ClassElement element) {
    ComponentInfo componentInfo = ComponentInfo();
    componentInfo.name = element.displayName;
    if (element.documentationComment != null) {
      componentInfo.introduction = formatDocumentationForMarkdown(
        element.documentationComment!,
      );
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
      item.isRequired =
          param.hasRequired ||
          param.isRequiredNamed ||
          param.isRequiredPositional;
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
    propertyList.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

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

      return hasDocumentation
          ? formatDocumentationForMarkdown(field.documentationComment!)
          : null;
    }
    return null;
  }
}
