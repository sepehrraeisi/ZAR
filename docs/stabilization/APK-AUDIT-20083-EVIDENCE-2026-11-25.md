# APK audit — installed Device QA 20083 (2026-11-25)

مرجع ROADMAP فاز ۱ «ممیزی APK واقعی گوشی»

## Device

- Model: Samsung `SM_N986U` (`R5CN70SG2BF`)
- Package: `com.zarplus.app`
- versionCode: **20083**
- versionName: `1.0.0`
- lastUpdateTime: `2026-11-24 19:42:22` (+03:30)
- codePath: `/data/app/~~…/com.zarplus.app-…`

## Artifact (local build used for install)

- Path: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- APK SHA-256: `117e117adc0ca86d394f9c428084e83a281d23b1ba08c86202692e6a84bdd337`
- Signer SHA-256: `d19ad1127403b0f97ca43b0db6a94d5e6a0a1fd06e94466485922c20a57a2667`
  (matches `RELEASE-SIGNING-EVIDENCE-2026-11-06.md`)
- Build: `--build-number=18083` (+2000 → versionCode 20083),
  `--dart-define=ZAR_SERVER_URL=https://app.titangold.ir`
- Master tip at audit: `163f6c5` (includes epoch/SSE/actor + drop-local-user)

## Prior evidence

- Build/install log: `DEVICE-QA-APK-20083-EVIDENCE-2026-11-24.md`
- Physical multi-device soak still open:
  `MULTI-DEVICE-PHYSICAL-SOAK-CHECKLIST.md`
