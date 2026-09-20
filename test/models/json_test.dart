import 'package:jev/src/models/json.dart';
import 'package:test/test.dart';

void main() {
  group('decodeIntKeyedMap', () {
    test('parses string-integer keys into int keys with converted values', () {
      final json = {'0': 0.57, '1': 0.43};

      final result = decodeIntKeyedMap<double>(
        json,
        (value) => (value as num).toDouble(),
      );

      expect(result, {0: 0.57, 1: 0.43});
    });
  });

  group('encodeIntKeyedMap', () {
    test('encodes int keys back into string keys', () {
      final map = {0: 0.57, 1: 0.43};

      final result = encodeIntKeyedMap<double>(map, (value) => value);

      expect(result, {'0': 0.57, '1': 0.43});
    });
  });

  test('round-trips a Map<int, double> through encode/decode', () {
    final original = {0: 0.12, 1: 0.33, 2: 0.55};

    final encoded = encodeIntKeyedMap<double>(original, (value) => value);
    final decoded = decodeIntKeyedMap<double>(
      encoded,
      (value) => (value as num).toDouble(),
    );

    expect(decoded, original);
  });
}
