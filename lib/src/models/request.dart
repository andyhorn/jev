import 'question.dart';
import 'state.dart';

/// The model aliases known to be accepted by the System One API.
///
/// This is intentionally not a closed enum — the server resolves the alias
/// string, and new aliases may be added without a client release.
abstract final class JevModel {
  static const String latest = 'jev-latest';
  static const String preview = 'jev-preview';
}

/// A request to the System One API: some [state] to evaluate, and a set of
/// named [questions] to ask about it.
class SystemOneRequest {
  /// The content to evaluate.
  final JevState state;

  /// The model alias to use, e.g. [JevModel.latest].
  final String model;

  /// The questions to ask about [state], keyed by a caller-chosen name.
  final Map<String, Question> questions;

  const SystemOneRequest({
    required this.state,
    this.model = JevModel.latest,
    required this.questions,
  });

  /// Serializes this request into its wire-format JSON representation.
  Map<String, Object?> toJson() {
    return {
      'state': state.toJson(),
      'model': model,
      'questions': questions.map(
        (name, question) => MapEntry(name, question.toJson()),
      ),
    };
  }
}
