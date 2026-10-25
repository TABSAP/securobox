# Unified Device Biometric Unlock

## Goal

Let a user unlock SecuroBox with any eligible device biometric they have
enrolled, such as face recognition or fingerprint. If both are enrolled, one
system authentication request accepts either method; SecuroBox must not launch
two prompts or require both methods in sequence.

## Ownership and settings

- Android owns face/fingerprint enrollment, liveness checks, modality choice,
  and the authentication prompt. SecuroBox cannot choose a face-only or
  fingerprint-only Android prompt through the public biometric API.
- iOS owns Face ID / Touch ID enrollment and presents its native biometric
  prompt. SecuroBox does not capture or store a face template on either OS.
- **Device biometrics** and **Face Unlock** are app preferences. If either is
  enabled, the vault lock screen starts the same native biometric request.
  Enabling Face Unlock is confirmed through the OS prompt and persisted as
  `biometric_face`.
- A legacy `biometric_face` preference remains readable for upgrade
  compatibility and counts as biometric unlock being enabled.
- Android's Face Unlock toggle checks general OS biometric capability because
  Android may report biometric strength without identifying face specifically.
  It enables face recognition for app unlock where the device allows it; it
  cannot force a face-only prompt.

## Enable flow

1. User enables Device biometrics or Face Unlock in SecuroBox settings.
2. SecuroBox checks platform availability, then makes one native
   authentication request to confirm consent.
3. On success, it stores the corresponding preference and enables App Lock if
   needed. On cancellation or failure, the preference stays off; the user can
   retry or use the PIN.
4. Face enrollment remains managed from Android Settings. Returning to
   SecuroBox refreshes platform availability.

## Vault unlock flow

1. The vault lock screen reads both current and legacy biometric preferences.
2. If either is enabled and biometric cooldown is clear, it starts one
   `BiometricAuthSheet` flow after the screen is ready.
3. The sheet asks the operating system for biometric-only authentication and
   allows passive face confirmation where the system supports it. The OS
   accepts any eligible enrolled modality for this request.
4. Success opens the vault. Cancellation returns to the lock screen. Failure
   and lockout preserve the PIN path and existing biometric cooldown controls.
5. The lock screen and sheet expose one biometric action. Method-specific
   selections that would merely reopen the same system prompt are omitted.

## Security and fallback

- `biometricOnly` excludes device PIN/pattern from the biometric prompt; the
  app's vault PIN remains an explicit alternative.
- Android's passive-confirmation flag is only a system hint. OEM policy or
  biometric strength may still make face unavailable to third-party apps; in
  that case the OS can offer another eligible biometric or SecuroBox PIN.
- App never uses a camera-based face scan or stores face data.
- A single authentication in flight prevents duplicate or racing prompts.
