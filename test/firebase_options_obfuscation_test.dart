import 'package:flutter_test/flutter_test.dart';
import 'package:vibetech_xyz/firebase_options.dart';

void main() {
  group('DefaultFirebaseOptions Runtime Obfuscation & Security Tests', () {
    test('Android FirebaseOptions de-obfuscates with correct values', () {
      final opts = DefaultFirebaseOptions.android;
      expect(opts.apiKey, 'AIzaSyCfZOlBKRTSLo-RXOwaaXg-XPRb0_PZ0aI');
      expect(opts.appId, '1:567350641192:android:94e38e7e20510870f8eb1d');
      expect(opts.projectId, 'vibetech-xyz');
      expect(opts.messagingSenderId, '567350641192');
      expect(opts.databaseURL, 'https://vibetech-xyz-default-rtdb.asia-southeast1.firebasedatabase.app');
      expect(opts.storageBucket, 'vibetech-xyz.firebasestorage.app');
    });

    test('Web FirebaseOptions de-obfuscates with correct values', () {
      final opts = DefaultFirebaseOptions.web;
      expect(opts.apiKey, 'AIzaSyC7IO_Y824QCe2Y7BUFKTHF5dMtLR3PZ6w');
      expect(opts.appId, '1:567350641192:web:bb72bc8a4e3c90d3f8eb1d');
      expect(opts.projectId, 'vibetech-xyz');
      expect(opts.authDomain, 'vibetech-xyz.firebaseapp.com');
      expect(opts.measurementId, 'G-TTG2GPLS6Q');
    });

    test('Windows FirebaseOptions de-obfuscates with correct values', () {
      final opts = DefaultFirebaseOptions.windows;
      expect(opts.apiKey, 'AIzaSyC7IO_Y824QCe2Y7BUFKTHF5dMtLR3PZ6w');
      expect(opts.appId, '1:567350641192:web:884d54d5e4e9192df8eb1d');
      expect(opts.projectId, 'vibetech-xyz');
      expect(opts.measurementId, 'G-CQ49WWYMZH');
    });

    test('iOS and macOS FirebaseOptions de-obfuscates with correct values', () {
      final iosOpts = DefaultFirebaseOptions.ios;
      expect(iosOpts.apiKey, 'AIzaSyB-V0SDYOSOwIW5nH_MwingfRC01M9AGKE');
      expect(iosOpts.appId, '1:567350641192:ios:b5cbefafab9582d1f8eb1d');
      expect(iosOpts.iosBundleId, 'com.example.vibetechXyz');

      final macOpts = DefaultFirebaseOptions.macos;
      expect(macOpts.apiKey, 'AIzaSyB-V0SDYOSOwIW5nH_MwingfRC01M9AGKE');
      expect(macOpts.appId, '1:567350641192:ios:b5cbefafab9582d1f8eb1d');
    });
  });
}
