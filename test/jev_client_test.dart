import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jev/src/jev_client.dart';
import 'package:jev/src/jev_exception.dart';
import 'package:jev/src/models/answer.dart';
import 'package:jev/src/models/question.dart';
import 'package:jev/src/models/request.dart';
import 'package:jev/src/retry_policy.dart';
import 'package:test/test.dart';

const _quickstartJson = {
  'model': 'jev-1.13.0',
  'answers': {
    'urgency': {'type': 'noul', 'noul': 0.97},
  },
  'usage': {'input_tokens': 142, 'output_tokens': 8},
};

void main() {
  group('JevClient.systemOne', () {
    test(
      'sends a well-formed request and parses a successful response',
      () async {
        http.Request? capturedRequest;
        final mockClient = MockClient((request) async {
          capturedRequest = request;
          return http.Response(jsonEncode(_quickstartJson), 200);
        });

        final client = JevClient(apiKey: 'test-key', httpClient: mockClient);

        final response = await client.systemOne(
          state: 'Please refund my order immediately!',
          questions: {'urgency': NoulQuestion('Does this express urgency?')},
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
  });

  group('JevClient error mapping', () {
    Future<JevApiException> callWithStatus(
      int statusCode, {
      String body = '',
      Map<String, String> headers = const {},
    }) async {
      final mockClient = MockClient((request) async {
        return http.Response(body, statusCode, headers: headers);
      });
      final client = JevClient(
        apiKey: 'k',
        httpClient: mockClient,
        retryPolicy: RetryPolicy.none,
      );
      try {
        await client.systemOne(state: 's', questions: {});
        fail('expected an exception');
      } on JevApiException catch (e) {
        return e;
      }
    }

    test('400 maps to JevBadRequestException', () async {
      final e = await callWithStatus(
        400,
        headers: {'x-typesafe-request-id': 'req-400'},
      );
      expect(e, isA<JevBadRequestException>());
      expect(e.statusCode, 400);
      expect(e.requestId, 'req-400');
    });

    test('401 maps to JevAuthenticationException', () async {
      final e = await callWithStatus(
        401,
        headers: {'x-typesafe-request-id': 'req-401'},
      );
      expect(e, isA<JevAuthenticationException>());
      expect(e.statusCode, 401);
      expect(e.requestId, 'req-401');
    });

    test('403 maps to JevPermissionDeniedException', () async {
      final e = await callWithStatus(
        403,
        headers: {'x-typesafe-request-id': 'req-403'},
      );
      expect(e, isA<JevPermissionDeniedException>());
      expect(e.statusCode, 403);
      expect(e.requestId, 'req-403');
    });

    test('404 maps to JevNotFoundException', () async {
      final e = await callWithStatus(
        404,
        headers: {'x-typesafe-request-id': 'req-404'},
      );
      expect(e, isA<JevNotFoundException>());
      expect(e.statusCode, 404);
      expect(e.requestId, 'req-404');
    });

    test('422 maps to JevValidationException', () async {
      final e = await callWithStatus(
        422,
        headers: {'x-typesafe-request-id': 'req-422'},
      );
      expect(e, isA<JevValidationException>());
      expect(e.statusCode, 422);
      expect(e.requestId, 'req-422');
    });

    test('429 maps to JevRateLimitException', () async {
      final e = await callWithStatus(
        429,
        headers: {'x-typesafe-request-id': 'req-429'},
      );
      expect(e, isA<JevRateLimitException>());
      expect(e.statusCode, 429);
      expect(e.requestId, 'req-429');
    });

    test('529 maps to JevOverloadedException', () async {
      final e = await callWithStatus(
        529,
        headers: {'x-typesafe-request-id': 'req-529'},
      );
      expect(e, isA<JevOverloadedException>());
      expect(e.statusCode, 529);
      expect(e.requestId, 'req-529');
    });

    test('503 maps to JevServerException', () async {
      final e = await callWithStatus(
        503,
        headers: {'x-typesafe-request-id': 'req-503'},
      );
      expect(e, isA<JevServerException>());
      expect(e.statusCode, 503);
      expect(e.requestId, 'req-503');
    });

    test('408 maps to JevServerException', () async {
      final e = await callWithStatus(
        408,
        headers: {'x-typesafe-request-id': 'req-408'},
      );
      expect(e, isA<JevServerException>());
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
      expect(e, isA<JevRateLimitException>());
      expect(
        (e as JevRateLimitException).retryAfter,
        const Duration(seconds: 2),
      );
    });
  });

  group('JevClient retry behavior', () {
    test('retries a 429 and succeeds on the second attempt', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('', 429);
        }
        return http.Response(jsonEncode(_quickstartJson), 200);
      });

      final client = JevClient(
        apiKey: 'k',
        httpClient: mockClient,
        retryPolicy: const RetryPolicy(
          maxRetries: 2,
          initialDelay: Duration.zero,
        ),
      );

      final response = await client.systemOne(state: 's', questions: {});

      expect(callCount, 2);
      expect(response.model, 'jev-1.13.0');
    });

    test('exhausts retries and throws the last exception', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response('', 503);
      });

      final client = JevClient(
        apiKey: 'k',
        httpClient: mockClient,
        retryPolicy: const RetryPolicy(
          maxRetries: 1,
          initialDelay: Duration.zero,
        ),
      );

      await expectLater(
        client.systemOne(state: 's', questions: {}),
        throwsA(isA<JevServerException>()),
      );
      expect(callCount, 2);
    });

    test('does not retry a status code outside the retry set', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response('', 400);
      });

      final client = JevClient(
        apiKey: 'k',
        httpClient: mockClient,
        retryPolicy: const RetryPolicy(
          maxRetries: 2,
          initialDelay: Duration.zero,
        ),
      );

      await expectLater(
        client.systemOne(state: 's', questions: {}),
        throwsA(isA<JevBadRequestException>()),
      );
      expect(callCount, 1);
    });
  });

  group('JevClient.fromEnvironment', () {
    test(
      'throws StateError when TYPESAFE_API_KEY is unset',
      () {
        expect(() => JevClient.fromEnvironment(), throwsStateError);
      },
      skip: (Platform.environment['TYPESAFE_API_KEY']?.isNotEmpty ?? false)
          ? 'TYPESAFE_API_KEY is set in this environment'
          : null,
    );
  });

  group('JevClient response parsing failures', () {
    test(
      'a 200 response with invalid JSON throws JevResponseFormatException',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('not json', 200);
        });

        final client = JevClient(apiKey: 'k', httpClient: mockClient);

        await expectLater(
          client.systemOne(state: 's', questions: {}),
          throwsA(
            isA<JevResponseFormatException>().having(
              (e) => e.rawBody,
              'rawBody',
              'not json',
            ),
          ),
        );
      },
    );
  });
}
