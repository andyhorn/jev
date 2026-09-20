import 'answer.dart';

/// Token accounting for a single System One API call.
///
/// Both fields are nullable — the upstream SDK types them nullable, and the
/// API's own docs show responses that omit `usage` entirely.
class Usage {
  /// The number of tokens consumed by the request, or `null` if unavailable.
  final int? inputTokens;

  /// The number of tokens consumed by the response, or `null` if unavailable.
  final int? outputTokens;

  const Usage({this.inputTokens, this.outputTokens});

  /// Parses a [Usage] from a decoded JSON object.
  ///
  /// Accepts a `null` [json] — the API omits the `usage` key entirely in
  /// some documented responses — and returns a [Usage] with both fields
  /// `null` in that case.
  factory Usage.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const Usage();
    }
    return Usage(
      inputTokens: json['input_tokens'] as int?,
      outputTokens: json['output_tokens'] as int?,
    );
  }
}

/// The top-level response envelope from `POST /v1/systemone`.
class SystemOneResponse {
  /// The resolved model version string, e.g. `"jev-1.13.0"`.
  final String model;

  /// The answer to each submitted question, keyed by question ID.
  final Map<String, Answer> answers;

  /// Token accounting for this call.
  final Usage usage;

  const SystemOneResponse({
    required this.model,
    required this.answers,
    required this.usage,
  });

  /// Parses a [SystemOneResponse] from a decoded JSON response object.
  factory SystemOneResponse.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'] as Map<String, dynamic>?;
    final answers = rawAnswers?.map(
      (key, value) =>
          MapEntry(key, Answer.fromJson(value as Map<String, dynamic>)),
    );

    return SystemOneResponse(
      model: json['model'] as String,
      answers: answers ?? {},
      usage: Usage.fromJson(json['usage'] as Map<String, dynamic>?),
    );
  }
}
