# SecuroBox

SecuroBox is a private media vault for Android and iOS, built with Flutter.
It stores imported media in the app's private storage and encrypts files at rest.

## Features

- Import and organize photos, videos, audio, and documents.
- Protect the vault with a PIN and device biometrics where supported.
- View supported media and documents in the app.
- Export optional passphrase-protected backups.

Supported formats and device capabilities vary by platform.

## Development

Install a Flutter SDK compatible with the Dart constraint in `pubspec.yaml`, then run:

```sh
flutter pub get
flutter run
```

Run static analysis and tests with:

```sh
flutter analyze
flutter test
```
