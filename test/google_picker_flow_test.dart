import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibetech_xyz/services/firebase_user_service.dart';
import 'package:vibetech_xyz/services/google_auth_service.dart';

void main() {
  group('Google Account Selection & Sync Flow Tests', () {
    test('GoogleAccountUser initializes and filters dummy accounts properly', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final dummyUser = GoogleAccountUser(
        name: 'Budi Santoso Google',
        email: 'budi.santoso.$ts@gmail.com',
        avatarUrl: 'https://lh3.googleusercontent.com/a/custom-avatar',
        avatarColor: const Color(0xFF4285F4),
      );

      final uid = 'goog_$ts';
      final username = dummyUser.email.split('@').first.replaceAll('.', '_');

      final userData = {
        'uid': uid,
        'nama': dummyUser.name,
        'username': username,
        'email': dummyUser.email,
        'phone': '081234567890',
        'password': 'google_oauth_pass',
        'pin': '123456',
        'referralCode': '',
        'role': 'user',
        'createdAt': DateTime.now().toIso8601String(),
        'saldo': 0.0,
        'avatarUrl': dummyUser.avatarUrl,
        'authProvider': 'Google',
      };

      // Memastikan user budi santoso terdeteksi sebagai dummy dan diabaikan dari cloud
      final isDummy = FirebaseUserService.isDummyUser(userData);
      expect(isDummy, isTrue);

      final docId = await FirebaseUserService.instance.saveUserToFirebase(userData);
      expect(docId, uid);

      // Verifikasi bahwa user dummy tidak pernah tersimpan di Firebase
      final cloudUser = await FirebaseUserService.instance.getUserFromFirebase(uid);
      expect(cloudUser, isNull);
    });
  });
}
