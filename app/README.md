# MoneyNote — Flutter app

The mobile app of [MoneyNote](../README.md) — a local-first Vietnamese expense tracker with AI natural-language entry.

```bash
flutter pub get
flutter run        # Android emulator/device
flutter test       # unit + widget tests (Drift in-memory; no network)
flutter analyze
```

Layering (one-way, top-down): `features/` (UI) → `state/providers.dart` (Riverpod) → `domain/` (pure logic) → `data/` (Drift DB, repository, AI client). UI never touches the database or network directly — everything goes through `AppRepository`.

On Windows, tests need `sqlite3.dll` in this folder (see `test/drift_setup.dart`).

AI entry needs the [Go server](../server) running; configure its URL in **Cài đặt → Máy chủ AI** (defaults to the Android-emulator host `10.0.2.2:8080`).
