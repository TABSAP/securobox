# Private Locker architecture

## Goal

Add an optional, PIN-gated area inside SecuroBox where users can import photos
and videos that do not appear in the regular vault library. The feature is
separate from the app's existing startup lock and does not alter its PIN.

## User flow

1. A Settings entry opens Private Locker.
2. First use explains that locker content is encrypted and isolated from the
   regular library, then asks the user to enable the feature and create a
   dedicated six-digit PIN.
3. Every new visit requires the locker PIN. Leaving the screen or backgrounding
   the app locks it again.
4. Once unlocked, the user can select multiple photos/videos from the system
   picker, browse locker-only items, and open them in the existing secure media
   viewers.
5. Imports never remove or modify the original Gallery/file-picker source.

## Components and boundaries

- `PrivateLockerService`: owns feature state, PIN hashing/verification, locker
  metadata, and encrypted imports. Real and decoy modes use separate
  preferences, PIN credentials, and encrypted subfolders.
- `PrivateLockerScreen`: setup, unlock, media grid, picker, progress, and
  recoverable empty/error states. It never reads the regular media library.
- Settings navigation: exposes the feature as optional and clearly describes
  its extra PIN.
- Existing `VaultCrypto`: encrypts files under the private-locker subfolder;
  existing `openVaultMedia` handles decryption and type-specific viewing.

## Persistence

- Metadata uses separate SharedPreferences keys for real and decoy lockers.
- PIN verifier and random salt use separate Flutter Secure Storage keys for
  each mode. Derive the verifier with the project's PBKDF2 helper; never store
  the raw PIN.
- Media bytes are encrypted in `vault/private_locker/` or
  `vault_decoy/private_locker/`. The normal library key is never written by
  locker imports.
- A failed metadata commit deletes any newly encrypted files from that import
  attempt. Existing locker records remain intact.
- Import source files are treated as read-only; the user must explicitly manage
  originals in Gallery themselves.

## Locking and privacy behavior

- Locker PIN verification is independent of app-lock preferences and the main
  app PIN. The locker screen starts locked on every route entry and locks when
  the app is backgrounded. Five incorrect PIN attempts trigger a short delay.
- The screen removes its decrypted item list from view when locking. Previews
  are generated through the existing thumbnail cache and the locker removes
  its own decrypted preview cache when it locks.
- Decoy mode gets a separate locker metadata namespace, PIN verifier, and file
  subfolder so its locker contents do not cross into the real vault.
- The PIN is an additional in-app access gate. File encryption continues to
  use SecuroBox's existing master key; this is not a separately keyed
  cryptographic vault and does not protect against a compromised/rooted device
  or code running inside an already-unlocked app process.

## Error handling and recovery

- Explain unavailable picker access and allow retry.
- Show per-import totals and report skipped/unreadable files without leaking
  paths or deleting source files.
- On partial failure, keep valid metadata and encrypted files; on metadata
  commit failure, roll back only files created by that transaction.
- Wrong PIN leaves the locker locked. Secure storage or persistence errors are
  shown as recoverable failures; do not silently disable the PIN gate.
- Disabling/removing the feature is not part of the first version because it
  could destroy user data. Locker files remain intact if the user stops using
  the feature.

## First implementation scope

- Optional feature entry in Settings.
- Dedicated six-digit PIN setup and verification.
- Real/decoy isolation, private encrypted import subfolder, separate media
  list, photo/video grid, and secure viewer routing.
- Lock on leaving/backgrounding; retryable picker and persistence errors.
- No cloud sync, Private Locker PIN recovery, album-level rules, or permanent
  delete action in the initial implementation. Private Locker media is not part
  of the regular vault backup. App PIN recovery questions cannot recover a
  forgotten Private Locker PIN.
