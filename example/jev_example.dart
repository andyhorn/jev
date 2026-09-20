import 'package:jev/jev.dart';

/// Demonstrates a single System One call asking a Noul, Choice, and Score
/// question about a support-ticket-style `state`.
///
/// Requires a real System One API key in the `TYPESAFE_API_KEY` environment
/// variable — this example is illustrative only and is not run by CI.
Future<void> main() async {
  final JevClient client;
  try {
    client = JevClient.fromEnvironment();
  } on StateError catch (e) {
    print('Cannot run example: ${e.message}');
    return;
  }

  try {
    final response = await client.systemOne(
      SystemOneRequest(
        state:
            "Hi, I've been trying to connect my Stripe account for two days "
            "and keep getting a 500 error. This is urgent, I'm losing sales.",
        questions: {
          'urgency': NoulQuestion('Does this message express urgency?'),
          'department': ChoiceQuestion(
            'Which department should handle this?',
            criteria: {
              'returns': null,
              'shipping': 'Delivery delays, tracking, lost packages',
              'billing': 'Payment issues, invoices, refunds',
            },
          ),
          'severity': ScoreQuestion(
            'Rate the severity of this issue',
            criteria: ['cosmetic', 'workaround', 'blocking'],
          ),
        },
      ),
    );

    for (final entry in response.answers.entries) {
      final answer = entry.value;
      switch (answer) {
        case NoulAnswer(:final noul):
          print('${entry.key}: ${noul >= 0.5 ? "yes" : "no"} (p=$noul)');
        case ChoiceAnswer(:final choice, :final confidence):
          print('${entry.key}: $choice (confidence=$confidence)');
        case ScoreAnswer(:final score, :final mostLikelyDescription):
          print('${entry.key}: $score ($mostLikelyDescription)');
      }
    }

    print(
      'usage: input=${response.usage.inputTokens} '
      'output=${response.usage.outputTokens}',
    );
    print('model: ${response.model}');
  } on JevException catch (e) {
    print('System One request failed: $e');
  } finally {
    client.close();
  }
}
