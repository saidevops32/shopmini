# ShopMini mobile (Flutter), UNTESTED starter

Only `lib/main.dart` is committed. Generate the platform folders on a machine with Flutter:
    cd mobile
    flutter create .          # keeps lib/main.dart? Check: it may overwrite it. Restore with `git checkout lib/main.dart`
    flutter pub add http
    flutter run --dart-define=API_BASE=http://10.0.2.2:8080
10.0.2.2 is the Android emulator's address for your computer. Real devices need a reachable HTTPS address.

Android blocks plain http by default (cleartext). For local testing against http only, add
`android:usesCleartextTraffic="true"` to the debug AndroidManifest. Production must use HTTPS.

Known gaps: the token is kept in memory only (use flutter_secure_storage), no registration validation
beyond the server's, no order history screen, no tests.
