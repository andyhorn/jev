import 'package:system_one/src/system_one_exception.dart';
import 'package:test/test.dart';

void main() {
  group('SystemOneApiException.requestId', () {
    test('reads the x-typesafe-request-id header', () {
      final e = SystemOneBadRequestException(
        statusCode: 400,
        headers: {'x-typesafe-request-id': 'req-123'},
      );

      expect(e.requestId, 'req-123');
    });

    test('is null when the header is absent', () {
      final e = SystemOneBadRequestException(statusCode: 400, headers: {});

      expect(e.requestId, isNull);
    });
  });

  group('toString', () {
    test('SystemOneApiException includes statusCode and requestId', () {
      final e = SystemOneNotFoundException(
        statusCode: 404,
        headers: {'x-typesafe-request-id': 'req-404'},
      );

      expect(e.toString(), contains('404'));
      expect(e.toString(), contains('req-404'));
    });

    test('SystemOneRateLimitException includes retryAfter', () {
      final e = SystemOneRateLimitException(
        statusCode: 429,
        headers: const {},
        retryAfter: const Duration(seconds: 2),
      );

      expect(e.toString(), contains('retryAfter'));
    });

    test('SystemOneConnectionException includes cause', () {
      final e = SystemOneConnectionException(cause: 'boom');

      expect(e.toString(), contains('boom'));
    });

    test('SystemOneResponseFormatException includes rawBody', () {
      final e = SystemOneResponseFormatException(rawBody: 'not json');

      expect(e.toString(), contains('not json'));
    });
  });

  group('SystemOneApiException.body', () {
    test('may carry a decoded JSON body', () {
      final e = SystemOneBadRequestException(
        statusCode: 400,
        headers: const {},
        body: {'error': 'bad request'},
      );

      expect(e.body, {'error': 'bad request'});
    });

    test('may carry a raw string body', () {
      final e = SystemOneBadRequestException(
        statusCode: 400,
        headers: const {},
        body: 'plain text',
      );

      expect(e.body, 'plain text');
    });

    test('may be null', () {
      final e = SystemOneBadRequestException(
        statusCode: 400,
        headers: const {},
      );

      expect(e.body, isNull);
    });
  });
}
