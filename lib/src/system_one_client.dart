import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;

import 'system_one_exception.dart';
import 'models/request.dart';
import 'models/response.dart';
import 'retry_policy.dart';

/// A client for the System One API.
class SystemOneClient {
  /// The hosted TypeSafe API, targeted when no `baseUrl` is supplied.
  static final defaultBaseUrl = Uri.parse('https://api.typesafe.ai');

  final String? _apiKey;
  final Uri _baseUrl;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Duration _timeout;
  final RetryPolicy _retryPolicy;

  /// Creates a client.
  ///
  /// When [apiKey] is non-empty it is sent as a bearer token on every
  /// request; when absent, requests carry no `Authorization` header. The
  /// hosted API rejects unauthenticated requests, but a custom or local
  /// [baseUrl] (e.g. an Ollama server) may need no key at all.
  SystemOneClient({
    String? apiKey,
    Uri? baseUrl,
    // If null, this instance creates and owns an internal [http.Client],
    // which [close] will close. If you pass your own client, you retain
    // ownership of it and [close] will not close it.
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
    RetryPolicy retryPolicy = const RetryPolicy(),
  }) : _apiKey = apiKey, // ignore: prefer_initializing_formals
       _baseUrl = baseUrl ?? defaultBaseUrl,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       // ignore: prefer_initializing_formals
       _timeout = timeout,
       // ignore: prefer_initializing_formals
       _retryPolicy = retryPolicy;

  /// Creates a client from the process environment (or [environment], for
  /// tests).
  ///
  /// `SYSTEM_ONE_API_KEY` is used as the bearer token when set.
  /// `SYSTEM_ONE_BASE_URL` overrides the endpoint when [baseUrl] is not given.
  /// Neither variable is required: without a key, requests simply carry no
  /// `Authorization` header, and the hosted API answers them with a 401.
  factory SystemOneClient.fromEnvironment({
    Uri? baseUrl,
    Map<String, String>? environment,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
    RetryPolicy retryPolicy = const RetryPolicy(),
  }) {
    final env = environment ?? Platform.environment;
    final baseUrlOverride = env['SYSTEM_ONE_BASE_URL'];
    return SystemOneClient(
      apiKey: env['SYSTEM_ONE_API_KEY'],
      baseUrl:
          baseUrl ??
          ((baseUrlOverride == null || baseUrlOverride.isEmpty)
              ? defaultBaseUrl
              : Uri.parse(baseUrlOverride)),
      httpClient: httpClient,
      timeout: timeout,
      retryPolicy: retryPolicy,
    );
  }

  /// Sends [request] to `POST /v1/systemone` and returns the parsed
  /// [SystemOneResponse].
  ///
  /// Retries according to the configured [RetryPolicy] on retryable HTTP
  /// status codes and on connection/timeout failures.
  Future<SystemOneResponse> systemOne(SystemOneRequest request) async {
    final uri = _baseUrl.resolve('/v1/systemone');
    final body = utf8.encode(jsonEncode(request.toJson()));
    final headers = <String, String>{
      if (_apiKey != null && _apiKey.isNotEmpty)
        'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json; charset=utf-8',
    };

    var attempt = 0;
    while (true) {
      SystemOneException thrownException;
      try {
        final response = await _httpClient
            .post(uri, headers: headers, body: body)
            .timeout(
              _timeout,
              onTimeout: () => throw SystemOneTimeoutException(),
            );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return _parseSuccess(response);
        }

        thrownException = _mapErrorResponse(response);
      } on SystemOneException catch (e) {
        thrownException = e;
      } catch (e) {
        thrownException = SystemOneConnectionException(cause: e);
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
  Duration? _retryDelayFor(SystemOneException exception, int attempt) {
    if (attempt >= _retryPolicy.maxRetries) {
      return null;
    }

    if (exception is SystemOneRateLimitException) {
      return exception.retryAfter ?? _retryPolicy.delayForAttempt(attempt);
    }

    if (exception is SystemOneApiException &&
        _retryPolicy.shouldRetryStatusCode(exception.statusCode)) {
      return _retryPolicy.delayForAttempt(attempt);
    }

    if (exception is SystemOneConnectionException) {
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
      throw SystemOneResponseFormatException(rawBody: rawBody, cause: e);
    }
  }

  SystemOneApiException _mapErrorResponse(http.Response response) {
    final headers = <String, String>{
      for (final entry in response.headers.entries)
        entry.key.toLowerCase(): entry.value,
    };

    final rawBody = utf8.decode(response.bodyBytes);
    final Object? body = _decodeErrorBody(rawBody);

    final statusCode = response.statusCode;
    switch (statusCode) {
      case 400:
        return SystemOneBadRequestException(
          statusCode: statusCode,
          body: body,
          headers: headers,
        );
      case 401:
        return SystemOneAuthenticationException(
          statusCode: statusCode,
          body: body,
          headers: headers,
        );
      case 403:
        return SystemOnePermissionDeniedException(
          statusCode: statusCode,
          body: body,
          headers: headers,
        );
      case 404:
        return SystemOneNotFoundException(
          statusCode: statusCode,
          body: body,
          headers: headers,
        );
      case 422:
        return SystemOneValidationException(
          statusCode: statusCode,
          body: body,
          headers: headers,
        );
      case 429:
        return SystemOneRateLimitException(
          statusCode: statusCode,
          body: body,
          headers: headers,
          retryAfter: _parseRetryAfter(headers),
        );
      case 529:
        return SystemOneOverloadedException(
          statusCode: statusCode,
          body: body,
          headers: headers,
        );
      default:
        return SystemOneServerException(
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
