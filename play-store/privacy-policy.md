# Privacy Policy — SecuroBox

**Effective date:** 2026-05-29
**Contact:** info@tabsap.com

## Summary

SecuroBox is a 100% offline application. We do not collect, store, transmit, sell, or share any personal data. This privacy policy exists because the Google Play Store requires every app to publish one, even when the app collects nothing.

## What data the app handles

The app handles only the files **you choose to import** into the in-app vault, plus any photos or videos you capture with the in-app Secure Capture camera. These files are AES-256-CTR encrypted on your device and stored in the app's private sandbox. They never leave your device.

When you import a photo or video, by default the app **moves** it into the vault: the file is encrypted into the vault and its original is removed from your device gallery (your device shows a confirmation before anything is removed). You can turn this off in Settings to keep the gallery copy, and you can move a file back out at any time with **Save to gallery**.

Specifically, the app does **not**:

- send any data to any server we control or to any third party
- include any analytics SDK (no Google Analytics, Firebase, Mixpanel, etc.)
- include any advertising SDK (no AdMob, no IronSource, etc.)
- include any crash reporting SDK that uploads off-device
- create any account or require any sign-up
- request your location, contacts, calendar, SMS, or phone data

## Permissions we request and why

| Permission | Purpose |
|---|---|
| Internet | Optional — only used when you paste a URL and ask the app to download a file into the vault (HTTPS only) |
| Photos / Videos / Audio (READ_MEDIA_*) | To let you import existing media from your device into the vault |
| Storage (Android 12 and below) | Same as above, on older Android versions |
| Biometric / Fingerprint | To let you unlock the vault with fingerprint or face, processed locally by the OS — never seen by the app |
| Camera | Used by the in-app Secure Capture camera (take photos or record videos directly into your vault) and, only if you turn them on, Break-in Detection (a silent photo on a wrong PIN) and Face Unlock. Every capture is encrypted into the vault and never transmitted |
| Microphone | Optional — only to record sound while you film a video with the in-app Secure Capture camera. The audio stays inside the encrypted vault and is never transmitted |

The app does **not** request: location, contacts, SMS, phone, calendar, or notifications.

## Where your data lives

- **Files you import**: AES-256-CTR encrypted with a per-device master key, stored in the app's private application documents directory. Filenames on disk are random UUIDs.
- **PIN**: hashed with PBKDF2-HMAC-SHA256 (100,000 iterations) using a 16-byte random salt. The hash and salt are stored in OS-backed secure storage — Android EncryptedSharedPreferences (Keystore-backed) and iOS Keychain. The PIN itself is never persisted.
- **Master encryption key**: 32 random bytes generated on first launch, stored in the same OS-backed secure storage.
- **Break-in photos**: encrypted with the same master key and stored under `vault/intrusions/` in the app's private sandbox.
- **Face Unlock data**: a numeric geometric face signature (not a photo), stored in OS-backed secure storage. No face image is kept.
- **Recovery email (optional)**: if you turn on PIN recovery, the email address you enter and a salted PBKDF2 hash of your one-time recovery code are stored in OS-backed secure storage. They are never transmitted — there is no server.

When you uninstall the app, the operating system automatically deletes all of its private storage, removing every file you imported and every key.

## Face Unlock and ML Kit

If you choose to enable Face Unlock, SecuroBox uses Google ML Kit's on-device face detection model to compute a numeric geometric face signature (not a photo). That signature is stored in OS-backed secure storage (Android Keystore-backed storage / iOS Keychain). No image or any other face data is ever transmitted off your device.

## Children's privacy

The app is not directed at children under 13. It does not knowingly collect any data from anyone, regardless of age.

## Changes to this policy

If we ever change this policy, we will update the "Effective date" at the top and post the new version at the same public URL.

## Contact

Questions or concerns? Email **info@tabsap.com**.
