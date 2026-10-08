import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:dart_style/dart_style.dart';

/// Callable syntax, independent of the rendered section title.
enum ApiCallableKind { method, constructor, factoryConstructor, function }

/// Only positional constructors need a parameter shape beside their table.
/// Types, defaults and required flags remain in the parameter table.
String constructorParameterShape(
  String signature, {
  required String ownerDeclaration,
  required ApiCallableKind kind,
  bool isExternal = false,
}) {
  if (signature.isEmpty) return '';
  final suffix =
      !isExternal && kind == ApiCallableKind.factoryConstructor
          ? ' = _DocumentationConstructor;'
          : ';';
  final owner =
      parseString(
            content: '$ownerDeclaration { $signature$suffix }',
          ).unit.declarations.single
          as ClassDeclaration;
  final constructor = owner.members.single as ConstructorDeclaration;
  final parameters = constructor.parameters.parameters;
  if (parameters.every((parameter) => parameter.isNamed)) return '';
  final required = <String>[];
  final optional = <String>[];
  final named = <String>[];
  for (final parameter in parameters) {
    final target =
        parameter.isNamed
            ? named
            : parameter.isRequiredPositional
            ? required
            : optional;
    target.add(parameter.name!.lexeme);
  }
  final groups = [
    ...required,
    if (optional.isNotEmpty) '[${optional.join(', ')}]',
    if (named.isNotEmpty) '{${named.join(', ')}}',
  ];
  final name = constructor.name?.lexeme;
  return '${owner.name.lexeme}${name == null ? '' : '.$name'}(${groups.join(', ')})';
}

/// Compact type contract, without a standalone class/extension declaration.
({String parameters, String onType}) apiTypeContract(String declaration) {
  if (declaration.isEmpty) return (parameters: '', onType: '');
  final owner =
      parseString(content: '$declaration {}').unit.declarations.single;
  final parameters =
      owner is ClassDeclaration
          ? owner.typeParameters
          : owner is ExtensionDeclaration
          ? owner.typeParameters
          : null;
  return (
    parameters:
        parameters?.typeParameters.map((p) => p.toSource()).join(', ') ?? '',
    onType:
        owner is ExtensionDeclaration
            ? owner.onClause?.extendedType.toSource() ?? ''
            : '',
  );
}

/// Format a declaration without changing tokens inside string literals.
String formatApiSignature(
  String signature, {
  String ownerDeclaration = '',
  ApiCallableKind kind = ApiCallableKind.method,
  bool isExternal = false,
}) {
  final suffix =
      isExternal || kind == ApiCallableKind.constructor
          ? ';'
          : kind == ApiCallableKind.factoryConstructor
          ? ' = _DocumentationConstructor;'
          : ' => throw UnimplementedError();';
  final wrapped =
      ownerDeclaration.isEmpty
          ? '$signature$suffix'
          : '$ownerDeclaration { $signature$suffix }';
  final formatted = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  ).format(wrapped);
  final owner = parseString(content: formatted).unit.declarations.single;
  final AnnotatedNode callable =
      owner is ClassDeclaration
          ? owner.members.single
          : owner is ExtensionDeclaration
          ? owner.members.single
          : owner;
  final end =
      callable is ConstructorDeclaration
          ? callable.parameters.end
          : callable is MethodDeclaration
          ? callable.parameters!.end
          : (callable as FunctionDeclaration)
              .functionExpression
              .parameters!
              .end;

  // Only whitespace BETWEEN tokens belongs to the wrapper. Literal contents,
  // including multiline/interpolated strings, are copied without modification.
  final buffer = StringBuffer();
  Token? token = callable.firstTokenAfterCommentAndMetadata;
  var previousEnd = token.offset;
  while (token != null && token.offset < end && !token.isEof) {
    buffer.write(
      formatted.substring(previousEnd, token.offset).replaceAll('\n  ', '\n'),
    );
    buffer.write(token.lexeme);
    previousEnd = token.end;
    token = token.next;
  }
  return buffer.toString();
}
