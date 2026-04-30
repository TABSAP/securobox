# Secure Player

A 100% offline private media vault for Android (and iOS) — keep videos, audio, photos and PDFs safe behind a PIN and biometric lock.

Built with Flutter.

## Features

- Local-only vault — files never leave the device
- PIN + biometric (fingerprint / face) app lock
- Per-video lock for extra protection
- Screenshot / screen-capture blocking
- Built-in video, audio, image and PDF players
- Auto-categorized library + recycle bin
- No ads, no analytics, no account

## Getting started

```bash
flutter pub get
flutter run                # debug on connected device / sim
flutter run -d iphone      # iOS simulator
flutter run -d emulator-5554  # Android emulator
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
| URL download | `dio` |
| Local storage | `path_provider`, `sqflite`, `hive`, `shared_preferences` |
| Secrets | `flutter_secure_storage` (Android Keystore-backed) |
| Auth | `local_auth` (BiometricPrompt) |
| Capture blocking | `flutter_screenshot_blocker` |
| Notifications | `another_flushbar` |

## Project layout

```
lib/
├── main.dart                  app entry, screenshot blocker, downloader init
├── app.dart                   MaterialApp + theme
├── splash_screen/             animated launch screen
├── app_lock_screen/           PIN entry + biometric prompt
├── main_screen.dart           bottom-nav scaffold
├── views/screens/home_screen/ media library
├── upload_screen/             import from device or URL
├── download_screen/           in-app download manager
├── security_settings/         PIN change + biometric toggle
├── video_player_screen/       chewie wrapper
├── audio_hear_screen/         just_audio UI
├── pdf_reader_screen/         syncfusion viewer
├── data/theme/                colors + theme
├── database/                  sqflite helpers
├── services/                  media import service
├── models/                    data models
└── utils/                     helpers
```

## Repository structure

```
.
├── android/                   Android project + signing config
├── ios/                       iOS project + Info.plist usage strings
├── lib/                       Dart source
├── assets/                    icon + splash source images
├── play-store/                Play Console listing pack (descriptions, privacy policy, walkthroughs)
├── pubspec.yaml
└── README.md
```

## Contact

Built by Farhatullah — hello@farhatullah.com
