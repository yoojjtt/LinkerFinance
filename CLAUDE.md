# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter application targeting iOS, Android, macOS, Linux, Windows, and Web. Currently at the default counter app template stage. Dart SDK ^3.9.2.

## Common Commands

- **Run app:** `flutter run` (add `-d chrome` for web, `-d macos` for macOS, etc.)
- **Run tests:** `flutter test`
- **Run single test:** `flutter test test/widget_test.dart`
- **Analyze code:** `flutter analyze`
- **Get dependencies:** `flutter pub get`
- **Format code:** `dart format .`

## Architecture

- `lib/main.dart` — App entry point, single-file app with `MyApp` (MaterialApp) and `MyHomePage` (StatefulWidget)
- `test/` — Widget tests using `flutter_test`
- Linting via `package:flutter_lints/flutter.yaml` (configured in `analysis_options.yaml`)
