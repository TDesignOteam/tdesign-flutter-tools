import 'package:analyzer/dart/ast/ast.dart';

/// Framework exclusions require an owner type, never just a method name or
/// an @override annotation. Unknown/custom interfaces remain public APIs.
bool isFrameworkHook(MethodDeclaration method) {
  final name = method.name.lexeme;
  final hasDocs = method.documentationComment != null;
  if (!hasDocs && const {'hashCode', '==', 'toString'}.contains(name)) {
    return true;
  }
  final owner = method.parent;
  if (owner is! ClassDeclaration) return false;
  final unit = owner.parent;
  final localClasses = <String, ClassDeclaration>{
    if (unit is CompilationUnit)
      for (final node in unit.declarations.whereType<ClassDeclaration>())
        node.name.lexeme: node,
  };
  final seen = <String>{};
  final pending = <String>[
    if (owner.extendsClause != null)
      owner.extendsClause!.superclass.name2.lexeme,
    ...?owner.implementsClause?.interfaces.map((type) => type.name2.lexeme),
    ...?owner.withClause?.mixinTypes.map((type) => type.name2.lexeme),
  ];
  while (pending.isNotEmpty) {
    final parent = pending.removeLast();
    if (!seen.add(parent)) continue;
    final local = localClasses[parent];
    if (local != null) {
      if (local.extendsClause != null)
        pending.add(local.extendsClause!.superclass.name2.lexeme);
      pending.addAll(
        local.implementsClause?.interfaces.map((type) => type.name2.lexeme) ??
            [],
      );
      pending.addAll(
        local.withClause?.mixinTypes.map((type) => type.name2.lexeme) ?? [],
      );
      continue;
    }
    if (const {
          'Widget',
          'StatelessWidget',
          'StatefulWidget',
          'State',
          'Tab',
          'RenderObjectWidget',
          'SingleChildRenderObjectWidget',
          'MultiChildRenderObjectWidget',
          'LeafRenderObjectWidget',
        }.contains(parent) &&
        const {
          'build',
          'createState',
          'createElement',
          'debugFillProperties',
        }.contains(name)) {
      return true;
    }
    if (hasDocs) continue;
    if (const {'PreferredSizeWidget', 'Tab'}.contains(parent) &&
        name == 'preferredSize')
      return true;
    if (const {
          'RenderObjectWidget',
          'SingleChildRenderObjectWidget',
          'MultiChildRenderObjectWidget',
          'LeafRenderObjectWidget',
        }.contains(parent) &&
        const {
          'createRenderObject',
          'updateRenderObject',
          'didUnmountRenderObject',
        }.contains(name))
      return true;
    if (const {
          'Element',
          'ComponentElement',
          'RenderObjectElement',
          'SingleChildRenderObjectElement',
          'MultiChildRenderObjectElement',
        }.contains(parent) &&
        const {
          'widget',
          'renderObject',
          'slot',
          'visitChildren',
          'forgetChild',
          'mount',
          'update',
          'unmount',
          'activate',
          'deactivate',
          'insertRenderObjectChild',
          'moveRenderObjectChild',
          'removeRenderObjectChild',
          'attachRenderObject',
          'detachRenderObject',
          'performRebuild',
          'debugFillProperties',
        }.contains(name))
      return true;
    if (parent == 'Decoration' &&
        const {
          'createBoxPainter',
          'hitTest',
          'isComplex',
          'debugFillProperties',
        }.contains(name))
      return true;
    if (parent == 'State' &&
        const {
          'initState',
          'dispose',
          'setState',
          'didChangeDependencies',
          'didUpdateWidget',
          'deactivate',
          'activate',
          'reassemble',
        }.contains(name))
      return true;
    if (parent == 'ChangeNotifier' &&
        const {
          'addListener',
          'removeListener',
          'notifyListeners',
          'dispose',
          'hasListeners',
        }.contains(name))
      return true;
    if (parent == 'LocalizationsDelegate' &&
        const {'isSupported', 'load', 'shouldReload'}.contains(name))
      return true;
    if (parent == 'ThemeExtension' && name == 'type') return true;
    if (const {'Map', 'MapBase', 'DelegatingMap'}.contains(parent) &&
        const {
          '[]=',
          'keys',
          'values',
          'length',
          'isEmpty',
          'isNotEmpty',
          'containsKey',
          'containsValue',
          'clear',
          'remove',
          'addAll',
          'addEntries',
          'cast',
          'forEach',
          'map',
          'putIfAbsent',
          'removeWhere',
          'update',
          'updateAll',
        }.contains(name))
      return true;
    if (const {'Iterable', 'IterableBase'}.contains(parent) &&
        const {
          'iterator',
          'length',
          'isEmpty',
          'isNotEmpty',
          'first',
          'last',
          'single',
          'cast',
          'contains',
          'elementAt',
          'toList',
          'toSet',
          'map',
          'where',
          'expand',
          'fold',
          'reduce',
          'forEach',
          'any',
          'every',
          'join',
          'skip',
          'take',
          'skipWhile',
          'takeWhile',
          'firstWhere',
          'lastWhere',
          'singleWhere',
          'followedBy',
          'whereType',
        }.contains(name))
      return true;
  }
  return false;
}
