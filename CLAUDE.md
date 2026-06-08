# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

SecuroBox — a 100% offline, on-device encrypted media vault (Android/iOS, Flutter). Videos, photos, audio, PDFs and documents are AES-256 encrypted at rest and unlocked only by PIN or biometric. No cloud, no analytics, no accounts. See `README.md` and `SECURITY.md` for the product and threat model.

**Note:** the Dart package is named `video_player_app` (legacy), so all internal imports are `package:video_player_app/...` even though the product is SecuroBox. The Android applicationId is `app.securobox.vault`.

## Commands

```bash
flutter pub get                        # install deps
flutter run                            # run on the connected device/emulator
flutter analyze                        # static analysis — the only gate (run before every PR; CONTRIBUTING requires it)
flutter build appbundle --release      # Play Store AAB → build/app/outputs/bundle/release/
flutter build apk --debug              # full debug build (use to verify native/Kotlin/manifest changes compile)

# Code-gen (only when their config/assets change):
dart run flutter_launcher_icons        # app icons
dart run flutter_native_splash:create  # splash screen
```

There is **no test suite** (`test/` has no Dart tests). `flutter analyze` is the verification step — keep it clean.

### Critical rebuild rule
Native changes — anything under `android/` (Kotlin, `AndroidManifest.xml`), `ios/`, or **adding a plugin dependency** (e.g. `sensors_plus`, `flutter_native_splash`) — are **not** picked up by hot reload or hot restart. You must fully stop and reinstall (`flutter run` fresh / `flutter install`). A stale build is the usual cause of "I already fixed this but it still crashes." Pure-Dart changes work on hot restart.

## Architecture

### Startup & lock flow
`main()` (`lib/main.dart`) initializes singletons in order (ThemeController, SessionManager, NetworkGuard, then fire-and-forget `DisguiseService.load()`, `prewarmPbkdf2()`, and a `local_auth` channel warm-up) → `app.dart` → `SplashScreen`. The splash decides the next screen from SharedPreferences: `OnboardingScreen` (not onboarded), `AppLockScreen` (any of `appLock`/`biometric`/`biometric_face` enabled), else `MainScreen`.

`MainScreen` (`lib/main_screen.dart`) is the app shell: an `IndexedStack` of tabs (Home/Library, Intrusions, Settings) plus a `WidgetsBindingObserver` that re-locks. On resume/inactivity it pushes `AppLockScreen(isOverlay: true)` on top. `SessionManager` (`lib/utils/session_manager.dart`) owns all lock state: auto-lock timing, escalating wrong-PIN/biometric cooldowns (persisted in secure storage so clearing app data can't reset them), the `shouldLock`/`shakeToLock` notifiers, and **trusted interactions**.

### Trusted interactions (auto-lock suppression)
Opening the OS file picker, an OS biometric prompt, or the gallery-delete confirmation backgrounds the app, which would otherwise trigger auto-lock-on-resume and strand the operation behind the lock screen. Any code that triggers such an OS round-trip wraps it in `SessionManager.instance.beginTrustedInteraction()` / `endTrustedInteraction()` (a depth counter). `MainScreen._onResumed` and the inactivity timer skip locking while `inTrustedInteraction` is true. When adding a flow that leaves the app to the OS, wrap it.

### Cryptography — always off the UI isolate
- **Files**: `VaultCrypto` (`lib/utils/vault_crypto.dart`) does AES-256-CTR streaming encryption. The master key lives in OS-backed secure storage; file processing (`_processFile`) runs in a `compute()` isolate. Import → `importEncrypted(File)` returns a `.enc` path with a random UUID name; view → `decryptToTemp(path)`; locking wipes the temp cache.
- **PIN**: `PinCrypto` and `DecoyService` hash PINs with PBKDF2-HMAC-SHA256 (100k iterations) via `lib/utils/pbkdf2.dart`, which runs on a **persistent worker isolate** (kept warm by `prewarmPbkdf2()`) so repeated PIN entry has no per-call isolate-spawn lag and never blocks the keypad.

This is a hard rule: never run KDF/AES on the main isolate — it freezes the UI. Use the existing `compute`/worker patterns.

### Vault namespacing (real vs decoy)
`VaultContext` (`lib/utils/vault_context.dart`) namespaces every SharedPreferences key (`libraryKey`, `customCategoriesKey`, `downloadHistoryKey`, …) and `VaultCrypto`/`SecureNotesService`/`ActivityLog` storage by whether the vault is in **decoy** mode. The decoy vault is a separate, cryptographically isolated duress vault opened by a fake PIN (`DecoyService`). Anything that stores per-vault data must key off `VaultContext` so the decoy stays separate.

### Storage model
The media library is **not JSON** — it's a `List<String>` in SharedPreferences where each `VideoItem` (`lib/models/app_models.dart`) is a pipe-delimited record (`id|title|path|type|isLocked|category|isDeleted|deletedDate|encrypted|isHidden|isFavorite`). `fromStorageString` parses defensively by field count, so **new fields must be appended at the end** with a backward-compatible default. Small secrets (PIN hashes, secure notes) use `flutter_secure_storage` instead.

### Biometric sheet
`BiometricAuthSheet.show` (`lib/widgets/biometric_auth_sheet.dart`) is a full-screen page whose result is delivered through a `Completer`; it removes its **own route by reference** (pop when current, `removeRoute` otherwise) rather than `Navigator.pop()` — this avoids popping a transient overlay (e.g. an `another_flushbar` toast) that happens to be on top, which crashed the navigator. Preserve this pattern when touching it.

### Native disguise (Android)
The home-screen icon/name can be disguised (Calculator, Notes, etc.). `MainActivity.kt` toggles `<activity>` components via `setComponentEnabledSetting` over the `secure_player/disguise` MethodChannel. Each disguise is a real `<activity>` in `AndroidManifest.xml` backed by a thin `MainActivity` subclass (`CalculatorActivity`, …) so it can carry its own icon/label/theme; component class names in Kotlin must match the manifest exactly. Switching disguise requires a full reinstall to take effect.

### UI conventions
- All colors come from `LiquidColors` (`lib/utils/liquid_colors.dart`) — theme-aware tokens driven by `ThemeController` (light/dark). Don't hardcode `Color(...)`; use the tokens.
- Layout uses `lib/utils/responsive.dart` helpers (`context.contentInset(...)`, `context.responsive(phone:, tablet:)`).
- User-facing messages use `FlushBarHelper`.

### Other security subsystems
- `IntrusionService` — silently captures a break-in photo (via `camera`) on the 3rd wrong PIN, encrypted into the vault.
- `NetworkGuard` — "Offline Integrity Lock": seals the vault whenever the device has a network path (`connectivity_plus`); even a correct credential won't decrypt while online.
- Shake-to-lock — `ShakeDetector` (`lib/utils/shake_detector.dart`, `sensors_plus`) → `SessionManager.requestLock()` when the `shakeToLock` setting is on.
- Screenshot/recents blocking via `flutter_screenshot_blocker` (Android `FLAG_SECURE`) + native iOS snapshot blanking.
