import 'package:jev/src/jev_exception.dart';
import 'package:test/test.dart';

void main() {
  group('JevApiException.requestId', () {
    test('reads the x-typesafe-request-id header', () {
      final e = JevBadRequestException(
        statusCode: 400,
        headers: {'x-typesafe-request-id': 'req-123'},
      );

      expect(e.requestId, 'req-123');
    });

    test('is null when the header is absent', () {
      final e = JevBadRequestException(statusCode: 400, headers: {});

      expect(e.requestId, isNull);
    });
  });

  group('toString', () {
    test('JevApiException includes statusCode and requestId', () {
      final e = JevNotFoundException(
        statusCode: 404,
        headers: {'x-typesafe-request-id': 'req-404'},
      );

      expect(e.toString(), contains('404'));
      expect(e.toString(), contains('req-404'));
    });

    test('JevRateLimitException includes retryAfter', () {
      final e = JevRateLimitException(
        statusCode: 429,
        headers: const {},
        retryAfter: const Duration(seconds: 2),
      );

      expect(e.toString(), contains('retryAfter'));
    });

    test('JevConnectionException includes cause', () {
      final e = JevConnectionException(cause: 'boom');

      expect(e.toString(), contains('boom'));
    });

    test('JevResponseFormatException includes rawBody', () {
      final e = JevResponseFormatException(rawBody: 'not json');

      expect(e.toString(), contains('not json'));
    });
  });

  group('JevApiException.body', () {
    test('may carry a decoded JSON body', () {
      final e = JevBadRequestException(
        statusCode: 400,
        headers: const {},
        body: {'error': 'bad request'},
      );

      expect(e.body, {'error': 'bad request'});
    });

    test('may carry a raw string body', () {
      final e = JevBadRequestException(
        statusCode: 400,
        headers: const {},
        body: 'plain text',
      );

      expect(e.body, 'plain text');
    });

    test('may be null', () {
      final e = JevBadRequestException(statusCode: 400, headers: const {});

      expect(e.body, isNull);
    });
  });
}
