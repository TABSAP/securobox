# SecuroBox feature expansion architecture

## Goals

Add safer recovery, controlled guest access, stronger organization, and
convenient imports without weakening the default offline vault model. Cloud
storage is a user-selected destination for a portable backup file; SecuroBox
does not need an account or a server.

## Component boundaries

- `VaultBackupService` owns portable backup and restore. A backup is a versioned
  container protected by a user passphrase with PBKDF2 and authenticated
  encryption. It carries vault records and media payloads. Restore validates the
  entire container before writing vault records, stages payloads temporarily,
  and re-encrypts each imported file with the current device's vault key.
- The Safety Center reports missing payloads and Gallery permission state.
  Actual exports remain delegated to the media service so its
  verify-before-delete behavior stays the single restore path.
- `CategoryLockService` stores category gates separately for the real and decoy
  vaults. It requires the app's configured PIN or biometric authentication on
  each entry. Guest viewing is a separate read-only route limited to selected
  photos and videos and gated on exit.
- `AutoImportScreen` stores album rules and scans them while open. Candidates
  enter a review queue; importing and removing Gallery originals are explicit
  choices.
- Library sorting stays in the library presentation layer. Timeline grouping
  and local-only map browsing can be added without changing vault storage.

## Safety invariants

1. Never remove a Gallery original or vault payload until the destination has
   been written and verified.
2. Never apply a backup until its password, authentication tag, manifest, and
   every payload have been validated.
3. Backups and auto-import are opt-in. Ordinary vault use remains offline.
4. Guest mode exposes only selected items, disables destructive actions, and
   re-authenticates on exit.
5. Decoy-vault records and key material remain namespaced and cannot be mixed
   into a real-vault backup or restore.

## Delivery status

- [x] Safety Center and passphrase-protected backup/restore foundation. The
  current implementation bounds media payloads to 128 MB to limit memory use.
- [x] Guest viewing and category entry authentication.
- [x] Foreground album rules with a review queue and explicit original-file
  choice; scans run only while the rules screen is open.
- [x] Sort by newest imported, oldest imported, or name.
- [ ] Timeline grouping by original capture date and local map browsing. The
  current media model does not retain capture dates or GPS coordinates, so this
  needs metadata extraction and a versioned metadata migration first.
- [ ] Manual Android and iOS document-picker, permission, and lifecycle checks
  before release.

## Platform notes

Drive and iCloud Drive are reached through the OS document picker. This avoids
embedding cloud credentials and works with providers exposed by the device.
Automatic imports run while SecuroBox is open because iOS and Android background
execution is constrained; the UI must not promise continuous monitoring.
Location metadata must remain local, and users must be able to disable location
display without deleting original metadata.
