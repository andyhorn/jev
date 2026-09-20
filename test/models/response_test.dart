import 'package:jev/src/models/answer.dart';
import 'package:jev/src/models/response.dart';
import 'package:test/test.dart';

void main() {
  group('SystemOneResponse.fromJson', () {
    test('parses the full quickstart example', () {
      final json = {
        'model': 'jev-1.13.0',
        'answers': {
          'urgency': {'type': 'noul', 'noul': 0.97},
        },
        'usage': {'input_tokens': 142, 'output_tokens': 8},
      };

      final response = SystemOneResponse.fromJson(json);

      expect(response.model, 'jev-1.13.0');
      expect(response.answers['urgency'], isA<NoulAnswer>());
      expect((response.answers['urgency'] as NoulAnswer).noul, 0.97);
      expect(response.usage.inputTokens, 142);
      expect(response.usage.outputTokens, 8);
    });

    test('parses the score.md example with usage entirely absent', () {
      final json = {
        'model': 'jev-1.13.0',
        'answers': {
          'severity': {
            'type': 'score',
            'score': 1.43,
            'confidence': 0.71,
            'legend': {'0': 'cosmetic', '1': 'workaround', '2': 'blocking'},
            'probabilities': {'0': 0.12, '1': 0.33, '2': 0.55},
          },
        },
      };

      final response = SystemOneResponse.fromJson(json);

      expect(response.answers['severity'], isA<ScoreAnswer>());
      expect(response.usage.inputTokens, isNull);
      expect(response.usage.outputTokens, isNull);
    });

    test('parses the multi-answer example', () {
      final json = {
        'model': 'jev-1.13.0',
        'answers': {
          'urgency': {'type': 'noul', 'noul': 0.97},
          'department': {
            'type': 'choice',
            'choice': 'shipping',
            'confidence': 0.82,
            'probabilities': {
              'returns': 0.05,
              'shipping': 0.82,
              'billing': 0.13,
            },
          },
          'severity': {
            'type': 'score',
            'score': 1.43,
            'confidence': 0.71,
            'legend': {'0': 'cosmetic', '1': 'workaround', '2': 'blocking'},
            'probabilities': {'0': 0.12, '1': 0.33, '2': 0.55},
          },
        },
        'usage': {'input_tokens': 210, 'output_tokens': 24},
      };

      final response = SystemOneResponse.fromJson(json);

      expect(response.answers, hasLength(3));
      expect(response.answers['urgency'], isA<NoulAnswer>());
      expect(response.answers['department'], isA<ChoiceAnswer>());
      expect(response.answers['severity'], isA<ScoreAnswer>());
    });

    test('defaults answers to an empty map when absent', () {
      final json = {'model': 'jev-1.13.0'};

      final response = SystemOneResponse.fromJson(json);

      expect(response.answers, isEmpty);
    });
  });

  group('Usage.fromJson', () {
    test('returns null fields when json is null', () {
      final usage = Usage.fromJson(null);

      expect(usage.inputTokens, isNull);
      expect(usage.outputTokens, isNull);
    });

    test('parses a null output_tokens field as null', () {
      final usage = Usage.fromJson({'input_tokens': 5, 'output_tokens': null});

      expect(usage.inputTokens, 5);
      expect(usage.outputTokens, isNull);
    });
  });
}
