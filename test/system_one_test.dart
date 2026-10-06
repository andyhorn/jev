import 'package:system_one/system_one.dart';
import 'package:test/test.dart';

void main() {
  test('public API is exported from the barrel', () {
    final question = NoulQuestion('test');
    expect(question, isA<Question>());

    final answer = Answer.fromJson({'type': 'noul', 'noul': 1.0});
    expect(answer, isA<NoulAnswer>());

    expect(SystemOneClient, isA<Type>());
    expect(SystemOneApiException, isA<Type>());
    expect(RetryPolicy.none.maxRetries, 0);
  });
}
