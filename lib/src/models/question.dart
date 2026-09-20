/// One of the question shapes that can be submitted to the System One API.
///
/// Questions are request-only — they are serialized with [toJson] and sent
/// to the API, never parsed back from a response.
sealed class Question {
  /// The instructions describing what the question asks about, e.g.
  /// `"Does this message express urgency?"`.
  ///
  /// May be a `String`, `Map`, `List`, or `null`.
  final Object? instructions;

  const Question(this.instructions);

  /// Serializes this question into its wire-format JSON representation.
  Map<String, Object?> toJson();
}

/// A yes/no question, optionally with criteria describing what counts as
/// true or false.
final class NoulQuestion extends Question {
  /// A description of what counts as a "true" answer.
  ///
  /// May be a `String`, `Map`, `List`, or `null`.
  final Object? trueCriteria;

  /// A description of what counts as a "false" answer.
  ///
  /// May be a `String`, `Map`, `List`, or `null`.
  final Object? falseCriteria;

  const NoulQuestion(
    super.instructions, {
    this.trueCriteria,
    this.falseCriteria,
  });

  @override
  Map<String, Object?> toJson() {
    final hasCriteria = trueCriteria != null || falseCriteria != null;
    return {
      'type': 'noul',
      'instructions': instructions,
      if (hasCriteria)
        'criteria': {'true': trueCriteria, 'false': falseCriteria},
    };
  }
}

/// A question selecting one option out of a fixed set of choices.
final class ChoiceQuestion extends Question {
  /// The available options, keyed by option name, with a description
  /// (`String`, `Map`, `List`, or `null`) for each.
  ///
  /// Must contain between 1 and 255 entries.
  final Map<String, Object?> criteria;

  ChoiceQuestion(super.instructions, {required this.criteria}) {
    if (criteria.isEmpty || criteria.length > 255) {
      throw ArgumentError.value(
        criteria,
        'criteria',
        'must contain between 1 and 255 options',
      );
    }
  }

  @override
  Map<String, Object?> toJson() {
    return {
      'type': 'choice',
      'instructions': instructions,
      'criteria': criteria,
    };
  }
}

/// A question rating something against an ordered rubric of levels.
final class ScoreQuestion extends Question {
  /// The description of each rubric level, ordered low to high.
  ///
  /// Each entry's index corresponds to its level. Must contain between 2
  /// and 10 entries.
  final List<Object?> criteria;

  ScoreQuestion(super.instructions, {required this.criteria}) {
    if (criteria.length < 2 || criteria.length > 10) {
      throw ArgumentError.value(
        criteria,
        'criteria',
        'must contain between 2 and 10 levels',
      );
    }
  }

  @override
  Map<String, Object?> toJson() {
    return {
      'type': 'score',
      'instructions': instructions,
      'criteria': criteria,
    };
  }
}
