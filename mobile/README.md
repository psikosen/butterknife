# Butter Knife Flutter Application

This directory hosts the Butter Knife Flutter app. The project adopts a feature-first layout with shared core utilities.

## Structure

- `lib/`
  - `core/` — bindings, logging, error modeling, networking, persistence helpers.
  - `features/` — feature domains (`browser`, `extract`, `download`, `settings`).
  - `shared/` — cross-cutting models such as `MediaItem` and `ExtractionResult`.
- `test/` — unit tests covering serialization, URI normalization, and settings state.

## Getting Started

1. Install Flutter 3.22 or newer.
2. Run `flutter pub get` inside this directory.
3. Launch the application with `flutter run` or execute `flutter test` for unit coverage.

Logs conform to the structured schema defined at the repository root and emit the `[The 17 Commandments of Quality Code]` tag for parity with the Python toolkit.
