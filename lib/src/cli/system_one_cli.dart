import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;

import '../system_one_client.dart';
import '../system_one_exception.dart';
import '../models/answer.dart';
import '../models/question.dart';
import '../models/request.dart';
import '../models/response.dart';
import '../models/state.dart';
import '../version.dart';

const _exitOk = 0;
const _exitFailure = 1;
const _exitUsage = 64;

class _UsageError implements Exception {
  final String message;

  _UsageError(this.message);
}

/// Runs the `system_one` command-line interface and returns its process exit code.
///
/// [stdin], [out], [err] and [environment] are injectable so the command can
/// be exercised without touching the real process; pass [httpClient] to stub
/// the network.
Future<int> runSystemOne(
  List<String> arguments, {
  required Stream<List<int>> stdin,
  required IOSink out,
  required IOSink err,
  required Map<String, String> environment,
  http.Client? httpClient,
}) async {
  final parser = _buildParser();

  try {
    final ArgResults args;
    try {
      args = parser.parse(arguments);
    } on FormatException catch (e) {
      throw _UsageError(e.message);
    }

    if (args.flag('help')) {
      out.writeln(_usage(parser));
      return _exitOk;
    }
    if (args.flag('version')) {
      out.writeln('system_one $systemOneVersion');
      return _exitOk;
    }

    final model = args.option('model');
    if (model == null || model.isEmpty) {
      throw _UsageError('Missing required option --model.');
    }

    final request = SystemOneRequest(
      state: await _readState(args, stdin),
      model: model,
      questions: await _readQuestions(args),
    );

    final client = SystemOneClient.fromEnvironment(
      baseUrl: _resolveBaseUrl(args.option('base-url')),
      environment: environment,
      httpClient: httpClient,
    );
    try {
      final response = await client.systemOne(request);
      if (args.flag('json')) {
        out.writeln(jsonEncode(response.toJson()));
      } else {
        out.write(_formatResponse(response));
      }
      return _exitOk;
    } finally {
      client.close();
    }
  } on _UsageError catch (e) {
    err
      ..writeln('system_one: ${e.message}')
      ..writeln()
      ..writeln(_usage(parser));
    return _exitUsage;
  } on SystemOneApiException catch (e) {
    err.writeln('system_one: request failed: $e');
    if (e.body != null) {
      err.writeln(e.body is String ? e.body : jsonEncode(e.body));
    }
    return _exitFailure;
  } on SystemOneException catch (e) {
    err.writeln('system_one: request failed: $e');
    return _exitFailure;
  }
}

ArgParser _buildParser() {
  return ArgParser()
    ..addOption(
      'state',
      abbr: 's',
      valueHelp: 'text',
      help: 'The content to ask about, given inline.',
    )
    ..addOption(
      'state-file',
      abbr: 'f',
      valueHelp: 'path',
      help: 'Read the content from a file ("-" reads standard input).',
    )
    ..addOption(
      'state-format',
      allowed: ['text', 'json'],
      defaultsTo: 'text',
      help: 'How to interpret the content. "json" sends an object or array.',
    )
    ..addMultiOption(
      'noul',
      abbr: 'n',
      valueHelp: 'name=instructions',
      help: 'Add a yes/no question. May be repeated.',
    )
    ..addOption(
      'questions-file',
      abbr: 'q',
      valueHelp: 'path',
      help:
          'A JSON object of questions in the API wire format, keyed by name. '
          'Supports noul, choice and score questions.',
    )
    ..addOption(
      'model',
      abbr: 'm',
      valueHelp: 'name',
      help:
          'The model to use (required), e.g. jev-latest for '
          'TypeSafe or nimble for Ollama.',
    )
    ..addOption(
      'base-url',
      valueHelp: 'url',
      help:
          'Override the API base URL (default '
          '${SystemOneClient.defaultBaseUrl}, or SYSTEM_ONE_BASE_URL). '
          'Custom endpoints need no API key.',
    )
    ..addFlag(
      'json',
      negatable: false,
      help: 'Print the response as machine-readable JSON.',
    )
    ..addFlag('version', negatable: false, help: 'Print the version.')
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    );
}

