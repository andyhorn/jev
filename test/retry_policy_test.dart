import 'dart:math';

import 'package:jev/src/retry_policy.dart';
import 'package:test/test.dart';

/// A [Random] whose `nextDouble` always returns a fixed value, for
/// deterministic jitter tests.
class _FixedRandom implements Random {
  final double value;

  _FixedRandom(this.value);

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => 0;
}

void main() {
  group('RetryPolicy.delayForAttempt', () {
    test('grows with attempt number but is capped at maxDelay', () {
      const policy = RetryPolicy(
        initialDelay: Duration(milliseconds: 100),
        maxDelay: Duration(seconds: 1),
        jitter: 0,
      );

      final delay0 = policy.delayForAttempt(0);
      final delay1 = policy.delayForAttempt(1);
      final delay2 = policy.delayForAttempt(2);
      final delayFar = policy.delayForAttempt(20);

      expect(delay0 < delay1, isTrue);
      expect(delay1 < delay2, isTrue);
      expect(delayFar, const Duration(seconds: 1));
    });

    test(
      'with jitter=0 is deterministic and matches initialDelay * 2^attempt',
      () {
        const policy = RetryPolicy(
          initialDelay: Duration(milliseconds: 100),
          maxDelay: Duration(seconds: 10),
          jitter: 0,
        );

        expect(policy.delayForAttempt(0), const Duration(milliseconds: 100));
        expect(policy.delayForAttempt(1), const Duration(milliseconds: 200));
        expect(policy.delayForAttempt(2), const Duration(milliseconds: 400));
      },
    );

    test('with jitter>0 and a fixed Random, produces a value strictly less '
        'than the un-jittered delay', () {
      const policy = RetryPolicy(
        initialDelay: Duration(milliseconds: 100),
        maxDelay: Duration(seconds: 10),
        jitter: 0.25,
      );

      final unjittered = policy.delayForAttempt(0, random: _FixedRandom(0));
      final jittered = policy.delayForAttempt(0, random: _FixedRandom(1));

      expect(unjittered, const Duration(milliseconds: 100));
      expect(jittered < unjittered, isTrue);
    });

    test('supports Duration.zero as initialDelay', () {
      const policy = RetryPolicy(initialDelay: Duration.zero, jitter: 0.25);

      final delay = policy.delayForAttempt(0);

      expect(delay, Duration.zero);
    });
  });

  group('RetryPolicy.shouldRetryStatusCode', () {
    const policy = RetryPolicy();

    for (final code in [408, 429, 500, 503, 529]) {
      test('returns true for $code', () {
        expect(policy.shouldRetryStatusCode(code), isTrue);
      });
    }

    for (final code in [200, 400, 401, 404, 422]) {
      test('returns false for $code', () {
        expect(policy.shouldRetryStatusCode(code), isFalse);
      });
    }
  });

  group('RetryPolicy.none', () {
    test('has maxRetries == 0', () {
      expect(RetryPolicy.none.maxRetries, 0);
    });
  });
}
