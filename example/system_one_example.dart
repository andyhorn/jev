import 'dart:io';

import 'package:system_one/system_one.dart';

/// Demonstrates a single System One call asking a Noul, Choice, and Score
/// question about a support-ticket-style `state`.
///
/// Requires a real System One API key in the `SYSTEM_ONE_API_KEY` environment
/// variable — this example is illustrative only and is not run by CI.
Future<void> main() async {
  if (Platform.environment['SYSTEM_ONE_API_KEY']?.isNotEmpty != true) {
    print('Cannot run example: set SYSTEM_ONE_API_KEY to a hosted API key.');
    return;
  }

  final client = SystemOneClient.fromEnvironment();

  try {
    final response = await client.systemOne(
      SystemOneRequest(
        state: SystemOneState.text(
          "Hi, I've been trying to connect my Stripe account for two days "
          "and keep getting a 500 error. This is urgent, I'm losing sales.",
        ),
        model: 'jev-latest',
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
  } on SystemOneException catch (e) {
    print('System One request failed: $e');
  } finally {
    client.close();
  }
}
