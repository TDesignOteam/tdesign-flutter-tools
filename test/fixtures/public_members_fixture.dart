/// A concrete lifecycle handle.
class DemoHandle {
  DemoHandle._hidden();

  /// Whether the handle is open.
  bool get isShowing => true;

  /// Close safely.
  void close({
    /// Whether closure is animated.
    bool animated = true,
  }) {}

  /// Current generic values.
  List<String> get values => const <String>[];

  /// Mutable text.
  set label(String value) {}

  /// Rebuild hook, not a user command.
  void build() {}
}

/// A controller with an implicit empty constructor.
class DemoController {
  /// Reset the controller.
  void reset() {}
}

/// Public named constructors.
class DemoOptions {
  /// Create a default configuration.
  DemoOptions();

  /// Create a named configuration.
  DemoOptions.named();

  /// Create a configuration through a factory.
  factory DemoOptions.factory() => DemoOptions();

  /// Two independently listed values.
  final int first = 1, second = 2;

  /// A public value beside a private field.
  final int _hidden = 0, publicMixed = 3;

  /// Read the internal value without documenting the private field.
  int get internalValue => _hidden;
}

/// Public extension helpers.
extension DemoHelpers on DemoHandle {
  /// Whether this handle can close.
  bool get canClose => isShowing;

  /// Close through the extension.
  void dismiss() => close();
}

/// An auxiliary type excluded by strict manifests.
enum UnregisteredEnum { value }

/// A generic callback.
typedef GenericBuilder<T> = T Function(T value);

/// Generic declarations and colliding parameter names.
class DemoGeneric<T extends Object> extends _GenericBase<T> {
  /// The current index, not a target index.
  int get index => 0;

  /// Move to a target. No parameter docs have been supplied.
  void jump(int index) {}

  /// Read a Token, not a Widget key.
  void lookup(String? key) {}

  /// Return a generic value with optional positional input.
  T? read<E extends Object>(E value, [T? fallback]) => fallback;

  @override
  DemoGeneric<T> copyWith() => this;

  @override
  T? operator [](Object? key) => null;
}

abstract class _GenericBase<T> {
  _GenericBase<T> copyWith();
  T? operator [](Object? key);
}

/// A const redirecting factory has no callable body in its declaration.
sealed class DemoRedirect {
  /// Fixed layout.
  const factory DemoRedirect.fixed({
    /// Number of columns; runtime fallback is supplied by the target.
    int count,
  }) = _DemoFixed;
}

class _DemoFixed implements DemoRedirect {
  const _DemoFixed({this.count = 2});
  final int count;
}
