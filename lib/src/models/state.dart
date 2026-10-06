/// The content a [SystemOneRequest] asks questions about.
///
/// Mirrors the API's accepted shapes for `state`: plain text, a JSON
/// object, or a JSON array.
sealed class SystemOneState {
  const SystemOneState();

  /// Plain text content, e.g. a message or article.
  const factory SystemOneState.text(String value) = SystemOneStateText;

  /// Structured content, e.g. named fields or a record.
  ///
  /// This is the recommended shape for `state`.
  const factory SystemOneState.object(Map<String, dynamic> value) =
      SystemOneStateObject;

  /// A sequence of content, e.g. a chat log.
  const factory SystemOneState.array(List<dynamic> value) = SystemOneStateArray;

  /// Serializes this state into its wire-format JSON representation.
  Object? toJson();
}

/// A [SystemOneState] holding plain text.
final class SystemOneStateText extends SystemOneState {
  final String value;

  const SystemOneStateText(this.value);

  @override
  Object? toJson() => value;
}

/// A [SystemOneState] holding a JSON object.
final class SystemOneStateObject extends SystemOneState {
  final Map<String, dynamic> value;

  const SystemOneStateObject(this.value);

  @override
  Object? toJson() => value;
}

/// A [SystemOneState] holding a JSON array.
final class SystemOneStateArray extends SystemOneState {
  final List<dynamic> value;

  const SystemOneStateArray(this.value);

  @override
  Object? toJson() => value;
}
