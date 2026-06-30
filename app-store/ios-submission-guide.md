# SecuroBox — iOS App Store Submission Guide

Everything is code-ready. Follow this once your **Apple Developer Program** membership is active (you'll get an activation email — up to 2 business days).

---

## 0. Prerequisites (status)

| Item | Status |
|---|---|
| Mac with Xcode 26 | ✅ installed |
| Apple Developer Program ($99/yr) | ⏳ paid Jun 30 — waiting for activation email |
| Bundle ID `app.securobox.vault` | ✅ set in project |
| App icon (1024, no alpha) | ✅ present |
| Privacy manifest | ✅ present |
| Encryption export compliance | ✅ declared in Info.plist |
| Clean release build | ✅ verified (`flutter build ios --release --no-codesign`) |

---

## 1. Create the App Store Connect record

1. Go to **https://appstoreconnect.apple.com** → **My Apps** → **➕ → New App**.
2. Fill in:
   - **Platform:** iOS
   - **Name:** `SecuroBox - Private Vault` (see metadata.txt — plain "SecuroBox" may be taken)
   - **Primary language:** English (U.S.)
   - **Bundle ID:** `app.securobox.vault` (pick it from the dropdown; if it's not there, create it first at **developer.apple.com → Certificates, IDs & Profiles → Identifiers → ➕**)
   - **SKU:** `securobox-ios-001` (any unique string, not shown to users)
   - **User access:** Full
3. Click **Create**.

---

## 2. Sign the app in Xcode

1. Open the workspace (NOT the project):
   ```
   open ios/Runner.xcworkspace
   ```
2. Select the **Runner** target → **Signing & Capabilities** tab.
3. ✅ **Automatically manage signing.**
4. **Team:** select your TABSAP team (appears once the account is active).
5. Confirm **Bundle Identifier** = `app.securobox.vault`.
6. Xcode will create the signing certificate + provisioning profile automatically.

---

## 3. Build & upload

**Option A — Xcode (recommended for first time):**
1. In Xcode, top bar device selector → **Any iOS Device (arm64)**.
2. First sync the build number/version:
   ```
   flutter build ipa --release
   ```
   (or let Xcode use the values; version = 1.0.0, build = 5 from pubspec)
3. Menu **Product → Archive**. Wait for it to finish (~2–4 min).
4. The **Organizer** opens → select the archive → **Distribute App → App Store Connect → Upload** → keep defaults → **Upload**.

**Option B — CLI + Transporter:**
1. ```
   flutter build ipa --release
   ```
   Output: `build/ios/ipa/*.ipa`
2. Open the **Transporter** app (free, Mac App Store), sign in, drag the `.ipa` in, **Deliver**.

> After upload, the build takes ~5–15 min to finish "Processing" in App Store Connect before you can select it.

---

## 4. Fill in the version page (App Store Connect → your app → iOS 1.0)

Copy from **`app-store/listing/metadata.txt`**:
- **Promotional text, Description, Keywords, Support URL, Marketing URL**
- **Subtitle** (in App Information)
- **Build:** select the build you uploaded (the `+5` one)
- **Screenshots** (see §5)
- **App Review Information:** your contact name/email/phone. **Sign-in required? No** (the app has no account). Add a note (see §6).
- **Version release:** "Automatically release after approval" (or manual).

**App Information (left sidebar):**
- **Category:** Utilities (secondary: Photo & Video)
- **Privacy Policy URL:** (in metadata.txt)
- **Age rating:** open the questionnaire → answer **None** to everything → **4+**

**App Privacy (left sidebar):**
- Click **Get Started** → choose **"Data Not Collected"** → Publish. (No SDKs, no analytics, nothing leaves the device.)

---

## 5. Screenshots (the one asset you still need to produce)

The app is **iPhone-only** (`TARGETED_DEVICE_FAMILY = 1`), so you only need ONE set — no iPad screenshots required:

| Device | Size needed | How many |
|---|---|---|
| iPhone 6.9" (15/16 Pro Max) | 1290 × 2796 | 3–10 |

**Easiest way to get them:** run the app in the iOS Simulator and press **⌘S** (File → Save Screen) on each screen.
```
open -a Simulator          # then in Xcode pick an iPhone 16 Pro Max
flutter run                # navigate to each screen, ⌘S to capture
```
Reuse the same SCREENS you used for Google Play — lock screen, empty vault, library, security score, settings — **but do NOT include the Smart/Quick-import or Disguise screens** to stay consistent with the honest listing.

> Only the **6.9"** size is strictly required; App Store Connect scales it for smaller iPhones. To add iPad later, set `TARGETED_DEVICE_FAMILY = "1,2"` and supply 13" iPad screenshots.

---

## 6. App Review note (paste into "App Review Information → Notes")

```
SecuroBox is a 100% offline encrypted media vault. No account or login is
required — all features are available immediately.

To test:
1. On first launch, complete onboarding and set a 6-digit PIN.
2. The vault opens. Use the "+" button to import photos/videos from the
   library, or the camera button for in-app Secure Capture.
3. Settings → Security contains optional features (Face Unlock, Decoy PIN,
   Break-in Detection, Offline Integrity Lock, PIN Recovery).

All data is AES-256 encrypted on-device using standard algorithms and never
transmitted. The app has no servers, analytics, or third-party SDKs.
```

---

## 7. Submit

Click **Add for Review → Submit**. First-app review is typically 24–48h.

---

## Notes / gotchas

- **iPhone-only vs iPad:** decide before screenshots (see §5).
- **"Hide photos / vault" category:** Apple allows these; the honest description + the review note above pre-empt questions.
- **Break-in photo & camera:** disclosed in the camera usage string and review note — fine.
- **No screenshot-blocking or disguise claims** in the iOS listing (those are Android-only) — already excluded from metadata.txt.
- **Build number:** each new upload must have a higher build number than the last. Currently `5`. Next upload → bump `version:` in pubspec.yaml.
