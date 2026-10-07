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
