# SecuroBox ads setup

SecuroBox shows a Google App Open ad at launch/resume (with a 30-minute
frequency cap) and one adaptive banner on the Settings root screen. Ads are
requested as non-personalized, and Google UMP consent is checked before
requests.

## Test configuration

Debug builds use Google's official sample app and ad unit IDs. They display test
ads and do not generate revenue.

## Production configuration

Create an AdMob app and banner ad unit for each platform, then:

- Put the Android production app ID in the local `android/key.properties`
  entry `admobAppId`. Release builds reject the Google sample app ID.
- Set `ADMOB_IOS_APP_ID` in the build environment for iOS releases; the Release
  xcconfig passes it to the native Ads SDK. Debug keeps Google's test app ID.
- Supply production banner and App Open unit IDs at build time:

Debug builds use Google's sample ad units when Dart defines are omitted. Release
builds disable ads when production unit IDs are missing; they do not fall back
to test inventory.

```sh
flutter build appbundle \
  --dart-define=ADMOB_ANDROID_BANNER_ID=ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy \
  --dart-define=ADMOB_ANDROID_APP_OPEN_ID=ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz

ADMOB_IOS_APP_ID=ca-app-pub-xxxxxxxxxxxxxxxx~zzzzzzzzzz flutter build ipa \
  --dart-define=ADMOB_IOS_BANNER_ID=ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy \
  --dart-define=ADMOB_IOS_APP_OPEN_ID=ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz
```

Configure consent messages and privacy options in the AdMob Privacy & messaging
console. The app checks UMP consent before requesting a banner and exposes the
privacy-options entry point in Settings whenever UMP requires it.
