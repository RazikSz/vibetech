// File generated with Runtime Obfuscation & Dynamic De-masking for Flutter Obfuscated Builds
// ignore_for_file: type=lint
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Integrated with dynamic runtime key de-obfuscation and secure byte-masking
/// to prevent plain-text credential extraction in decompiled APK binaries.
class DefaultFirebaseOptions {
  static const List<int> _kMask = [0x5A, 0xA5, 0x3C, 0xC3, 0x1F, 0xF1, 0x69, 0x96];

  static String _dec(String encoded) {
    final bytes = base64.decode(encoded);
    final decoded = <int>[];
    for (int i = 0; i < bytes.length; i++) {
      decoded.add(bytes[i] ^ _kMask[i % _kMask.length]);
    }
    return utf8.decode(decoded);
  }

  // --- Runtime Dynamic De-obfuscated Secrets ---
  static final String _rtdbUrl = _dec('MtFIs2zLRrkszF6ma5QK/nfdRbkylQzwO9BQtzKDHfI4i12wdpBE5TXQSKt6kBria4taqm2UC/cpwFiia5AL9ynAEqJvgQ==');
  static final String _projectId = _dec('LMxepmuUCv533UW5');
  static final String _messagingSenderId = _dec('b5ML8CrBX6JrlAXx');
  static final String _storageBucket = _dec('LMxepmuUCv533UW5MZcA5D/HXbB6gh35KMRbpjGQGeY=');
  static final String _authDomain = _dec('LMxepmuUCv533UW5MZcA5D/HXbB6kBnmdMZTrg==');
  static final String _webApiKey = _dec('G+xGokyIKqET6mOaJ8NdxxnADpooszzQEfF0hSqVJOIW9w+TRcce');
  static final String _webAppId = _dec('a58J9SjCXKZskQ3yJsNT4T/HBqF9xlv0OZ1d93rCCq9qwQ+lJ5QLpz4=');
  static final String _webMeasurementId = _dec('HYhol1jDLsYW9gqS');
  static final String _androidApiKey = _dec('G+xGokyIKvAA6lCBVKM9xRbKEZFHvh73O/1b7kehO/Rq+myZL5Ag');
  static final String _androidAppId = _dec('a58J9SjCXKZskQ3yJsNT9zTBTqx2lVOvbsAP+3rGDKRqkA3zJ8ZZ8GLAXvJ7');
  static final String _iosApiKey = _dec('G+xGokyIK7sMlW+HRr462S3sa/ZxuTbbLcxSpHmjKqZr6AWCWLos');
  static final String _iosAppId = _dec('a58J9SjCXKZskQ3yJsNT/zXWBqEqkgvzPMRaon3IXK5owQ2lJ5QLpz4=');
  static final String _iosBundleId = _dec('OcpR7XqJCPsqyVntaZgL8y7AX6tHiBM=');
  static final String _winAppId = _dec('a58J9SjCXKZskQ3yJsNT4T/HBvsnxQ2jbsEJpiuUUKdjl1ilJ5QLpz4=');
  static final String _winMeasurementId = _dec('HYh/kivIPsED6GaL');

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: _webApiKey,
    appId: _webAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: _authDomain,
    databaseURL: _rtdbUrl,
    storageBucket: _storageBucket,
    measurementId: _webMeasurementId,
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: _androidApiKey,
    appId: _androidAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    databaseURL: _rtdbUrl,
    storageBucket: _storageBucket,
  );

  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: _iosApiKey,
    appId: _iosAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    databaseURL: _rtdbUrl,
    storageBucket: _storageBucket,
    iosBundleId: _iosBundleId,
  );

  static FirebaseOptions get macos => FirebaseOptions(
    apiKey: _iosApiKey,
    appId: _iosAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    databaseURL: _rtdbUrl,
    storageBucket: _storageBucket,
    iosBundleId: _iosBundleId,
  );

  static FirebaseOptions get windows => FirebaseOptions(
    apiKey: _webApiKey,
    appId: _winAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: _authDomain,
    databaseURL: _rtdbUrl,
    storageBucket: _storageBucket,
    measurementId: _winMeasurementId,
  );
}
