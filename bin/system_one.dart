import 'dart:io';

import 'package:jev/src/cli/jev_cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runJev(
    arguments,
    stdin: stdin,
    out: stdout,
    err: stderr,
    environment: Platform.environment,
  );
}
