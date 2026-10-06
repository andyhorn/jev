import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jev/src/cli/jev_cli.dart';
import 'package:jev/src/version.dart';
import 'package:test/test.dart';

class _Result {
  final int code;
  final String out;
  final String err;

  _Result(this.code, this.out, this.err);
}

Future<_Result> _run(
  List<String> args, {
  Map<String, String> environment = const {'TYPESAFE_API_KEY': 'sk-test'},
  String stdinText = '',
  http.Client? httpClient,
}) async {
  final dir = Directory.systemTemp.createTempSync('jev_cli_run');
  addTearDown(() => dir.deleteSync(recursive: true));
  final outFile = File('${dir.path}/out');
  final errFile = File('${dir.path}/err');
  final out = outFile.openWrite();
  final err = errFile.openWrite();

  final code = await runJev(
    args,
    stdin: Stream.value(utf8.encode(stdinText)),
    out: out,
    err: err,
    environment: environment,
    httpClient: httpClient,
  );

  await out.close();
  await err.close();
  return _Result(code, outFile.readAsStringSync(), errFile.readAsStringSync());
}

MockClient _okClient(void Function(http.Request) onRequest) {
  return MockClient((request) async {
    onRequest(request);
    return http.Response(
      jsonEncode({
        'model': 'jev-1.13.0',
        'answers': {
          'urgency': {'type': 'noul', 'noul': 0.97},
        },
        'usage': {'input_tokens': 142, 'output_tokens': 8},
      }),
      200,
    );
  });
}

void main() {
  test('--version prints the package version', () async {
    final result = await _run(['--version']);

    expect(result.code, 0);
    expect(result.out.trim(), 'jev $jevVersion');
  });

  test('--help prints usage', () async {
    final result = await _run(['--help']);

    expect(result.code, 0);
    expect(result.out, contains('Usage: jev'));
  });

  test('sends a text state and noul question, then prints answers', () async {
    late http.Request sent;
    final result = await _run([
      '--state',
      'Please hurry!',
      '--noul',
      'urgency=Is this urgent?',
    ], httpClient: _okClient((r) => sent = r));

    expect(result.code, 0);
    expect(result.out, contains('urgency: yes (p=0.97)'));
    expect(result.out, contains('usage: input=142 output=8'));
    expect(result.out, contains('model: jev-1.13.0'));
    expect(sent.headers['Authorization'], 'Bearer sk-test');
    expect(jsonDecode(sent.body), {
      'state': 'Please hurry!',
      'model': 'jev-latest',
      'questions': {
        'urgency': {'type': 'noul', 'instructions': 'Is this urgent?'},
      },
    });
  });

  test('reads a JSON state from stdin', () async {
    late http.Request sent;
    final result = await _run(
      ['-f', '-', '--state-format', 'json', '-n', 'urgency=Is this urgent?'],
      stdinText: '{"subject": "Help"}',
      httpClient: _okClient((r) => sent = r),
    );

    expect(result.code, 0);
    expect(jsonDecode(sent.body)['state'], {'subject': 'Help'});
  });

  test('loads choice and score questions from a questions file', () async {
    late http.Request sent;
    final dir = Directory.systemTemp.createTempSync('jev_cli_questions');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/questions.json')
      ..writeAsStringSync(
        jsonEncode({
          'department': {
            'type': 'choice',
            'instructions': 'Who handles this?',
            'criteria': {'billing': 'Payments', 'shipping': null},
          },
          'severity': {
            'type': 'score',
            'instructions': 'How bad?',
            'criteria': ['minor', 'major'],
          },
        }),
      );

    final result = await _run([
      '-s',
      'text',
      '-q',
      file.path,
      '-n',
      'urgency=Urgent?',
    ], httpClient: _okClient((r) => sent = r));

    expect(result.code, 0);
    final questions = jsonDecode(sent.body)['questions'] as Map;
    expect(questions.keys, ['department', 'severity', 'urgency']);
  });

  group('usage errors exit 64', () {
    test('without an API key', () async {
      final result = await _run([
        '-s',
        'x',
        '-n',
        'a=b',
      ], environment: const {});

      expect(result.code, 64);
      expect(result.err, contains('TYPESAFE_API_KEY'));
    });

    test('without a state', () async {
      final result = await _run(['-n', 'a=b']);

      expect(result.code, 64);
      expect(result.err, contains('--state'));
    });

    test('without questions', () async {
      final result = await _run(['-s', 'x']);

      expect(result.code, 64);
      expect(result.err, contains('at least one question'));
    });

    test('with a malformed --noul', () async {
      final result = await _run(['-s', 'x', '-n', 'nope']);

      expect(result.code, 64);
      expect(result.err, contains('name=instructions'));
    });

    test('with duplicate question names', () async {
      final result = await _run(['-s', 'x', '-n', 'a=b', '-n', 'a=c']);

      expect(result.code, 64);
      expect(result.err, contains('more than once'));
    });

    test('with a non-object/array JSON state', () async {
      final result = await _run([
        '-s',
        '5',
        '--state-format',
        'json',
        '-n',
        'a=b',
      ]);

      expect(result.code, 64);
    });
  });

  test('API failures exit 1 with the error body', () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode({'error': 'bad key'}), 401),
    );

    final result = await _run(['-s', 'x', '-n', 'a=b'], httpClient: client);

    expect(result.code, 1);
    expect(result.err, contains('401'));
    expect(result.err, contains('bad key'));
  });
}
