import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:system_one/src/system_one_client.dart';
import 'package:system_one/src/system_one_exception.dart';
import 'package:system_one/src/models/answer.dart';
import 'package:system_one/src/models/question.dart';
import 'package:system_one/src/models/request.dart';
import 'package:system_one/src/models/state.dart';
import 'package:system_one/src/retry_policy.dart';
import 'package:test/test.dart';

class _SpyHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request);
  }

  @override
  void close() {
    closed = true;
    _inner.close();
  }
}

const _quickstartJson = {
  'model': 'jev-1.13.0',
  'answers': {
    'urgency': {'type': 'noul', 'noul': 0.97},
  },
  'usage': {'input_tokens': 142, 'output_tokens': 8},
};

void main() {
  group('SystemOneClient.systemOne', () {
    test(
      'sends a well-formed request and parses a successful response',
      () async {
        http.Request? capturedRequest;
        final mockClient = MockClient((request) async {
          capturedRequest = request;
          return http.Response(jsonEncode(_quickstartJson), 200);
        });

        final client = SystemOneClient(
          apiKey: 'test-key',
          httpClient: mockClient,
        );

        final response = await client.systemOne(
          SystemOneRequest(
            state: SystemOneState.text('Please refund my order immediately!'),
            questions: {'urgency': NoulQuestion('Does this express urgency?')},
          ),
        );

        expect(capturedRequest, isNotNull);
        expect(capturedRequest!.method, 'POST');
        expect(
          capturedRequest!.url,
          Uri.parse('https://api.typesafe.ai/v1/systemone'),
        );
        expect(capturedRequest!.headers['Authorization'], 'Bearer test-key');
        expect(
          capturedRequest!.headers['Content-Type'],
          'application/json; charset=utf-8',
        );

        final sentBody =
            jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
        expect(sentBody['state'], 'Please refund my order immediately!');
        expect(sentBody['model'], JevModel.latest);
        expect(sentBody['questions'], {
          'urgency': {
            'type': 'noul',
            'instructions': 'Does this express urgency?',
          },
        });

        expect(response.model, 'jev-1.13.0');
        expect(response.answers['urgency'], isA<NoulAnswer>());
        expect((response.answers['urgency'] as NoulAnswer).noul, 0.97);
        expect(response.usage.inputTokens, 142);
        expect(response.usage.outputTokens, 8);
      },
    );

    test('omits the Authorization header when no API key is given', () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode(_quickstartJson), 200);
      });

      final client = SystemOneClient(httpClient: mockClient);
      await client.systemOne(
        SystemOneRequest(state: SystemOneState.text('s'), questions: {}),
      );

      expect(capturedRequest!.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('SystemOneClient error mapping', () {
    Future<SystemOneApiException> callWithStatus(
      int statusCode, {
      String body = '',
      Map<String, String> headers = const {},
    }) async {
      final mockClient = MockClient((request) async {
        return http.Response(body, statusCode, headers: headers);
      });
      final client = SystemOneClient(
        apiKey: 'k',
        httpClient: mockClient,
        retryPolicy: RetryPolicy.none,
      );
      try {
        await client.systemOne(
          SystemOneRequest(state: SystemOneState.text('s'), questions: {}),
        );
        fail('expected an exception');
      } on SystemOneApiException catch (e) {
        return e;
      }
    }

    test('400 maps to SystemOneBadRequestException', () async {
      final e = await callWithStatus(
        400,
        headers: {'x-typesafe-request-id': 'req-400'},
      );
      expect(e, isA<SystemOneBadRequestException>());
      expect(e.statusCode, 400);
      expect(e.requestId, 'req-400');
    });

    test('401 maps to SystemOneAuthenticationException', () async {
      final e = await callWithStatus(
        401,
        headers: {'x-typesafe-request-id': 'req-401'},
      );
      expect(e, isA<SystemOneAuthenticationException>());
      expect(e.statusCode, 401);
      expect(e.requestId, 'req-401');
    });

    test('403 maps to SystemOnePermissionDeniedException', () async {
      final e = await callWithStatus(
        403,
        headers: {'x-typesafe-request-id': 'req-403'},
      );
      expect(e, isA<SystemOnePermissionDeniedException>());
      expect(e.statusCode, 403);
      expect(e.requestId, 'req-403');
    });

    test('404 maps to SystemOneNotFoundException', () async {
      final e = await callWithStatus(
        404,
        headers: {'x-typesafe-request-id': 'req-404'},
      );
      expect(e, isA<SystemOneNotFoundException>());
      expect(e.statusCode, 404);
      expect(e.requestId, 'req-404');
    });

    test('422 maps to SystemOneValidationException', () async {
      final e = await callWithStatus(
        422,
        headers: {'x-typesafe-request-id': 'req-422'},
      );
      expect(e, isA<SystemOneValidationException>());
      expect(e.statusCode, 422);
      expect(e.requestId, 'req-422');
    });

    test('429 maps to SystemOneRateLimitException', () async {
      final e = await callWithStatus(
        429,
        headers: {'x-typesafe-request-id': 'req-429'},
      );
      expect(e, isA<SystemOneRateLimitException>());
      expect(e.statusCode, 429);
      expect(e.requestId, 'req-429');
    });

    test('529 maps to SystemOneOverloadedException', () async {
      final e = await callWithStatus(
        529,
        headers: {'x-typesafe-request-id': 'req-529'},
      );
      expect(e, isA<SystemOneOverloadedException>());
      expect(e.statusCode, 529);
      expect(e.requestId, 'req-529');
    });

    test('503 maps to SystemOneServerException', () async {
      final e = await callWithStatus(
        503,
        headers: {'x-typesafe-request-id': 'req-503'},
      );
      expect(e, isA<SystemOneServerException>());
      expect(e.statusCode, 503);
      expect(e.requestId, 'req-503');
    });

    test('408 maps to SystemOneServerException', () async {
      final e = await callWithStatus(
        408,
        headers: {'x-typesafe-request-id': 'req-408'},
      );
      expect(e, isA<SystemOneServerException>());
      expect(e.statusCode, 408);
      expect(e.requestId, 'req-408');
    });

    test(
      'a non-JSON error body is captured as a String, without throwing',
      () async {
        final e = await callWithStatus(400, body: 'plain text error');
        expect(e.body, 'plain text error');
      },
    );

    test('an empty error body results in body == null', () async {
      final e = await callWithStatus(400, body: '');
      expect(e.body, isNull);
    });

    test('429 with a Retry-After header populates retryAfter', () async {
      final e = await callWithStatus(429, headers: {'Retry-After': '2'});
      expect(e, isA<SystemOneRateLimitException>());
      expect(
        (e as SystemOneRateLimitException).retryAfter,
        const Duration(seconds: 2),
      );
    });
  });

  group('SystemOneClient retry behavior', () {
    test('retries a 429 and succeeds on the second attempt', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('', 429);
        }
        return http.Response(jsonEncode(_quickstartJson), 200);
      });

      final client = SystemOneClient(
        apiKey: 'k',
        httpClient: mockClient,
        retryPolicy: const RetryPolicy(
          maxRetries: 2,
          initialDelay: Duration.zero,
        ),
      );

      final response = await client.systemOne(
        SystemOneRequest(state: SystemOneState.text('s'), questions: {}),
      );

      expect(callCount, 2);
      expect(response.model, 'jev-1.13.0');
    });

    test('exhausts retries and throws the last exception', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response('', 503);
      });

      final client = SystemOneClient(
        apiKey: 'k',
        httpClient: mockClient,
        retryPolicy: const RetryPolicy(
          maxRetries: 1,
          initialDelay: Duration.zero,
        ),
      );

      await expectLater(
        client.systemOne(
          SystemOneRequest(state: SystemOneState.text('s'), questions: {}),
        ),
        throwsA(isA<SystemOneServerException>()),
      );
      expect(callCount, 2);
    });

    test('does not retry a status code outside the retry set', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response('', 400);
      });

      final client = SystemOneClient(
        apiKey: 'k',
        httpClient: mockClient,
        retryPolicy: const RetryPolicy(
          maxRetries: 2,
          initialDelay: Duration.zero,
        ),
      );

      await expectLater(
        client.systemOne(
          SystemOneRequest(state: SystemOneState.text('s'), questions: {}),
        ),
        throwsA(isA<SystemOneBadRequestException>()),
      );
      expect(callCount, 1);
    });
  });

  group('SystemOneClient.fromEnvironment', () {
    Future<http.Request> capture(
      Map<String, String> environment, {
      Uri? baseUrl,
    }) async {
      late http.Request sent;
      final mockClient = MockClient((request) async {
        sent = request;
        return http.Response(jsonEncode(_quickstartJson), 200);
      });
      final client = SystemOneClient.fromEnvironment(
        baseUrl: baseUrl,
        environment: environment,
        httpClient: mockClient,
      );
      await client.systemOne(
        SystemOneRequest(state: SystemOneState.text('s'), questions: {}),
      );
      return sent;
    }

    test('sends TYPESAFE_API_KEY as a bearer token when set', () async {
      final sent = await capture(const {'TYPESAFE_API_KEY': 'sk-env'});
      expect(sent.headers['Authorization'], 'Bearer sk-env');
    });

    test(
      'sends no Authorization header when the key is unset or empty',
      () async {
        final unset = await capture(const {});
        expect(unset.headers.containsKey('Authorization'), isFalse);

        final empty = await capture(const {'TYPESAFE_API_KEY': ''});
        expect(empty.headers.containsKey('Authorization'), isFalse);
      },
    );

    test('targets TYPESAFE_BASE_URL when set', () async {
      final sent = await capture(const {
        'TYPESAFE_BASE_URL': 'http://localhost:11434',
      });
      expect(sent.url, Uri.parse('http://localhost:11434/v1/systemone'));
    });

    test('prefers an explicit baseUrl over TYPESAFE_BASE_URL', () async {
      final sent = await capture(const {
        'TYPESAFE_BASE_URL': 'http://env.example',
      }, baseUrl: Uri.parse('http://explicit.example'));
      expect(sent.url, Uri.parse('http://explicit.example/v1/systemone'));
    });
  });

  group('SystemOneClient.close', () {
    test('does not close a caller-supplied http.Client', () {
      final spy = _SpyHttpClient();
      final client = SystemOneClient(apiKey: 'k', httpClient: spy);

      client.close();

      expect(spy.closed, isFalse);
    });
  });

  group('SystemOneClient response parsing failures', () {
    test('a 200 response with invalid JSON throws SystemOneResponseFormatException', () async {
      final mockClient = MockClient((request) async {
        return http.Response('not json', 200);
      });

      final client = SystemOneClient(apiKey: 'k', httpClient: mockClient);

      await expectLater(
        client.systemOne(
          SystemOneRequest(state: SystemOneState.text('s'), questions: {}),
        ),
        throwsA(
          isA<SystemOneResponseFormatException>().having(
            (e) => e.rawBody,
            'rawBody',
            'not json',
          ),
        ),
      );
    });
  });
}
