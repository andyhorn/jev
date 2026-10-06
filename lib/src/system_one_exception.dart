/// The exception hierarchy for the `jev` client.
///
/// All exceptions thrown by [JevClient] implement this sealed base.
library;

/// The base type for every exception thrown by the `jev` client.
sealed class JevException implements Exception {}

/// The API responded with a non-2xx HTTP status code.
///
/// The exact shape of an error response body is undocumented by the
/// System One API, so [body] is intentionally left untyped — never
/// destructure it into named fields.
class JevApiException extends JevException {
  /// The HTTP status code returned by the API.
  final int statusCode;

  /// The decoded JSON error body, if the response body parsed as JSON; the
  /// raw response body as a `String` if it did not; or `null` if the
  /// response body was empty.
  final Object? body;

  /// The response headers, with keys normalized to lowercase.
  final Map<String, String> headers;

  JevApiException({required this.statusCode, this.body, required this.headers});

  /// The `x-typesafe-request-id` response header, if present.
  String? get requestId => headers['x-typesafe-request-id'];

  @override
  String toString() {
    final id = requestId;
    return '$runtimeType(statusCode: $statusCode'
        '${id != null ? ', requestId: $id' : ''})';
  }
}

/// The API rejected the request as malformed (HTTP 400).
final class JevBadRequestException extends JevApiException {
  JevBadRequestException({
    required super.statusCode,
    super.body,
    required super.headers,
  });
}

/// The API key was missing or invalid (HTTP 401).
final class JevAuthenticationException extends JevApiException {
  JevAuthenticationException({
    required super.statusCode,
    super.body,
    required super.headers,
  });
}

/// The API key was valid but lacks permission for this request (HTTP 403).
final class JevPermissionDeniedException extends JevApiException {
  JevPermissionDeniedException({
    required super.statusCode,
    super.body,
    required super.headers,
  });
}

/// The requested resource does not exist (HTTP 404).
final class JevNotFoundException extends JevApiException {
  JevNotFoundException({
    required super.statusCode,
    super.body,
    required super.headers,
  });
}

/// The request failed semantic validation (HTTP 422).
final class JevValidationException extends JevApiException {
  JevValidationException({
    required super.statusCode,
    super.body,
    required super.headers,
  });
}

/// The caller has exceeded a rate limit (HTTP 429).
final class JevRateLimitException extends JevApiException {
  /// How long the caller should wait before retrying, parsed from the
  /// `Retry-After` (seconds) or `retry-after-ms` (milliseconds) response
  /// header, if either was present.
  final Duration? retryAfter;

  JevRateLimitException({
    required super.statusCode,
    super.body,
    required super.headers,
    this.retryAfter,
  });

  @override
  String toString() {
    return '${super.toString().replaceFirst(')', '')}'
        '${retryAfter != null ? ', retryAfter: $retryAfter' : ''})';
  }
}

/// The API is temporarily overloaded (HTTP 529).
final class JevOverloadedException extends JevApiException {
  JevOverloadedException({
    required super.statusCode,
    super.body,
    required super.headers,
  });
}

/// The fallback for any HTTP status code not explicitly mapped, which in
/// practice is typically any other 5xx status code or a request timeout (HTTP 408).
final class JevServerException extends JevApiException {
  JevServerException({
    required super.statusCode,
    super.body,
    required super.headers,
  });
}

/// A network-level failure occurred before an HTTP response was received.
class JevConnectionException extends JevException {
  /// The underlying error that caused this exception, if any.
  final Object? cause;

  JevConnectionException({this.cause});

  @override
  String toString() => '$runtimeType(${cause != null ? 'cause: $cause' : ''})';
}

/// A request did not complete within the configured timeout.
final class JevTimeoutException extends JevConnectionException {
  JevTimeoutException({super.cause});
}

/// A successful (2xx) response could not be parsed as the expected shape.
final class JevResponseFormatException extends JevException {
  /// The raw, undecoded response body that failed to parse.
  final String rawBody;

  /// The underlying decode or parse error, if any.
  final Object? cause;

  JevResponseFormatException({required this.rawBody, this.cause});

  @override
  String toString() => '$runtimeType(cause: $cause, rawBody: $rawBody)';
}
