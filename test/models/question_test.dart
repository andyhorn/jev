import 'package:jev/src/models/question.dart';
import 'package:test/test.dart';

void main() {
  group('NoulQuestion', () {
    test('serializes without a criteria key when none is given', () {
      final question = NoulQuestion('Does this message express urgency?');

      final json = question.toJson();

      expect(json, {
        'type': 'noul',
        'instructions': 'Does this message express urgency?',
      });
      expect(json.containsKey('criteria'), isFalse);
    });

    test('serializes with a nested criteria object when both are given', () {
      final question = NoulQuestion(
        'Is the customer requesting a refund?',
        trueCriteria: 'Customer explicitly asks for money back',
        falseCriteria: 'Customer has no refund request',
      );

      final json = question.toJson();

      expect(json, {
        'type': 'noul',
        'instructions': 'Is the customer requesting a refund?',
        'criteria': {
          'true': 'Customer explicitly asks for money back',
          'false': 'Customer has no refund request',
        },
      });
    });

    test('includes criteria with a null value when only true is set', () {
      final question = NoulQuestion(
        'Is this urgent?',
        trueCriteria: 'Explicit urgency language',
      );

      final json = question.toJson();

      expect(json['criteria'], {
        'true': 'Explicit urgency language',
        'false': null,
      });
    });

    test('includes criteria with a null value when only false is set', () {
      final question = NoulQuestion(
        'Is this urgent?',
        falseCriteria: 'No urgency language',
      );

      final json = question.toJson();

      expect(json['criteria'], {'true': null, 'false': 'No urgency language'});
    });
  });

  group('ChoiceQuestion', () {
    test('serializes correctly, including a null criteria value', () {
      final question = ChoiceQuestion(
        'Which department should handle this?',
        criteria: {
          'returns': null,
          'shipping': 'Delivery delays, tracking, lost packages',
          'billing': 'Payment issues, invoices, refunds',
        },
      );

      final json = question.toJson();

      expect(json, {
        'type': 'choice',
        'instructions': 'Which department should handle this?',
        'criteria': {
          'returns': null,
          'shipping': 'Delivery delays, tracking, lost packages',
          'billing': 'Payment issues, invoices, refunds',
        },
      });
    });

    test('throws ArgumentError when criteria is empty', () {
      expect(
        () => ChoiceQuestion('instructions', criteria: {}),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when criteria has 256 entries', () {
      final criteria = {
        for (var i = 0; i < 256; i++) 'option$i': 'description $i',
      };

      expect(
        () => ChoiceQuestion('instructions', criteria: criteria),
        throwsArgumentError,
      );
    });

    test('succeeds with 255 entries', () {
      final criteria = {
        for (var i = 0; i < 255; i++) 'option$i': 'description $i',
      };

      expect(
        () => ChoiceQuestion('instructions', criteria: criteria),
        returnsNormally,
      );
    });
  });

  group('ScoreQuestion', () {
    test('serializes correctly, preserving order', () {
      final question = ScoreQuestion(
        'Rate the severity of this bug report',
        criteria: ['cosmetic', 'workaround', 'blocking'],
      );

      final json = question.toJson();

      expect(json, {
        'type': 'score',
        'instructions': 'Rate the severity of this bug report',
        'criteria': ['cosmetic', 'workaround', 'blocking'],
      });
    });

    test('throws ArgumentError with 1 level', () {
      expect(
        () => ScoreQuestion('instructions', criteria: ['only']),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError with 11 levels', () {
      final criteria = List.generate(11, (i) => 'level $i');

      expect(
        () => ScoreQuestion('instructions', criteria: criteria),
        throwsArgumentError,
      );
    });

    test('succeeds with 2 levels', () {
      expect(
        () => ScoreQuestion('instructions', criteria: ['low', 'high']),
        returnsNormally,
      );
    });

    test('succeeds with 10 levels', () {
      final criteria = List.generate(10, (i) => 'level $i');

      expect(
        () => ScoreQuestion('instructions', criteria: criteria),
        returnsNormally,
      );
    });
  });
}
