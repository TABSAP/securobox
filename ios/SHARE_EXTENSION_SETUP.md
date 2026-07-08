# iOS "Share to SecuroBox" — Xcode setup

The Flutter/Dart side, the Android Sharesheet, and all the extension **source
files** are already done. iOS needs a Share Extension **target**, which can only
be created in Xcode. Follow these steps once (~5–10 min), then build.

This project uses **CocoaPods** and `receive_sharing_intent` **1.8.1** (which
ships a podspec — no Swift Package Manager needed).

Files already in the repo:

- `ios/Share Extension/ShareViewController.swift`
- `ios/Share Extension/Info.plist`
- `ios/Share Extension/MainInterface.storyboard`
- `ios/Share Extension/Share Extension.entitlements`
- `ios/Runner/Runner.entitlements`
- `ios/Runner/Info.plist` (already has `AppGroupId` + the URL scheme)
- `ios/Podfile` (already has the nested `target 'Share Extension'` block)

App Group used everywhere: **`group.app.securobox.vault`**
Host bundle id: **`app.securobox.vault`**

---

## 1. Create the Share Extension target

1. Open **`ios/Runner.xcworkspace`** in Xcode (the workspace, not the project).
2. **File ▸ New ▸ Target… ▸ Share Extension.**
3. Product Name: **`Share Extension`** (exactly — it must match the folder,
   the Podfile target, and the storyboard). Language: **Swift**. If prompted to
   activate the scheme, click **Cancel**.
4. Set the extension's **iOS Deployment Target equal to Runner's** (15.5).

Xcode generates a `Share Extension/` group with its own `ShareViewController.swift`,
`Info.plist`, and `MainInterface.storyboard`.

## 2. Replace the generated files with the repo's

Delete the three generated files (Move to Trash), then **Add Files to "Runner"…**
into the **Share Extension** target only:
- `ios/Share Extension/ShareViewController.swift`
- `ios/Share Extension/Info.plist` → set as the target's Info.plist
  (Build Settings ▸ *Info.plist File* = `Share Extension/Info.plist`)
- `ios/Share Extension/MainInterface.storyboard`
- `ios/Share Extension/Share Extension.entitlements`

## 3. App Group capability (BOTH targets)

For **Runner** *and* **Share Extension**: target ▸ **Signing & Capabilities ▸
+ Capability ▸ App Groups**, then check/add **`group.app.securobox.vault`**.
- Runner ▸ Build Settings ▸ *Code Signing Entitlements* = `Runner/Runner.entitlements`.
- Share Extension ▸ *Code Signing Entitlements* = `Share Extension/Share Extension.entitlements`.

## 4. `CUSTOM_GROUP_ID` build setting (BOTH targets)

For **Runner** and **Share Extension**: Build Settings ▸ **+ ▸ Add User-Defined
Setting**, name **`CUSTOM_GROUP_ID`**, value **`group.app.securobox.vault`**.

## 5. Install pods for the extension

From the repo root:

```sh
cd ios && pod install
```

The Podfile already nests `target 'Share Extension' do inherit! :search_paths end`
inside `Runner`, so `receive_sharing_intent` (which provides `RSIShareViewController`)
becomes available to the extension. If Xcode still can't find the module, do a
clean build (⇧⌘K) and rebuild.

## 6. Build & test

```sh
flutter run            # or build for a device
```

Share a photo / PDF / zip / doc from another app ▸ choose **SecuroBox**. After
you unlock the vault, the **Import to SecuroBox** preview opens with the file(s).

---

### How it flows

`Share sheet → Share Extension (auto-redirects) → opens SecuroBox via the
ShareMedia-app.securobox.vault URL scheme → ShareIntake catches the files →
waits until the vault is unlocked → pushes ShareImportScreen`.

Shared files are written into the App Group container by the extension and read
by the app; nothing leaves the device.
