import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:system_one/src/cli/system_one_cli.dart';
import 'package:system_one/src/version.dart';
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
  final dir = Directory.systemTemp.createTempSync('system_one_cli_run');
  addTearDown(() => dir.deleteSync(recursive: true));
  final outFile = File('${dir.path}/out');
  final errFile = File('${dir.path}/err');
  final out = outFile.openWrite();
  final err = errFile.openWrite();

  final code = await runSystemOne(
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
    expect(result.out.trim(), 'system_one $systemOneVersion');
  });

  test('--help prints usage', () async {
    final result = await _run(['--help']);

    expect(result.code, 0);
    expect(result.out, contains('Usage: system_one'));
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
    final dir = Directory.systemTemp.createTempSync('system_one_cli_questions');
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

    test('with a non-http --base-url', () async {
      final result = await _run([
        '-s',
        'x',
        '-n',
        'a=b',
        '--base-url',
        'localhost:11434',
      ]);

      expect(result.code, 64);
      expect(result.err, contains('http or https'));
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

  test('missing key against the hosted API exits 1 with the 401', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(jsonEncode({'error': 'missing api key'}), 401);
    });

    final result = await _run(
      ['-s', 'x', '-n', 'a=b'],
      environment: const {},
      httpClient: client,
    );

    expect(result.code, 1);
    expect(sent.headers.containsKey('Authorization'), isFalse);
    expect(result.err, contains('401'));
    expect(result.err, contains('missing api key'));
  });

  group('--json', () {
    test('prints the response as one line of machine-readable JSON', () async {
      final result = await _run([
        '-s',
        'Please hurry!',
        '-n',
        'urgency=Is this urgent?',
        '--json',
      ], httpClient: _okClient((_) {}));

      expect(result.code, 0);
      expect(result.out.trim().split('\n'), hasLength(1));
      expect(jsonDecode(result.out), {
        'model': 'jev-1.13.0',
        'answers': {
          'urgency': {'type': 'noul', 'noul': 0.97},
        },
        'usage': {'input_tokens': 142, 'output_tokens': 8},
      });
    });

    test('emits every answer type in wire format', () async {
      final body = jsonEncode({
        'model': 'jev-1.13.0',
        'answers': {
          'urgency': {'type': 'noul', 'noul': 0.97},
          'department': {
            'type': 'choice',
            'choice': 'shipping',
            'confidence': 0.82,
            'probabilities': {
              'returns': 0.05,
              'shipping': 0.82,
              'billing': 0.13,
            },
          },
          'severity': {
            'type': 'score',
            'score': 1.43,
            'confidence': 0.71,
            'legend': {'0': 'cosmetic', '1': 'workaround', '2': 'blocking'},
            'probabilities': {'0': 0.12, '1': 0.33, '2': 0.55},
          },
        },
        'usage': {'input_tokens': 210, 'output_tokens': 24},
      });
      final client = MockClient((_) async => http.Response(body, 200));

      final result = await _run([
        '-s',
        'x',
        '-n',
        'a=b',
        '--json',
      ], httpClient: client);

      expect(result.code, 0);
      expect(jsonDecode(result.out), jsonDecode(body));
    });

    test('leaves failures on stderr with the existing exit codes', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'error': 'bad key'}), 401),
      );

      final result = await _run([
        '-s',
        'x',
        '-n',
        'a=b',
        '--json',
      ], httpClient: client);

      expect(result.code, 1);
      expect(result.out, isEmpty);
      expect(result.err, contains('bad key'));
    });

    test('usage errors still exit 64 without writing JSON', () async {
      final result = await _run(['--json', '-n', 'a=b']);

      expect(result.code, 64);
      expect(result.out, isEmpty);
      expect(result.err, contains('--state'));
    });
  });

  group('custom base URLs', () {
    test('--base-url works without an API key', () async {
      late http.Request sent;
      final result = await _run(
        ['-s', 'x', '-n', 'a=b', '--base-url', 'http://localhost:11434'],
        environment: const {},
        httpClient: _okClient((r) => sent = r),
      );

      expect(result.code, 0);
      expect(sent.url, Uri.parse('http://localhost:11434/v1/systemone'));
      expect(sent.headers.containsKey('Authorization'), isFalse);
    });

    test('TYPESAFE_BASE_URL is honored, and --base-url wins', () async {
      late http.Request sent;
      const env = {'TYPESAFE_BASE_URL': 'http://env.example'};

      await _run(
        ['-s', 'x', '-n', 'a=b'],
        environment: env,
        httpClient: _okClient((r) => sent = r),
      );
      expect(sent.url.host, 'env.example');

      await _run(
        ['-s', 'x', '-n', 'a=b', '--base-url', 'http://flag.example'],
        environment: env,
        httpClient: _okClient((r) => sent = r),
      );
      expect(sent.url.host, 'flag.example');
    });
  });
}
