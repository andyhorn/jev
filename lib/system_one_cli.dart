/// Embeddable entry point for the `system_one` command-line interface.
///
/// Exposes [runSystemOne] so the command can be hosted by another Dart
/// executable; `bin/system_one.dart` is the packaged executable.
library;

export 'src/cli/system_one_cli.dart' show runSystemOne;
