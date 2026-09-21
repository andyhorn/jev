# jev

An unofficial Dart client for [TypeSafe AI](https://typesafe.ai)'s System One
("Jev") API. See the [official API docs](https://docs.typesafe.ai) for details
on the underlying service.

This is an experimental, play-project client. It is not affiliated with,
endorsed by, or supported by TypeSafe AI, and it is not published to pub.dev
(`publish_to: none` in `pubspec.yaml`) — pull it directly from this
repository if you want to use it.

## Getting started

You'll need a System One API key. Either set it in the `TYPESAFE_API_KEY`
environment variable and use `JevClient.fromEnvironment()`, or pass it
directly to the default constructor:

```dart
import 'package:jev/jev.dart';

final client = JevClient.fromEnvironment();
// or: final client = JevClient(apiKey: 'sk-...');
```

Then ask one or more named questions about some `state`:

```dart
final response = await client.systemOne(
  SystemOneRequest(
    state: "Hi, I've been trying to connect my Stripe account for two days "
        "and keep getting a 500 error. This is urgent, I'm losing sales.",
    questions: {
      'urgency': NoulQuestion('Does this message express urgency?'),
      'severity': ScoreQuestion(
        'Rate the severity of this issue',
        criteria: ['cosmetic', 'workaround', 'blocking'],
      ),
    },
  ),
);

for (final entry in response.answers.entries) {
  print('${entry.key}: ${entry.value}');
}

client.close();
```

See `example/jev_example.dart` for a fuller, runnable example that
demonstrates all three question types (`NoulQuestion`, `ChoiceQuestion`,
`ScoreQuestion`) and exhaustive pattern matching over the `Answer` types.

## AI agent skill

This repo ships the [TypeSafe AI agent skill](.claude/skills/typesafe-ai/SKILL.md)
for Claude Code. If you use a different coding agent, install it for your own
tool with [skills.sh](https://skills.sh):

```bash
npx skills add typesafe-ai/skills --skill typesafe-ai
```

You'll be prompted to select your agent.

## Handling answers

`Answer` is a sealed class with three subtypes — `NoulAnswer`,
`ChoiceAnswer`, and `ScoreAnswer` — so a `switch` over an `Answer` is  
exhaustive.

```dart
for (final entry in response.answers.entries) {
  final message = switch (entry.value) {
    NoulAnswer(:final noul) => noul >= 0.5 ? 'yes' : 'no ($noul)',
    ChoiceAnswer(:final choice, :final confidence) =>
      '$choice (confidence=$confidence)',
    ScoreAnswer(:final score, :final mostLikelyDescription) =>
      '$score ($mostLikelyDescription)',
  };
  print('${entry.key}: $message');
}
```

## Known limitations and assumptions

These follow from the shape of the underlying API, not from missing client
functionality:

- **No streaming support.** The System One API does not offer a streaming
response mode, so neither does this client.
- **No batch endpoint.** There is no bulk/batch request API — submit
multiple named questions in a single `systemOne` call instead.
- **Single-shot only.** The API has no server-side session or conversation
state. If you need multi-turn context, include the prior conversation
inside `state` yourself.
- **Per-request timeout only.** The `timeout` passed to `JevClient` applies
to each individual HTTP attempt, not to the total wall-clock time across
all retries performed by the configured `RetryPolicy`.
- **`JevApiException.body` is untyped.** The exact JSON schema of an error
response body is undocumented by TypeSafe AI, so `body` is deliberately
left as `Object?` rather than a typed model — treat it as best-effort
diagnostic information, not a stable contract.

