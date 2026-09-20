import 'package:jev/src/models/answer.dart';
import 'package:test/test.dart';

void main() {
  group('NoulAnswer', () {
    test('parses correctly from the docs quickstart fixture', () {
      final json = {'type': 'noul', 'noul': 0.97};

      final answer = Answer.fromJson(json);

      expect(answer, isA<NoulAnswer>());
      expect((answer as NoulAnswer).noul, 0.97);
    });

    test('parses successfully with no confidence field present', () {
      final json = {'type': 'noul', 'noul': 0.97};

      expect(() => Answer.fromJson(json), returnsNormally);
    });
  });

  group('ChoiceAnswer', () {
    test('parses correctly from the docs choice fixture', () {
      final json = {
        'type': 'choice',
        'choice': 'shipping',
        'confidence': 0.82,
        'probabilities': {'returns': 0.05, 'shipping': 0.82, 'billing': 0.13},
      };

      final answer = Answer.fromJson(json);

      expect(answer, isA<ChoiceAnswer>());
      final choice = answer as ChoiceAnswer;
      expect(choice.choice, 'shipping');
      expect(choice.confidence, 0.82);
      expect(choice.probabilities, {
        'returns': 0.05,
        'shipping': 0.82,
        'billing': 0.13,
      });
    });
  });

  group('ScoreAnswer', () {
    test('parses correctly from the docs score fixture', () {
      final json = {
        'type': 'score',
        'score': 1.43,
        'confidence': 0.71,
        'legend': {'0': 'cosmetic', '1': 'workaround', '2': 'blocking'},
        'probabilities': {'0': 0.12, '1': 0.33, '2': 0.55},
      };

      final answer = Answer.fromJson(json);

      expect(answer, isA<ScoreAnswer>());
      final score = answer as ScoreAnswer;
      expect(score.score, 1.43);
      expect(score.confidence, 0.71);
      expect(score.legend, {0: 'cosmetic', 1: 'workaround', 2: 'blocking'});
      expect(score.probabilities, {0: 0.12, 1: 0.33, 2: 0.55});
      expect(score.mostLikelyLevel, 2);
      expect(score.mostLikelyDescription, 'blocking');
    });

    test('parses with a non-string legend value without throwing', () {
      final json = {
        'type': 'score',
        'score': 2.0,
        'confidence': 0.9,
        'legend': {
          '0': 'cosmetic',
          '1': {'summary': 'blocking issue'},
        },
        'probabilities': {'0': 0.1, '1': 0.9},
      };

      final answer = Answer.fromJson(json);

      expect(answer, isA<ScoreAnswer>());
      final score = answer as ScoreAnswer;
      expect(score.legend[1], {'summary': 'blocking issue'});
      expect(score.mostLikelyDescription, {'summary': 'blocking issue'});
    });
  });

  test('Answer.fromJson throws FormatException for an unrecognized type', () {
    final json = {'type': 'bogus'};

    expect(() => Answer.fromJson(json), throwsA(isA<FormatException>()));
  });
}
