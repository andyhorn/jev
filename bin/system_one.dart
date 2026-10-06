import 'dart:io';

import 'package:system_one/system_one_cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runSystemOne(
    arguments,
    stdin: stdin,
    out: stdout,
    err: stderr,
    environment: Platform.environment,
  );
}
