import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;

import 'jev_exception.dart';
import 'models/request.dart';
import 'models/response.dart';
import 'models/question.dart';
import 'retry_policy.dart';

/// A client for the TypeSafe AI System One API.
class JevClient {
  final String _apiKey;
  final Uri _baseUrl;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Duration _timeout;
  final RetryPolicy _retryPolicy;

  /// Creates a client authenticated with [apiKey].
  JevClient({
    required String apiKey,
    Uri? baseUrl,
    // If null, this instance creates and owns an internal [http.Client],
    // which [close] will close. If you pass your own client, you retain
    // ownership of it and [close] will not close it.
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
    RetryPolicy retryPolicy = const RetryPolicy(),
  }) : _apiKey = apiKey, // ignore: prefer_initializing_formals
       _baseUrl = baseUrl ?? Uri.parse('https://api.typesafe.ai'),
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       // ignore: prefer_initializing_formals
       _timeout = timeout,
       // ignore: prefer_initializing_formals
       _retryPolicy = retryPolicy;

  /// Creates a client using the API key from the `TYPESAFE_API_KEY`
  /// environment variable.
  ///
  /// Throws a [StateError] if that variable is unset or empty.
  factory JevClient.fromEnvironment({
    Uri? baseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
    RetryPolicy retryPolicy = const RetryPolicy(),
  }) {
    final apiKey = Platform.environment['TYPESAFE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError(
        'The TYPESAFE_API_KEY environment variable is not set. '
        'Set it to your System One API key, or use the default '
        'JevClient constructor to pass one explicitly.',
      );
    }
    return JevClient(
      apiKey: apiKey,
      baseUrl: baseUrl,
      httpClient: httpClient,
      timeout: timeout,
      retryPolicy: retryPolicy,
    );
  }

  /// Asks [questions] about [state] using [model], returning the parsed
  /// [SystemOneResponse].
  Future<SystemOneResponse> systemOne({
    required Object state,
    required Map<String, Question> questions,
    String model = JevModel.latest,
  }) {
    final request = SystemOneRequest(
      state: state,
      model: model,
      questions: questions,
    );
    return systemOneRaw(request);
  }

  /// Sends [request] to `POST /v1/systemone` and returns the parsed
  /// [SystemOneResponse].
  ///
  /// Retries according to the configured [RetryPolicy] on retryable HTTP
  /// status codes and on connection/timeout failures.
  Future<SystemOneResponse> systemOneRaw(SystemOneRequest request) async {
    final uri = _baseUrl.resolve('/v1/systemone');
    final body = utf8.encode(jsonEncode(request.toJson()));
    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json; charset=utf-8',
    };

    var attempt = 0;
    while (true) {
      JevException thrownException;
      try {
        final response = await _httpClient
            .post(uri, headers: headers, body: body)
            .timeout(_timeout, onTimeout: () => throw JevTimeoutException());

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return _parseSuccess(response);
        }

        thrownException = _mapErrorResponse(response);
      } on JevException catch (e) {
        thrownException = e;
      } catch (e) {
        thrownException = JevConnectionException(cause: e);
      }

      final retryDelay = _retryDelayFor(thrownException, attempt);
      if (retryDelay == null) {
        throw thrownException;
      }
      attempt++;
      await Future<void>.delayed(retryDelay);
    }
  }

  /// Returns the delay to wait before retrying after [exception], or `null`
  /// if [exception] should not be retried (either it isn't a retryable kind,
  /// or no attempts remain).
  Duration? _retryDelayFor(JevException exception, int attempt) {
    if (attempt >= _retryPolicy.maxRetries) {
      return null;
    }

    if (exception is JevRateLimitException) {
      return exception.retryAfter ?? _retryPolicy.delayForAttempt(attempt);
    }

    if (exception is JevApiException &&
        _retryPolicy.shouldRetryStatusCode(exception.statusCode)) {
      return _retryPolicy.delayForAttempt(attempt);
    }

    if (exception is JevConnectionException) {
      return _retryPolicy.delayForAttempt(attempt);
    }

    return null;
  }

  SystemOneResponse _parseSuccess(http.Response response) {
    final rawBody = utf8.decode(response.bodyBytes);
    try {
      final json = jsonDecode(rawBody) as Map<String, dynamic>;
      return SystemOneResponse.fromJson(json);
    } catch (e) {
      throw JevResponseFormatException(rawBody: rawBody, cause: e);
    }
  }

  JevApiException _mapErrorResponse(http.Response response) {
    final headers = <String, String>{
      for (final entry in response.headers.entries)
        entry.key.toLowerCase(): entry.value,
    };

    final rawBody = utf8.decode(response.bodyBytes);
    final Object? body = _decodeErrorBody(rawBody);

    final statusCode = response.statusCode;
    switch (statusCode) {
      case 400:
        return JevBadRequestException(
          statusCode: statusCode,
          body: body,
          headers: headers,
        );
      case 401:
        return JevAuthenticationException(
          statusCode: statusCode,
          body: body,
          headers: headers,
        );
      case 403:
        return JevPermissionDeniedException(
          statusCode: statusCode,
          body: body,
          headers: headers,
        );
      case 404:
        return JevNotFoundException(
          statusCode: statusCode,
          body: body,
          headers: headers,
        );
      case 422:
        return JevValidationException(
          statusCode: statusCode,
          body: body,
          headers: headers,
        );
      case 429:
        return JevRateLimitException(
          statusCode: statusCode,
          body: body,
          headers: headers,
          retryAfter: _parseRetryAfter(headers),
        );
      case 529:
        return JevOverloadedException(
          statusCode: statusCode,
          body: body,
          headers: headers,
        );
      default:
        return JevServerException(
          statusCode: statusCode,
          body: body,
          headers: headers,
        );
    }
  }

  Object? _decodeErrorBody(String rawBody) {
    if (rawBody.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(rawBody);
    } on FormatException {
      return rawBody;
    }
  }

  Duration? _parseRetryAfter(Map<String, String> headers) {
    final retryAfterMs = headers['retry-after-ms'];
    if (retryAfterMs != null) {
      final ms = int.tryParse(retryAfterMs);
      if (ms != null) {
        return Duration(milliseconds: ms);
      }
    }

    final retryAfter = headers['retry-after'];
    if (retryAfter != null) {
      final seconds = int.tryParse(retryAfter);
      if (seconds != null) {
        return Duration(seconds: seconds);
      }
    }

    return null;
  }

  /// Closes this client.
  ///
  /// If this instance created its own internal [http.Client] (because none
  /// was passed to the constructor), this closes it. If a client was passed
  /// in explicitly, the caller retains ownership and it is left open.
  void close() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}
