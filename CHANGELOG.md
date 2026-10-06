# Changelog

## [0.3.0](https://github.com/andyhorn/system_one_dart/compare/v0.2.0...v0.3.0) (2026-10-06)


### ⚠ BREAKING CHANGES

* set SYSTEM_ONE_API_KEY and SYSTEM_ONE_BASE_URL instead of TYPESAFE_API_KEY and TYPESAFE_BASE_URL.

### Features

* add --json output mode to the jev CLI ([#8](https://github.com/andyhorn/system_one_dart/issues/8)) ([a71a4d4](https://github.com/andyhorn/system_one_dart/commit/a71a4d4838288abf41bb95d41b11f0a1f34f3a64)), closes [#4](https://github.com/andyhorn/system_one_dart/issues/4)
* make TYPESAFE_API_KEY optional, honor TYPESAFE_BASE_URL ([#10](https://github.com/andyhorn/system_one_dart/issues/10)) ([f1defbd](https://github.com/andyhorn/system_one_dart/commit/f1defbd79aa21265a5aa9f27f6fb19db803adc4e)), closes [#7](https://github.com/andyhorn/system_one_dart/issues/7)
* rename package to system_one ([#11](https://github.com/andyhorn/system_one_dart/issues/11)) ([9c720bb](https://github.com/andyhorn/system_one_dart/commit/9c720bbd08d6af911ea2361a96a19d256c2b38f2))

## [0.2.0](https://github.com/andyhorn/jev/compare/v0.1.0...v0.2.0) (2026-10-06)


### Features

* add jev CLI and Release Please release workflow ([#3](https://github.com/andyhorn/jev/issues/3)) ([cc6cc9a](https://github.com/andyhorn/jev/commit/cc6cc9a6c72187bb797403fa3807917b27b19c1a))

## 0.1.0

- Initial version: `JevClient` with `systemOne`/`systemOneRaw`, `Question`/`Answer` models for Noul/Choice/Score primitives, retry policy with exponential backoff, and a typed exception hierarchy.
