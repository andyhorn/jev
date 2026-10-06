import 'package:jev/jev.dart';
import 'package:test/test.dart';

void main() {
  test('public API is exported from the barrel', () {
    expect(JevModel.latest, 'jev-latest');

    final question = NoulQuestion('test');
    expect(question, isA<Question>());

    final answer = Answer.fromJson({'type': 'noul', 'noul': 1.0});
    expect(answer, isA<NoulAnswer>());

    expect(JevClient, isA<Type>());
    expect(JevApiException, isA<Type>());
    expect(RetryPolicy.none.maxRetries, 0);
  });
}
