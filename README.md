# Secure Player

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey)](https://flutter.dev)
[![Built with Flutter](https://img.shields.io/badge/built_with-Flutter-02569B?logo=flutter)](https://flutter.dev)

A 100% offline private media vault for Android and iOS. Videos, photos, audio and PDFs are encrypted on-device with AES-256 and unlocked only by your PIN or biometric. No cloud, no analytics, no account.

> **Open source so you can verify what we say.** Every encryption claim, every "no telemetry" statement and every threat-model promise in [SECURITY.md](SECURITY.md) is auditable in the source. If you find a flaw, please follow [SECURITY.md](SECURITY.md) to report it.

## Features

- AES-256-CTR encryption for every file at rest, with a master key in OS Keystore
- PBKDF2-HMAC-SHA256 PIN hashing (4 or 6 digit PINs supported)
- Biometric (fingerprint / face) unlock via OS BiometricPrompt
- Auto-lock on background, configurable inactivity timeout, escalating wrong-PIN cooldown
- Break-in detection — silently photographs anyone who enters the wrong PIN, encrypted into the vault
- iOS App Switcher snapshot blocked via native UIView; Android `FLAG_SECURE` screenshot blocking
- Files held in app-private sandbox with random UUID filenames
- Cloud backup explicitly disabled (`allowBackup=false`, file-protection class on iOS)
- HTTPS-only enforced at OS level for the optional URL download feature
- No analytics, no trackers, no third-party SDKs
- Built-in video, audio, image and PDF players

## Security model

Read [SECURITY.md](SECURITY.md) for the full threat model — what we defend against, what we explicitly do not, and the cryptographic primitives used.

## Getting started

```bash
# Prerequisites: Flutter 3.10+, Xcode 15+ (iOS), Android Studio (Android)

flutter pub get
flutter run -d iphone           # iOS simulator
flutter run -d emulator-5554    # Android emulator
```

## Building for Play Store

See [`play-store/README.md`](play-store/README.md) for the full submission walkthrough. TL;DR:

```bash
# One-time keystore setup
cd android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
# (then create android/key.properties — see play-store/01-keystore-setup.md)

# Build release AAB
cd ..
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

## Tech stack

| Concern | Library |
|---|---|
| Video | `video_player`, `chewie` |
| Audio | `just_audio` |
| PDF | `syncfusion_flutter_pdfviewer` |
| Photos | native `Image` widget |
| File picker | `file_picker` |
| URL download | `dio` (HTTPS only) |
| Encryption | `pointycastle` (AES-256-CTR), `crypto` (PBKDF2-HMAC-SHA256) |
| Local storage | `path_provider`, `sqflite`, `shared_preferences` |
| Secrets in OS keystore | `flutter_secure_storage` |
| Auth | `local_auth` (BiometricPrompt) |
| Camera (break-in detection only) | `camera`, `permission_handler` |
| Capture blocking | `flutter_screenshot_blocker` (Android), native UIView overlay (iOS) |

## Project layout

```
lib/
├── main.dart                          app entry
├── splash_screen/                     animated launch screen
├── onboarding_screen/                 first-launch flow (PIN length, set PIN, biometric)
├── app_lock_screen/                   PIN entry + biometric prompt
├── main_screen.dart                   bottom-nav scaffold + lifecycle observer + privacy overlay
├── views/screens/home_screen/         media library
├── upload_screen/                     import from device or HTTPS URL
├── download_screen/                   export history
├── security_settings/                 PIN change, biometric toggle, session, intrusion log, about
├── video_player_screen/               chewie wrapper
├── audio_hear_screen/                 just_audio UI
├── pdf_reader_screen/                 syncfusion viewer
├── services/                          media import service
├── models/                            data models
└── utils/
    ├── pin_crypto.dart                PBKDF2 PIN hashing
    ├── vault_crypto.dart              AES-256-CTR file encryption
    ├── intrusion_service.dart         break-in selfie capture
    ├── session_manager.dart           inactivity timeout, failed-attempt cooldown
    └── liquid_colors.dart             theme colors
```

## Repository structure

```
.
├── android/                   Android project + signing config
├── ios/                       iOS project + privacy manifest
├── lib/                       Dart source
├── assets/                    icon + splash source images
├── play-store/                Play Console listing pack
├── SECURITY.md                threat model + vulnerability disclosure policy
├── CONTRIBUTING.md            how to contribute
├── LICENSE                    Apache 2.0
└── pubspec.yaml
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security reports go to `hello@farhatullah.com`, not GitHub issues — see [SECURITY.md](SECURITY.md) for details.

## License

Apache License 2.0 — see [LICENSE](LICENSE).

## Contact

Built by Farhatullah — `hello@farhatullah.com`