/// Resolves the `--base-url` flag; returns null so that
/// [SystemOneClient.fromEnvironment] applies `SYSTEM_ONE_BASE_URL` or the
/// hosted default. A custom endpoint does not require an API key.
Uri? _resolveBaseUrl(String? flag) {
  if (flag == null || flag.isEmpty) {
    return null;
  }
  final Uri parsed;
  try {
    parsed = Uri.parse(flag);
  } on FormatException catch (e) {
    throw _UsageError('Invalid base URL "$flag": ${e.message}');
  }
  if (parsed.scheme != 'http' && parsed.scheme != 'https') {
    throw _UsageError('Base URL must be an http or https URL, got "$flag".');
  }
  return parsed;
}

String _usage(ArgParser parser) {
  return '''
Usage: system_one [options]

Asks System One questions about some content.

Sends the SYSTEM_ONE_API_KEY environment variable, when set, as a bearer token.
A custom --base-url (or SYSTEM_ONE_BASE_URL) endpoint, such as a local server,
needs no key.

${parser.usage}''';
}

Future<SystemOneState> _readState(
  ArgResults args,
  Stream<List<int>> stdin,
) async {
  final inline = args.option('state');
  final path = args.option('state-file');
  if ((inline == null) == (path == null)) {
    throw _UsageError('Provide exactly one of --state or --state-file.');
  }

  final String raw;
  if (inline != null) {
    raw = inline;
  } else if (path == '-') {
    raw = await utf8.decodeStream(stdin);
  } else {
    raw = await _readFile(path!);
  }

  if (args.option('state-format') == 'text') {
    return SystemOneState.text(raw);
  }

  final decoded = _decodeJson(raw, 'state');
  return switch (decoded) {
    Map<String, dynamic>() => SystemOneState.object(decoded),
    List<dynamic>() => SystemOneState.array(decoded),
    _ => throw _UsageError('A JSON state must be an object or an array.'),
  };
}

Future<Map<String, Question>> _readQuestions(ArgResults args) async {
  final questions = <String, Question>{};

  void add(String name, Question question) {
    if (questions.containsKey(name)) {
      throw _UsageError('Question "$name" is defined more than once.');
    }
    questions[name] = question;
  }

  final path = args.option('questions-file');
  if (path != null) {
    final decoded = _decodeJson(await _readFile(path), 'questions file');
    if (decoded is! Map<String, dynamic>) {
      throw _UsageError('The questions file must contain a JSON object.');
    }
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) {
        throw _UsageError('Question "${entry.key}" must be a JSON object.');
      }
      try {
        add(entry.key, Question.fromJson(value));
      } on FormatException catch (e) {
        throw _UsageError('Question "${entry.key}": ${e.message}');
      } on ArgumentError catch (e) {
        throw _UsageError('Question "${entry.key}": ${e.message}');
      }
    }
  }

  for (final spec in args.multiOption('noul')) {
    final separator = spec.indexOf('=');
    if (separator <= 0) {
      throw _UsageError('--noul expects name=instructions, got "$spec".');
    }
    add(
      spec.substring(0, separator),
      NoulQuestion(spec.substring(separator + 1)),
    );
  }

  if (questions.isEmpty) {
    throw _UsageError('Provide at least one question.');
  }
  return questions;
}

Future<String> _readFile(String path) async {
  try {
    return await File(path).readAsString();
  } on FileSystemException catch (e) {
    throw _UsageError('Cannot read $path: ${e.osError?.message ?? e.message}');
  }
}

Object? _decodeJson(String raw, String what) {
  try {
    return jsonDecode(raw);
  } on FormatException catch (e) {
    throw _UsageError('Invalid JSON in $what: ${e.message}');
  }
}

String _formatResponse(SystemOneResponse response) {
  final buffer = StringBuffer();
  for (final entry in response.answers.entries) {
    final description = switch (entry.value) {
      NoulAnswer(:final noul) => '${noul >= 0.5 ? 'yes' : 'no'} (p=$noul)',
      ChoiceAnswer(:final choice, :final confidence) =>
        '$choice (confidence=$confidence)',
      ScoreAnswer(:final score, :final mostLikelyDescription) =>
        '$score ($mostLikelyDescription)',
    };
    buffer.writeln('${entry.key}: $description');
  }
  buffer
    ..writeln(
      'usage: input=${response.usage.inputTokens} '
      'output=${response.usage.outputTokens}',
    )
    ..writeln('model: ${response.model}');
  return buffer.toString();
}
