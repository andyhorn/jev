import 'package:system_one/src/models/question.dart';
import 'package:system_one/src/models/request.dart';
import 'package:system_one/src/models/state.dart';
import 'package:test/test.dart';

void main() {
  test('toJson produces the full request envelope shape', () {
    final request = SystemOneRequest(
      state: SystemOneState.text(
        "Hi, I've been trying to connect my Stripe account...",
      ),
      model: 'jev-latest',
      questions: {
        'urgency': NoulQuestion('Does this message express urgency?'),
        'department': ChoiceQuestion(
          'Which department?',
          criteria: {
            'returns': null,
            'shipping': 'Delivery delays, tracking, lost packages',
            'billing': 'Payment issues, invoices, refunds',
          },
        ),
        'severity': ScoreQuestion(
          'Rate severity',
          criteria: ['cosmetic', 'workaround', 'blocking'],
        ),
      },
    );

    final json = request.toJson();

    expect(json, {
      'state': "Hi, I've been trying to connect my Stripe account...",
      'model': 'jev-latest',
      'questions': {
        'urgency': {
          'type': 'noul',
          'instructions': 'Does this message express urgency?',
        },
        'department': {
          'type': 'choice',
          'instructions': 'Which department?',
          'criteria': {
            'returns': null,
            'shipping': 'Delivery delays, tracking, lost packages',
            'billing': 'Payment issues, invoices, refunds',
          },
        },
        'severity': {
          'type': 'score',
          'instructions': 'Rate severity',
          'criteria': ['cosmetic', 'workaround', 'blocking'],
        },
      },
    });
  });

  test('allows overriding the model', () {
    final request = SystemOneRequest(
      state: SystemOneState.text('some state'),
      model: 'jev-preview',
      questions: {'urgency': NoulQuestion('Is this urgent?')},
    );

    expect(request.toJson()['model'], 'jev-preview');
  });

  test('rejects a blank model', () {
    for (final model in ['', '   ']) {
      expect(
        () => SystemOneRequest(
          state: SystemOneState.text('some state'),
          model: model,
          questions: {'urgency': NoulQuestion('Is this urgent?')},
        ),
        throwsArgumentError,
      );
    }
  });
}
