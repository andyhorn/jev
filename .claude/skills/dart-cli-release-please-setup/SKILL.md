---
name: dart-cli-release-please-setup
description: Use when automating Dart CLI releases as compiled binaries.
category: deployment
---

Release Please automates version bumps and GitHub releases for this Dart CLI package, compiling and distributing binaries for Linux x64, macOS arm64, and Windows x64.

## Version management

Store the CLI version in a committed Dart file (e.g., `lib/src/version.dart: const String jevVersion = '0.1.0';`), not only in `pubspec.yaml`. Add it to Release Please's `extra-files` in `release-please-config.json` so compiled binaries report the correct `--version` and the Dart version constant stays in sync with `pubspec.yaml`.

## Configuration files

- **`pubspec.yaml`** — add `executables` section to declare CLI entry points: `executables: { jev: jev }` maps `bin/jev.dart` to the `jev` command.
- **`release-please-config.json`** — Release Please config with `extra-files` to bump `lib/src/version.dart`, `packages` list for monorepo support, and `release-type: dart` for Dart conventions.
- **`.release-please-manifest.json`** — Release Please tracking file listing released versions; check it into git.
- **`.github/workflows/pr-title.yaml`** — Lint PR titles to enforce Conventional Commits (`feat:`, `fix:`, `chore:` prefixes). Release Please reads commit history and requires this format to generate changelogs and bump versions.

## Compilation and release workflow

In `.github/workflows/release.yaml`, after Release Please opens its release PR and it's merged:

1. Compile the CLI with `dart compile exe bin/jev.dart -o jev-<platform>`.
2. Attach binaries to the GitHub Release with platform-specific names: `jev-linux-x64`, `jev-macos-arm64`, `jev-windows-x64.exe`.
3. Enable **Settings → Actions → General → "Allow GitHub Actions to create and approve pull requests"** so Release Please can open release PRs without manual approval.

## Commit conventions

- Use `feat:`, `fix:`, and `chore:` prefixes on all commits (squash-merge PRs with conventional titles).
- `feat:` bumps minor version; `fix:` bumps patch; `feat!:` or `BREAKING CHANGE:` bumps major.