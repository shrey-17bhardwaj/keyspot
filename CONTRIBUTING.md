# Contributing to keyspot

Thanks for helping. This package has one job — highlights that never drift and
gestures that read clearly — so changes are judged mostly on whether they keep
that true on every platform.

## Getting set up

```sh
flutter pub get
flutter test
cd example && flutter run
```

## Before you open a pull request

```sh
dart format .
flutter analyze --fatal-warnings
flutter test --coverage
```

CI runs the same three, plus `dart pub publish --dry-run` and `pana`.

## Design rules

`SPEC.md` is the source of truth for the API. If your change alters public
behaviour, amend the relevant section in the same pull request and say so in the
description.

Two rules the package will not bend on:

- **No runtime dependencies.** `flutter` only. If a feature needs Lottie, Rive
  or SVG, it belongs behind `PointerStyle.builder` in the user's app, not here.
- **No guessed timing.** Futures complete when an `AnimationController`
  completes, never after a `Future.delayed` that approximates it. This is the
  single largest source of bugs in packages of this kind.

## Golden tests

Goldens are generated on the macOS runner, so regenerate them there:

```sh
flutter test --update-goldens test/golden
```

Do not commit goldens generated on Linux or Windows — font rendering differs and
CI will fail. If you do not have a Mac, open the pull request without touching
the goldens and say so; a maintainer will regenerate them.

## Commits

Conventional commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`). The
changelog is written by hand at release time — pub.dev renders it, so it is
prose for users, not a commit dump.
