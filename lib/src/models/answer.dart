import 'json.dart';

/// One of the answer shapes returned by the System One API for a question.
///
/// Every question submitted to the API resolves to exactly one of the
/// subtypes below, distinguished by the wire-format `type` field.
sealed class Answer {
  /// The discriminator value from the API response, e.g. `"noul"`.
  final String type;

  const Answer(this.type);

  /// Parses an [Answer] from a decoded JSON response object, dispatching on
  /// `json['type']`.
  ///
  /// Throws a [FormatException] if `type` is not one of `"noul"`,
  /// `"choice"`, or `"score"`.
  factory Answer.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    return switch (type) {
      'noul' => NoulAnswer.fromJson(json),
      'choice' => ChoiceAnswer.fromJson(json),
      'score' => ScoreAnswer.fromJson(json),
      _ => throw FormatException('Unrecognized Answer type: $type'),
    };
  }
}

/// A yes/no answer expressed as a single probability.
///
/// There is no separate confidence value for a Noul — the single
/// probability describes it completely.
final class NoulAnswer extends Answer {
  /// The probability that the answer is "yes", from `0.0` to `1.0`.
  final double noul;

  const NoulAnswer(this.noul) : super('noul');

  factory NoulAnswer.fromJson(Map<String, dynamic> json) {
    return NoulAnswer((json['noul'] as num).toDouble());
  }
}

/// An answer selecting one option out of a fixed set of choices.
final class ChoiceAnswer extends Answer {
  /// The name of the selected option.
  final String choice;

  /// The model's confidence in [choice], from `0.0` to `1.0`.
  final double confidence;

  /// The probability of each option name being the correct choice.
  final Map<String, double> probabilities;

  const ChoiceAnswer({
    required this.choice,
    required this.confidence,
    required this.probabilities,
  }) : super('choice');

  factory ChoiceAnswer.fromJson(Map<String, dynamic> json) {
    final probabilities = (json['probabilities'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );
    return ChoiceAnswer(
      choice: json['choice'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      probabilities: probabilities,
    );
  }
}

/// An answer rating something against an ordered rubric of levels.
final class ScoreAnswer extends Answer {
  /// The probability-weighted mean across levels, e.g. `1.43`.
  ///
  /// This is not an integer level index — it is a continuous value
  /// interpolated between levels.
  final double score;

  /// The model's confidence in [score], from `0.0` to `1.0`.
  final double confidence;

  /// The description of each rubric level, keyed by level index.
  final Map<int, Object?> legend;

  /// The probability of each rubric level, keyed by level index.
  final Map<int, double> probabilities;

  const ScoreAnswer({
    required this.score,
    required this.confidence,
    required this.legend,
    required this.probabilities,
  }) : super('score');

  factory ScoreAnswer.fromJson(Map<String, dynamic> json) {
    return ScoreAnswer(
      score: (json['score'] as num).toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
      legend: decodeIntKeyedMap(
        json['legend'] as Map<String, dynamic>,
        (value) => value,
      ),
      probabilities: decodeIntKeyedMap(
        json['probabilities'] as Map<String, dynamic>,
        (value) => (value as num).toDouble(),
      ),
    );
  }

  /// The level index with the highest probability in [probabilities].
  int get mostLikelyLevel {
    return probabilities.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  /// The description of [mostLikelyLevel] from [legend].
  Object? get mostLikelyDescription => legend[mostLikelyLevel];
}
