import 'dart:math';

final Random _sharedRandom = Random();

/// Controls whether and how [JevClient] retries failed requests.
class RetryPolicy {
  /// The maximum number of retry attempts after the initial request.
  final int maxRetries;

  /// The base delay used for the first retry attempt.
  final Duration initialDelay;

  /// The upper bound on any computed retry delay, before jitter.
  final Duration maxDelay;

  /// The fraction (0.0 to 1.0) of the computed delay that may be randomly
  /// subtracted as jitter.
  final double jitter;

  const RetryPolicy({
    this.maxRetries = 2,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 5),
    this.jitter = 0.25,
  });

  /// A policy that performs no retries.
  static const RetryPolicy none = RetryPolicy(maxRetries: 0);

  /// Computes the delay to wait before retry attempt [attempt] (0-indexed).
  ///
  /// The un-jittered delay is `initialDelay * 2^attempt`, capped at
  /// [maxDelay]. A random fraction of up to [jitter] of that value is then
  /// subtracted, so the result is always less than or equal to the
  /// un-jittered delay.
  Duration delayForAttempt(int attempt, {Random? random}) {
    final backoffMicros = initialDelay.inMicroseconds * pow(2, attempt);
    final cappedMicros = min(backoffMicros, maxDelay.inMicroseconds.toDouble());

    final rng = random ?? _sharedRandom;
    final jitterMicros = cappedMicros * jitter * rng.nextDouble();

    final resultMicros = (cappedMicros - jitterMicros).round();
    return Duration(microseconds: resultMicros);
  }

  /// Whether a response with [statusCode] should be retried: any 5xx status,
  /// or 408 (request timeout), or 429 (rate limited).
  bool shouldRetryStatusCode(int statusCode) {
    if (statusCode == 408 || statusCode == 429) {
      return true;
    }
    return statusCode >= 500 && statusCode <= 599;
  }
}
