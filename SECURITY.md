# Security Policy

SecuroBox is a privacy-first offline media vault. We take vulnerability reports seriously.

## Reporting a vulnerability

**Please email security reports to:** `info@tabsap.com` (PGP key on request)

Do **not** open public GitHub issues for security problems.

We aim to respond within **72 hours** and to ship a fix within **14 days** of confirmation for critical issues.

## What qualifies

In scope:

- Bypasses of the PIN / biometric lock
- Recovery of vault contents without authentication on a non-rooted, non-jailbroken device
- Recovery of the PIN hash from disk
- Cleartext leakage (network, logs, disk) of vault content or user secrets
- Cryptographic mistakes in PIN hashing or file encryption
- Privilege escalation or arbitrary file access
- Data exfiltration via Android backup or iOS file sharing despite the explicit opt-out

Out of scope:

- Attacks requiring a rooted Android device or jailbroken iOS device (we treat these as already-compromised)
- Physical access attacks (e.g. unlocked phone)
- Brute-forcing a 4-digit PIN past the in-app cooldown (the cooldown caps you at ~10 guesses per hour; a determined attacker with the device can still do it)
- Memory dump attacks against a running process on a privileged device
- Social engineering and phishing
- App Store / Play Store review process issues

## Threat model — what we promise

| Threat | Defense |
|---|---|
| Casual access — someone picks up your unlocked phone | Auto-lock on background, configurable inactivity timeout, PIN + biometric |
| Brute-force PIN from the lock screen | Escalating cooldown (3→30s, 6→1m, 9→5m, 12→15m), persistent across app kill |
| File access via ADB / Files / iTunes | Files stored only in private app sandbox; iTunes/Finder file sharing disabled on iOS; sandbox-only on Android |
| Cloud backup leaking data | `allowBackup=false` + `dataExtractionRules` exclude all domains on Android; iOS automatic backup excluded for vault contents via file protection class |
| Network MITM | HTTPS-only enforced at OS level (`usesCleartextTraffic=false` + network security config on Android, ATS default on iOS) |
| Reading PIN from disk on rooted device | PIN never stored as plaintext. PBKDF2-HMAC-SHA256 (100,000 iterations) with 16-byte random salt; hash + salt stored in `flutter_secure_storage` (Android EncryptedSharedPreferences, iOS Keychain accessibility=`firstUnlockThisDevice`) |
| Reading vault files from disk on rooted device | Each file is AES-256-CTR encrypted with a per-device master key stored in OS-backed keystore. Filenames on disk are random UUIDs; original filenames are stored in app metadata and would also need decryption to be meaningful |
| App Switcher / multitasking snapshot leakage | Native UIView privacy shield on iOS attached during `applicationWillResignActive`; Flutter overlay on inactive/paused/hidden lifecycle states; `FLAG_SECURE` (via `flutter_screenshot_blocker`) on Android |
| Timing attack on PIN compare | Constant-time XOR-OR comparison of hash bytes |
| Remote exfiltration while the device is online | **Offline Integrity Lock** (opt-in, off by default). Continuously monitors the device's network interfaces; the instant any Wi-Fi / mobile / ethernet / VPN path is detected, the in-memory encryption session is revoked, the decrypted temp cache is wiped, and the vault locks. While enabled, no credential opens the vault until the device is fully offline (Airplane Mode). All local — no server, no reachability probe |

## Threat model — what we do NOT promise

- We do not protect against an adversary with **persistent root / jailbreak access** — they can read process memory, install hooks, and bypass any in-app crypto. iOS file-protection class helps only until first unlock after boot.
- We do not protect against **OS-level keylogger malware**.
- We do not protect against **shoulder-surfing** beyond enabling biometric.
- We do not have **forgot-PIN recovery**. By design. Lose your PIN → lose your vault. There is no email reset, no security questions, no master key escrow.
- We are **not** a chat / messaging app — there are no end-to-end transport guarantees beyond HTTPS for the optional URL download feature.
- The **Offline Integrity Lock** narrows the window in which decrypted content is reachable, but it is *not* a substitute for the root/jailbreak caveat above. It keys off the OS-reported network interface state (`connectivity_plus`), not true internet reachability, and it does not regenerate the at-rest AES master key — re-authentication re-derives a fresh *in-memory* session from the existing key (rotating the at-rest key would orphan every already-encrypted file).

## Cryptographic primitives

- **PIN hashing:** PBKDF2-HMAC-SHA256, 100k iterations, 16-byte random salt, 32-byte output.
- **File encryption:** AES-256 in CTR mode with a 16-byte random IV per file. IV is stored as the first 16 bytes of the ciphertext file.
- **Master key:** 32 bytes from `Random.secure()`, stored in `flutter_secure_storage` (hardware-backed where available).
- **Comparison:** constant-time XOR-OR on raw bytes.

If you find a flaw in any of the above, please report it via the email above.

## Disclosure policy

We follow coordinated disclosure. After a fix ships and a reasonable window (14–30 days) for users to update, we publish a brief advisory in the repo.
