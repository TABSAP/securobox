# PIN Recovery Questions Architecture

## Goal

Replace the generated Recovery Key with a local security-question recovery flow
for the app PIN. Users configure recovery during onboarding and can change it in
Security settings after authenticating. The Forgot PIN screen verifies the
saved answers before allowing the existing PIN-reset flow.

## Components and data flow

1. `RecoveryQuestionsService` owns validation, canonicalization, salted answer
   verifiers, secure-storage persistence, attempt throttling, and removal of
   legacy Recovery Key material.
2. Onboarding sets the PIN, then requires the user to select and answer three
   distinct questions before finishing setup. Settings opens the same editor
   only after PIN/biometric re-authentication.
3. Forgot PIN loads only the question prompts. It verifies all three answers
   locally, then enters the existing PIN reset flow. It never reveals whether a
   particular answer was correct.
4. Successful reset returns to PIN setup while leaving the data encryption key
   and encrypted media intact.

## Storage and security

- Store question identifiers, independent random 16-byte salts, and
  PBKDF2-HMAC-SHA256 answer verifiers in platform secure storage. Never store
  clear-text answers or the app PIN in preferences, logs, analytics, or UI
  state beyond the form lifetime.
- Normalize answers consistently (trim, collapse whitespace, lowercase) and
  require meaningful answers. Answers must be unique after normalization.
- Verify all answers as one recovery attempt. Compare verifiers in constant
  time and do not indicate which answer failed.
- Persist failed-attempt count and lockout deadline in secure storage. Five
  failures impose a cooldown; further failures use an increasing delay. PIN
  reset operations are serialized and re-check mounted state before navigation.
- Save verifier data transactionally: preserve old values until all new values
  are written; on failure restore the previous set. A partially written setup
  must never count as configured.
- Clear legacy Recovery Key verifier values after the new recovery setup is
  successfully saved. Do not migrate or expose the old generated key.
- Clear answer controllers and temporary answer state when the screen closes
  or the operation completes. Dispose controllers and cancel transient UI work.

## User experience and failure handling

- Onboarding explains that questions are a fallback and answers should be
  memorable but hard for others to guess. The user confirms setup before
  continuing.
- Forgot PIN presents the saved prompts with answer fields, validation,
  progress state, a neutral mismatch error, and a visible lockout countdown.
- Missing or malformed secure-storage records produce a safe recovery-unavailable
  state with a route back to the app's existing secure reset/wipe options;
  they never silently bypass verification.
- Storage, hashing, and reset failures show actionable retry messaging without
  exposing exception text or secrets.
- Security settings allows replacing questions only after authentication and
  warns that the previous answers stop working after save.

## Threat and recovery limits

Knowledge-based questions have lower entropy than a randomly generated key.
Throttling protects online attempts, but does not make predictable answers
strong against an attacker who can extract secure-storage data and brute-force
it offline. The UI must say this plainly and advise unique answers that are not
publicly discoverable. Recovery remains device-local; it does not restore data
after device loss, app-data deletion, or secure-storage loss.

## Validation

- Unit tests cover normalization, answer validation, salted persistence,
  constant-time verification behavior, lockouts, legacy-key clearing, and
  transactional failure handling.
- Widget tests cover onboarding setup, Forgot PIN success/failure/lockout, and
  disposal without state updates after unmount.
- Run the complete Flutter test suite and analyzer after integration.
