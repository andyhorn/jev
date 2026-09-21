# Agent instructions

This package is an unofficial **Dart client** for TypeSafe AI's System One
("Jev") API — see `README.md` for usage.

If you have the [TypeSafe agent skill](https://github.com/typesafe-ai/skills)
installed (see `README.md`), note that it (and its docs.typesafe.ai links)
describe the HTTP API, Python SDK, and JavaScript SDK. When working in
*this* repo:

- Building a feature that calls the API from Dart/Flutter code → use
  `package:jev` (`JevClient`, `SystemOneRequest`, `NoulQuestion`,
  `ChoiceQuestion`, `ScoreQuestion`), not the HTTP/Python/JS examples from
  the skill. Match an exhaustive `switch` over the `Answer` sealed class,
  as shown in `README.md` and `example/jev_example.dart`.
- Modifying or extending this client itself (adding a primitive, a field,
  an error case, etc.) → the skill's API reference and confidence/primitive
  docs are still the source of truth for what the underlying service
  expects; the client's job is to model that faithfully.
