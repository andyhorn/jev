/// The content a [SystemOneRequest] asks questions about.
///
/// Mirrors the API's accepted shapes for `state`: plain text, a JSON
/// object, or a JSON array.
sealed class JevState {
  const JevState();

  /// Plain text content, e.g. a message or article.
  const factory JevState.text(String value) = JevStateText;

  /// Structured content, e.g. named fields or a record.
  const factory JevState.object(Map<String, dynamic> value) = JevStateObject;

  /// A sequence of content, e.g. a chat log.
  const factory JevState.array(List<dynamic> value) = JevStateArray;

  /// Serializes this state into its wire-format JSON representation.
  Object? toJson();
}

/// A [JevState] holding plain text.
final class JevStateText extends JevState {
  final String value;

  const JevStateText(this.value);

  @override
  Object? toJson() => value;
}

/// A [JevState] holding a JSON object.
final class JevStateObject extends JevState {
  final Map<String, dynamic> value;

  const JevStateObject(this.value);

  @override
  Object? toJson() => value;
}

/// A [JevState] holding a JSON array.
final class JevStateArray extends JevState {
  final List<dynamic> value;

  const JevStateArray(this.value);

  @override
  Object? toJson() => value;
}
