# Selene Re-Android

Android-only Kotlin native rebuild of Selene under `re-android/`.

Current status:
- Multi-module Gradle project bootstrapped
- App shell, navigation, startup/auth skeleton, and shared core modules added
- All first-pass feature modules exist with compileable placeholder routes

Verification commands:

```bash
./gradlew :app:testDebugUnitTest
./gradlew :core:common:testDebugUnitTest :core:network:testDebugUnitTest :feature:startup:testDebugUnitTest
./gradlew assembleDebug
```
