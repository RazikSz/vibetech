import 'package:flutter_test/flutter_test.dart';
import 'package:vibetech_xyz/models/user_model.dart';
import 'package:vibetech_xyz/services/firebase_user_service.dart';

void main() {
  group('UserModel Serialization & Firebase Sync Tests', () {
    test('UserModel converts to and from SQLite map correctly', () {
      final user = UserModel(
        id: 1,
        uid: 'usr_test_001',
        nama: 'Test User VibeTech',
        username: 'testuser',
        email: 'test@vibetech.xyz',
        phone: '081234567890',
        password: 'securePassword123',
        pin: '654321',
        referralCode: 'VIBE2026',
        role: 'user',
        createdAt: '2026-08-26T12:00:00.000',
        saldo: 250000.0,
        location: 'Surabaya, Indonesia',
        avatarUrl: 'https://cdn.nekohime.site/file/5232n74c.jpeg',
        is2FA: 1,
        language: 'Indonesia',
      );

      final map = user.toMap();
      expect(map['uid'], 'usr_test_001');
      expect(map['nama'], 'Test User VibeTech');
      expect(map['username'], 'testuser');
      expect(map['email'], 'test@vibetech.xyz');
      expect(map['pin'], '654321');
      expect(map['saldo'], 250000.0);
      expect(map['role'], 'user');
      expect(map['is2FA'], 1);

      final reconstructed = UserModel.fromMap(map);
      expect(reconstructed.id, 1);
      expect(reconstructed.uid, 'usr_test_001');
      expect(reconstructed.nama, 'Test User VibeTech');
      expect(reconstructed.email, 'test@vibetech.xyz');
      expect(reconstructed.pin, '654321');
      expect(reconstructed.saldo, 250000.0);
      expect(reconstructed.isTwoFactorEnabled, true);
      expect(reconstructed.isUser, true);
      expect(reconstructed.isAdmin, false);
    });

    test('UserModel converts to and from Cloud Firestore & RTDB properly', () {
      final admin = UserModel(
        id: 2,
        uid: 'usr_admin_001',
        nama: 'Super Administrator',
        username: 'superadmin',
        email: 'admin@vibetech.xyz',
        phone: '081122334455',
        password: 'adminPassword2026',
        pin: '112233',
        referralCode: 'ADMINVIP',
        role: 'admin',
        createdAt: '2026-08-26T12:00:00.000',
        saldo: 10000000.0,
        location: 'Jakarta, Indonesia',
        avatarUrl: 'https://cdn.nekohime.site/file/admin.jpeg',
        is2FA: 1,
        language: 'Indonesia',
        updatedAt: '2026-08-26T12:30:00.000',
      );

      final firestoreMap = admin.toFirestore();
      expect(firestoreMap['uid'], 'usr_admin_001');
      expect(firestoreMap['email'], 'admin@vibetech.xyz');
      expect(firestoreMap['saldo'], 10000000.0);
      expect(firestoreMap['role'], 'admin');
      expect(firestoreMap['pin'], '112233');

      final fromDoc = UserModel.fromFirestore(firestoreMap, 'usr_admin_001');
      expect(fromDoc.uid, 'usr_admin_001');
      expect(fromDoc.nama, 'Super Administrator');
      expect(fromDoc.username, 'superadmin');
      expect(fromDoc.email, 'admin@vibetech.xyz');
      expect(fromDoc.saldo, 10000000.0);
      expect(fromDoc.isAdmin, true);
      expect(fromDoc.isUser, false);
    });

    test('UserModel copyWith works properly for updates', () {
      final initial = UserModel(
        uid: 'usr_001',
        nama: 'Original Name',
        username: 'original',
        email: 'original@vibe.xyz',
        password: 'pass',
        createdAt: '2026-08-26',
        saldo: 10000.0,
      );

      final updated = initial.copyWith(
        nama: 'Updated Name',
        saldo: 50000.0,
        pin: '998877',
      );

      expect(updated.nama, 'Updated Name');
      expect(updated.saldo, 50000.0);
      expect(updated.pin, '998877');
      expect(updated.username, 'original');
      expect(updated.email, 'original@vibe.xyz');
    });

    test('FirebaseUserService filters dummy accounts and prevents cloud leakage', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final testUid = 'usr_sync_test_$ts';
      final testData = {
        'uid': testUid,
        'nama': 'Test User Cloud $ts',
        'username': 'cloud_user_$ts',
        'email': 'cloud_$ts@vibetech.xyz',
        'phone': '081234567890',
        'password': 'passwordCloud123',
        'pin': '778899',
        'referralCode': 'SYNC2026',
        'role': 'user',
        'createdAt': DateTime.now().toIso8601String(),
        'saldo': 50000.0,
        'location': 'Jakarta, Indonesia',
        'avatarUrl': 'https://cdn.nekohime.site/file/5232n74c.jpeg',
        'is2FA': 1,
        'language': 'Indonesia',
      };

      final docId = await FirebaseUserService.instance.saveUserToFirebase(testData);
      expect(docId, testUid);

      final cloudUser = await FirebaseUserService.instance.getUserFromFirebase(testUid);
      expect(cloudUser, isNull);
    });
  });
}
