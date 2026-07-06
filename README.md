# SecuroBox

**A 100% offline, on-device encrypted media vault for Android & iOS.**

SecuroBox keeps your private videos, photos, audio, PDFs, and documents locked
behind AES‑256 encryption and unlocked only by your PIN or biometrics.
Everything stays on your device — **no cloud, no accounts, no analytics, no
servers**. If the app can't reach a plaintext copy, neither can anyone else.

- **Platforms:** Android & iOS (Flutter)
- **App ID:** `app.securobox.vault`
- **Version:** `1.0.0+6`
- **Dart package name:** `video_player_app` (legacy — all internal imports are
  `package:video_player_app/...` even though the product is SecuroBox)

---

## Table of contents

- [What it does](#what-it-does)
- [Features](#features)
- [Security architecture](#security-architecture)
- [Technology stack](#technology-stack)
- [Project structure](#project-structure)
- [Getting started](#getting-started)
- [Building for release](#building-for-release)
- [Configuration](#configuration)
- [How it works](#how-it-works)
- [Screens](#screens)
- [Development notes](#development-notes)
- [Privacy](#privacy)
- [License](#license)

---

## What it does

SecuroBox is a private vault. You import media from your gallery, files, or the
built‑in secure camera; each file is encrypted at rest with AES‑256 and stored
inside the app's private storage. To view anything you must unlock the app with
a PIN or biometrics. Locking the app (manually, on inactivity, on backgrounding,
or when a network connection appears) wipes every decrypted temporary file.

Because it is fully offline, there is nothing to sign up for and nothing leaves
the device.

---

## Features

### Vault & media
- **Encrypted import** of videos, photos/images, audio, PDFs, and documents.
- **Built‑in players/viewers:** video (with speed & fullscreen), audio, PDF, and
  image — each decrypting on demand behind a fast in‑app loading state.
- **Secure camera** — capture photos/videos straight into the encrypted vault.
- **Categories** (Videos, Photos, Audio, Documents, Others) plus custom
  categories, with instant search and filtering.
- **Favorites**, rename, change category, and a **Recycle Bin** with a 30‑day
  auto‑purge for deleted items.
- **Save to gallery / share** individual items (decrypted on export), with an
  **export history** log.
- **Real‑time UI** — every change (import, delete, favorite, rename, restore)
  reflects instantly across the app; there is no manual refresh.
- **Original filenames** preserved on import.

### Security & privacy
- **AES‑256 encryption at rest** with Encrypt‑then‑MAC (HMAC‑SHA256) integrity.
- **PIN lock** (4‑ or 6‑digit) hashed with PBKDF2‑HMAC‑SHA256 (100,000
  iterations) — never stored in plaintext.
- **Biometric unlock** — fingerprint and Face ID / face unlock via the OS, plus
  optional **in‑app face recognition**.
- **Decoy vault** — a separate, cryptographically isolated duress vault opened by
  a fake PIN, so you can hand over a "safe" set of files under coercion.
- **Break‑in detection** — silently captures a front‑camera photo (encrypted into
  the vault) after repeated wrong PIN attempts.
- **Offline Integrity Lock** — seals the vault whenever the device has a network
  path; even a correct credential won't decrypt while online.
- **Auto‑lock** on inactivity, backgrounding, and app resume, with escalating
  cooldowns after wrong attempts.
- **Screenshot & screen‑recording blocking** (Android) and an app‑switcher
  privacy shield.
- **App disguise** (Android) — swap the home‑screen icon/name to look like a
  Calculator, Notes, etc.
- **PIN recovery** via a self‑issued, one‑time recovery code emailed to yourself
  (only a hash of the code is stored on device).

### Experience
- Material 3, light/dark theme, and a shared design system for consistent
  spacing, cards, section headers, empty states, and skeleton loaders.
- Crypto runs off the UI isolate, so the interface never freezes during
  encryption or decryption.

---

## Security architecture

> SecuroBox is designed so that a plaintext copy of your data exists only
> transiently, in memory or a temp file, and only while the app is unlocked and
> in the foreground.

### File encryption
- **Algorithm:** AES‑256 in CTR mode, streamed in 64 KB chunks.
- **Format:** `[4‑byte magic][IV(16)][ciphertext][HMAC‑SHA256 tag(32)]`
  (Encrypt‑then‑MAC). Decryption verifies the tag before yielding data; legacy
  files without the magic header are still readable.
- **Master key:** a 256‑bit key generated with a secure RNG and stored in
  OS‑backed secure storage (Android Keystore / iOS Keychain). It is cached in
  memory only while unlocked.
- **Isolation:** all file encryption/decryption runs in a background isolate
  (`compute`) so the UI thread is never blocked.
- **Temp cache:** viewing decrypts to a temporary file that is wiped on lock,
  auto‑lock, or backgrounding.

### PIN & authentication
- PINs are hashed with **PBKDF2‑HMAC‑SHA256, 100,000 iterations** and a random
  salt, on a persistent worker isolate (kept warm so the keypad never lags).
- Hashes are compared in constant time and stored in `flutter_secure_storage`.
- Failed‑attempt counters and cooldowns are persisted in secure storage so
  clearing app data cannot reset them.

### Vault namespacing (real vs decoy)
Every per‑vault key (library, custom categories, download history, crypto keys,
temp dirs) is namespaced by a `VaultContext` that tracks whether the app is in
**real** or **decoy** mode, keeping the duress vault fully isolated.

### Secrets handling
Keys, PIN hashes, recovery hashes, and cooldown state live only in
`flutter_secure_storage` (Keystore/Keychain) — never in plaintext, never in
logs.

---

## Technology stack

| Area | Libraries |
|---|---|
| Framework | Flutter (Dart SDK ≥ 3.10), Material 3 |
| Cryptography | `pointycastle`, `crypto` (AES‑CTR, HMAC‑SHA256, PBKDF2) |
| Secure storage | `flutter_secure_storage` |
| Authentication | `local_auth`, `google_mlkit_face_detection` |
| Media playback | `video_player` + `chewie`, `just_audio` + `audio_session`, `syncfusion_flutter_pdfviewer` |
| Import & files | `file_picker`, `photo_manager`, `camera`, `share_plus`, `path_provider`, `path`, `uuid` |
| Device & privacy | `connectivity_plus`, `permission_handler`, `flutter_screenshot_blocker` |
| UI & misc | `another_flushbar`, `intl`, `url_launcher`, `in_app_review`, `package_info_plus`, `flutter_email_sender` |
| Build tooling | `flutter_launcher_icons`, `flutter_native_splash`, `flutter_lints`, `build_runner` |

---

## Project structure

```
lib/
├── main.dart                     # Bootstraps singletons, then app.dart
├── app.dart                      # MaterialApp, theme (light/dark), routing
├── main_screen.dart              # App shell: Library / Logs / Settings tabs + re-lock
├── models/
│   └── app_models.dart           # VideoItem (pipe-delimited storage record)
├── services/
│   └── media_service.dart        # Library CRUD + real-time revision notifier
├── utils/                        # Core logic & singletons
│   ├── vault_crypto.dart         # AES-256 + Encrypt-then-MAC (isolate)
│   ├── pbkdf2.dart               # PBKDF2 on a persistent worker isolate
│   ├── pin_crypto.dart           # PIN hashing/verification
│   ├── vault_context.dart        # Real vs decoy namespacing
│   ├── decoy_service.dart        # Duress vault
│   ├── session_manager.dart      # Auto-lock, cooldowns, trusted interactions
│   ├── network_guard.dart        # Offline Integrity Lock
│   ├── intrusion_service.dart    # Break-in photo capture
│   ├── face_recognition_service.dart
│   ├── disguise_service.dart     # Android app-icon disguise
│   ├── screen_security.dart      # Screenshot/recording blocking (Android)
│   ├── recovery_service.dart     # PIN recovery codes
│   ├── theme_controller.dart     # Light/dark theme
│   ├── liquid_colors.dart        # Theme-aware color tokens
│   ├── media_importer.dart / media_helper.dart / title_helper.dart / import_settings.dart
│   └── responsive.dart, app_rating.dart, ...
├── widgets/                      # Shared/design-system widgets
│   ├── app_spacing.dart          # Spacing (4/8/16/24/32) & radius tokens
│   ├── app_card.dart             # Rounded, theme-aware card
│   ├── app_section_header.dart   # Consistent section header
│   ├── app_empty_state.dart      # Shared empty state
│   ├── app_skeleton.dart         # Shimmer loader
│   ├── liquid_bottom_nav.dart    # Material 3 bottom navigation
│   ├── biometric_auth_sheet.dart, pin_unlock_dialog.dart, app_brand_icon.dart
├── splash_screen/ , onboarding_screen/ , app_lock_screen/
├── views/screens/
│   ├── home_screen/              # Library (grid/list, search, filters, import)
│   ├── deleted_video_screen/     # Recycle Bin
│   ├── secure_camera/            # In-vault capture
│   └── secure_picker/            # Gallery picker
├── security_settings/            # Security center, decoy/recovery/face setup, about, support, privacy, feedback
├── history_screen/               # Export history
├── video_player_screen/ , audio_hear_screen/ , pdf_reader_screen/

android/  ios/                    # Native projects (disguise activities, file protection, FLAG_SECURE)
assets/   icon/ splash/ disguise/ # App icon, splash, disguise icons
```

There is currently **no automated test suite**; `flutter analyze` is the
verification gate.

---

## Getting started

### Prerequisites
- **Flutter** (stable channel, Dart SDK ≥ 3.10) + platform toolchains
- **Android:** Android Studio + SDK, an emulator or a device with USB debugging
- **iOS:** macOS with Xcode (or a cloud macOS build service)

### Setup
```bash
git clone <repo-url>
cd securobox
flutter pub get
flutter run          # on a connected device or emulator
```

### Everyday commands
```bash
flutter pub get                      # install dependencies
flutter run                          # run on device/emulator
flutter analyze                      # static analysis — the verification gate
flutter build apk --debug            # verify native/Kotlin/manifest changes compile
```

---

## Building for release

### Android
```bash
flutter build appbundle --release    # Play Store AAB
# -> build/app/outputs/bundle/release/
flutter build apk --release          # standalone APK
```
Release builds require a signing config (see [Configuration](#configuration)).

### iOS
```bash
flutter build ipa --release          # requires macOS + Xcode signing
```

> Versioning: `version: 1.0.0+N` in `pubspec.yaml`. `N` is the Android version
> code **and** the iOS build number. Every store upload must use a higher `N`
> than the previous uploaded build.

---

## Configuration

- **Android signing** — provide `android/key.properties` and a keystore
  (`*.jks`). These contain secrets and are **not** committed to the repository.
- **App icon** — configured under `flutter_launcher_icons` in `pubspec.yaml`
  (source: `assets/icon/icon.png`). Regenerate with:
  ```bash
  dart run flutter_launcher_icons
  ```
- **Splash screen** — configured under `flutter_native_splash` in `pubspec.yaml`
  (source: `assets/splash/logo.png`). Regenerate with:
  ```bash
  dart run flutter_native_splash:create
  ```
- **Permissions** — camera (secure camera, break‑in capture), photos/storage
  (import/export), and biometrics are requested at the point of use. Android‑only
  features (screenshot blocking, disguise) are guarded so they never surface on
  iOS.

---

## How it works

### Startup & lock flow
`main()` initializes core singletons (theme, session manager, network guard, and
warm‑ups for the disguise service, PBKDF2 isolate, and biometrics), then shows a
splash screen. The splash decides the next screen from stored preferences:
- **Onboarding** if the vault hasn't been set up,
- **App Lock** if any lock (PIN / biometric / face) is enabled,
- otherwise the **main app**.

The main shell is an `IndexedStack` of three tabs (Library, Logs, Settings). A
lifecycle observer re‑locks the app on resume/inactivity by pushing the lock
screen as an overlay. Opening the OS file picker, biometric prompt, or gallery
export is wrapped in a "trusted interaction" so those legitimate round‑trips
don't trip the auto‑lock.

### Real‑time updates
The media library is a single source of truth exposed through a change notifier.
Every mutation bumps it, and the library screen re‑renders instantly — there is
no pull‑to‑refresh anywhere in the app.

### Storage model
The library is stored as a `List<String>` in `SharedPreferences`, where each
item is a pipe‑delimited `VideoItem` record
(`id|title|path|type|isLocked|category|isDeleted|deletedDate|encrypted|isHidden|isFavorite`).
Parsing is defensive by field count, so new fields are appended with
backward‑compatible defaults. Small secrets use `flutter_secure_storage` instead.

### Design system
Shared tokens and widgets (`AppSpace`, `AppRadius`, `AppCard`,
`AppSectionHeader`, `AppEmptyState`, `AppSkeleton`) plus theme‑aware color tokens
(`LiquidColors`) keep spacing, radii, and states consistent across every screen.

---

## Screens

- **Onboarding** — welcome, choose PIN length, set PIN, optional recovery email,
  optional biometrics.
- **App Lock** — PIN keypad + biometric unlock, with cooldowns and decoy support.
- **Library** — encrypted media grid/list with search, category filters,
  favorites, import (gallery/files/secure camera), and per‑item actions.
- **Logs (Break‑in Log)** — encrypted intruder snapshots captured on wrong PINs.
- **Settings** — appearance (theme), links to Security, History, About, and Help.
- **Security** — app lock, biometric & face unlock, decoy vault, break‑in
  detection, Offline Integrity Lock, PIN change/length, recovery email, import
  options, and (Android) screenshot blocking & disguise.
- **History** — record of files exported out of the vault.
- **Recycle Bin** — restore or permanently delete trashed items (30‑day auto‑purge).
- **Viewers** — video, audio, PDF, and image, each decrypting on demand.
- **About / Help & Support / Privacy Policy / Send Feedback** — informational.

---

## Development notes

- **`flutter analyze` must be clean** before committing — it is the only gate
  (there is no test suite).
- **Native changes** (anything under `android/`/`ios/`, or adding a plugin) are
  **not** picked up by hot reload/restart — fully stop and reinstall the app.
- **Never run cryptography on the main isolate.** File AES and PIN PBKDF2 use the
  existing `compute`/worker‑isolate patterns; running them on the UI isolate
  freezes the interface.
- **Guard platform‑specific features** (e.g. screenshot blocking, disguise) with
  `Platform.isAndroid` so they never appear as non‑working options on iOS.
- **New storage fields** go at the **end** of the pipe‑delimited record with a
  backward‑compatible default.

---

## Privacy

SecuroBox is privacy‑first by architecture: it is fully offline, requests only
the permissions it needs at the point of use, stores secrets only in encrypted
OS‑backed storage, and wipes decrypted temporary files on lock. No data is
collected, transmitted, or shared.

---

## License

See [`LICENSE`](LICENSE) for the full text.
