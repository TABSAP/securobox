# Data Safety Form — exact answers

Path in Play Console: **Policy → App content → Data safety**

This form is mandatory and Google checks it against your code. Answer accurately or you'll get a policy strike.

---

## Q1. Does your app collect or share any of the required user data types?

**Answer: No**

> The app does not transmit user data anywhere. All files stay on the device in private app storage. There is no analytics SDK, no AdMob, no crash reporter, no backend server.

## Q2. Is all of the user data collected by your app encrypted in transit?

**Answer: N/A — no data is transmitted.**

(If the form forces a Yes/No, choose **Yes**, since the only network operation — downloading a file from a URL the user pastes — uses HTTPS by default via the `dio` library.)

## Q3. Do you provide a way for users to request that their data be deleted?

**Answer: Yes — users can delete files from within the app, and uninstalling the app removes everything.**

## Q4. Has your data collection and security practices been independently validated?

**Answer: No** (independent review is for big enterprises; selecting Yes without proof is a policy violation).

---

## Privacy Policy URL

You **must** provide a public URL. The text is in `play-store/privacy-policy.md`. Suggested hosts (free):

- **GitHub Pages**: create a repo `secure-player-privacy`, add `index.md` with the policy, enable Pages → URL is `https://farhatullah777.github.io/secure-player-privacy/`
- **Notion**: paste into a public Notion page, share publicly → URL is the share link
- **Google Sites**: free, no setup
- Your own domain if you have one

Test the URL in an incognito window before pasting it into Play Console.

---

## Permissions justifications (used elsewhere in the form)

| Permission | Why declared | Justification |
|---|---|---|
| `INTERNET` | Optional URL download feature | "User-initiated download of media files via direct URL" |
| `READ_MEDIA_VIDEO` / `_IMAGES` / `_AUDIO` | File picker import | "Required so users can choose existing media on their device to import into the private vault" |
| `READ_EXTERNAL_STORAGE` (max SDK 32) | File picker on Android 12 and below | "Legacy storage permission, only declared for Android 12 and earlier — replaced by READ_MEDIA_* on 13+" |
| `WRITE_EXTERNAL_STORAGE` (max SDK 29) | File picker on Android 9 and below | "Legacy storage permission, only declared for Android 9 and earlier" |
| `USE_BIOMETRIC` / `USE_FINGERPRINT` | App lock | "User-initiated biometric authentication for the in-app vault — never sent off-device" |
