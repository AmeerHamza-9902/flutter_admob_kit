# AdMob Kit native example

Android and iOS host projects use official Google test AdMob app IDs. All ad unit IDs are selected through `AdMobConfig(testMode: true)`.

The home screen demonstrates both `bigNative` and `mediumNative(height: 130)`
alongside a banner and fullscreen controls. Scroll to inspect the two native
cards after the test ads load.

Run from this directory:

```sh
flutter pub get
flutter run -d emulator-5554
flutter build apk --debug
flutter build ios --simulator --debug
```

To test a required UMP form, configure a real app and published privacy message in AdMob, replace the test native app ID with that app ID, and supply registered UMP test-device parameters. The default Google test app ID does not prove your own privacy-message setup.

The native build minimum is Android API 24 and iOS 13; resolved SDK dependencies can require a higher deployment target. Use the build diagnostics to determine that target.
