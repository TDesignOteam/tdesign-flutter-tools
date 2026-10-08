import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:dart_style/dart_style.dart';

/// Callable syntax, independent of the rendered section title.
enum ApiCallableKind { method, constructor, factoryConstructor, function }

/// Compact callable contract shared by constructors, methods and functions.
/// Tables carry types/defaults; only positional calls need a parameter shape.
({String shape, String typeParameters}) apiCallableContract(
  String signature, {
  String ownerDeclaration = '',
  ApiCallableKind kind = ApiCallableKind.method,
  bool isExternal = false,
}) {
  if (signature.isEmpty) return (shape: '', typeParameters: '');
  final suffix =
      isExternal || kind == ApiCallableKind.constructor
          ? ';'
          : kind == ApiCallableKind.factoryConstructor
          ? ' = _DocumentationConstructor;'
          : ' => throw UnimplementedError();';
  final owner =
      parseString(
        content:
            ownerDeclaration.isEmpty
                ? '$signature$suffix'
                : '$ownerDeclaration { $signature$suffix }',
      ).unit.declarations.single;
  final callable =
      owner is ClassDeclaration
          ? owner.members.single
          : owner is ExtensionDeclaration
          ? owner.members.single
          : owner;
  final FormalParameterList parameters;
  final TypeParameterList? typeParameters;
  if (callable is ConstructorDeclaration) {
    parameters = callable.parameters;
    typeParameters = null;
  } else if (callable is MethodDeclaration) {
    parameters = callable.parameters!;
    typeParameters = callable.typeParameters;
  } else {
    final function = callable as FunctionDeclaration;
    parameters = function.functionExpression.parameters!;
    typeParameters = function.functionExpression.typeParameters;
  }
  final positional = parameters.parameters
      .where((parameter) => !parameter.isNamed)
      .map((parameter) => parameter.name!.lexeme)
      .join(', ');
  return (
    shape: positional,
    typeParameters:
        typeParameters?.typeParameters.map((p) => p.toSource()).join(', ') ??
        '',
  );
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
