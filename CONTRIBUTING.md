# Contributing to Secure Player

Thank you for your interest in contributing.

## Reporting security issues

**Do NOT open a public GitHub issue for security vulnerabilities.** Email `hello@farhatullah.com` instead. See [SECURITY.md](SECURITY.md) for the full disclosure policy.

## Reporting bugs and feature requests

Open an issue on GitHub describing:

- **What you expected to happen**
- **What actually happened**
- **Device + Android/iOS version**
- **Steps to reproduce** (if it's a bug)
- **Screenshots** if relevant — but please redact any actual vault content

## Development setup

```bash
# Prerequisites: Flutter 3.10+, Xcode 15+ (for iOS), Android Studio (for Android)

git clone https://github.com/<your-fork>/secure-player-app.git
cd secure-player-app
flutter pub get
flutter run -d iphone           # iOS simulator
flutter run -d emulator-5554    # Android emulator
```

See [README.md](README.md) for more on the project structure.

## Code style

- Follow `flutter_lints` (already configured in `analysis_options.yaml`)
- Run `flutter analyze` and fix any new errors before opening a PR
- No `debugPrint` / `print` calls in committed code (logs leak in dev builds)
- Don't add comments that just restate the code; add a comment only when the *why* is non-obvious
- Match the existing style for naming and file layout

## Pull requests

- One feature or fix per PR
- Update relevant docs (`README.md`, `SECURITY.md`) if you change behavior visible to users
- If the PR touches cryptography (`lib/utils/pin_crypto.dart`, `lib/utils/vault_crypto.dart`) it will get extra scrutiny — please link to the rationale or RFC
- We may close PRs that add new third-party SDKs without strong justification — every dependency is an attack surface

## What kinds of contributions are most welcome

- Security hardening (especially platform-specific edges)
- Accessibility improvements (TalkBack / VoiceOver labels)
- Bug fixes with reproduction steps
- New language translations (drop a `.arb` file under `lib/l10n/`)
- Documentation improvements

## What we will probably decline

- New cloud-sync features that route data through someone else's server
- New analytics / telemetry / crash reporters
- New ad networks
- UI redesigns without prior discussion
- Adding language to the marketing copy that overstates the app's protections (we keep claims testable)

## Licensing

By submitting a contribution, you agree that your contribution is licensed under the [Apache License 2.0](LICENSE). If your employer owns rights to your work, you must have their permission to contribute under this license.

## Communication

- Bug reports / feature requests → GitHub issues
- Security reports → `hello@farhatullah.com`
- General questions → GitHub Discussions (when enabled) or the same email

Thanks for helping make Secure Player more secure for everyone.
