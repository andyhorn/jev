import 'question.dart';
import 'state.dart';

/// A request to the System One API: some [state] to evaluate, and a set of
/// named [questions] to ask about it.
class SystemOneRequest {
  /// The content to evaluate.
  final SystemOneState state;

  /// The model to use. Model names depend on the server: for example,
  /// `'jev-latest'` or `'jev-preview'` on TypeSafe's hosted API, or
  /// `'nimble'` on Ollama.
  final String model;

  /// The questions to ask about [state], keyed by a caller-chosen name.
  final Map<String, Question> questions;

  SystemOneRequest({
    required this.state,
    required this.model,
    required this.questions,
  }) {
    if (model.trim().isEmpty) {
      throw ArgumentError.value(model, 'model', 'must not be blank');
    }
  }

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
