# Privacy Policy — SecuroBox

**Effective date:** 2026-04-30
**Contact:** hello@farhatullah.com

## Summary

SecuroBox is a 100% offline application. We do not collect, store, transmit, sell, or share any personal data. This privacy policy exists because the Google Play Store requires every app to publish one, even when the app collects nothing.

## What data the app handles

The app handles only the files **you choose to import** into the in-app vault. These files are copied to the app's private storage on your device and never leave it.

Specifically, the app does **not**:

- send any data to any server we control or to any third party
- include any analytics SDK (no Google Analytics, Firebase, Mixpanel, etc.)
- include any advertising SDK (no AdMob, no IronSource, etc.)
- include any crash reporting SDK that uploads off-device
- create any account or require any sign-up
- request your location, contacts, calendar, or any non-media data

## Permissions we request and why

| Permission | Purpose |
|---|---|
| Internet | Optional — only used when you paste a URL and ask the app to download a file |
| Photos / Videos / Audio (READ_MEDIA_*) | To let the system file picker import media from your device |
| Read external storage (Android 12 and below only) | Same as above, on older Android versions |
| Biometric / Fingerprint | To let you unlock the app with face or fingerprint, processed locally by the OS |

The app does **not** request: camera, microphone, location, contacts, SMS, phone, calendar, or notifications.

## Where your data lives

Your imported files are stored in:

- Android: the app's private `Application Documents Directory`, which is sandboxed by Android and inaccessible to other apps
- The app PIN is stored in `SharedPreferences` and additionally backed up to the Android Keystore (hardware-backed on most devices)

When you uninstall the app, Android automatically deletes all of its private storage, removing every file you imported.

## Children's privacy

The app is not directed at children under 13. It does not knowingly collect any data from anyone, regardless of age.

## Changes to this policy

If we ever change this policy, we will update the "Effective date" at the top and post the new version at the same public URL.

## Contact

Questions or concerns? Email **hello@farhatullah.com**.
