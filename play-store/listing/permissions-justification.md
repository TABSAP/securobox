# Permission justifications

This is the same content as the table in `data-safety-form.md`, kept separate so you can copy/paste into the Play Console permission declarations dialog when prompted.

```
INTERNET — User-initiated download of media files via direct URL.

READ_MEDIA_VIDEO / READ_MEDIA_IMAGES / READ_MEDIA_AUDIO — Required so the user can pick existing media on their device to import into the private vault. Used only at the moment of import via the system file picker.

READ_EXTERNAL_STORAGE (maxSdkVersion 32) — Legacy storage permission only declared for Android 12 and earlier. Replaced by READ_MEDIA_* on Android 13+.

WRITE_EXTERNAL_STORAGE (maxSdkVersion 29) — Legacy storage permission only declared for Android 9 and earlier.

USE_BIOMETRIC / USE_FINGERPRINT — Used solely to unlock the app when the user opts into biometric app lock. Authentication is performed locally by the OS BiometricPrompt API; the biometric data never leaves the device and is never seen by the app.

CAMERA — Used for the in-app Secure Capture camera (the user takes photos or records videos that are encrypted directly into the private vault) and, only when the user enables them, optional break-in detection (a silent photo on a wrong PIN) and Face Unlock. All captures stay on-device inside the encrypted vault and are never transmitted.

RECORD_AUDIO — Records audio only while the user films a video with the in-app Secure Capture camera. The audio is stored inside the encrypted vault and is never transmitted. (This permission is merged into the app by the CameraX library.)
```
