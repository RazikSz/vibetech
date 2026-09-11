import 'package:flutter_test/flutter_test.dart';
import 'package:vibetech_xyz/services/firebase_user_service.dart';
import 'package:vibetech_xyz/services/github_auth_service.dart';

void main() {
  group('Google & GitHub Auth Firebase Sync & Dummy Filter Tests', () {
    test('FirebaseUserService.isDummyUser accurately detects and filters dummy accounts', () {
      final dummyGoogle = {
        'email': 'alex.pratama.12345@gmail.com',
        'nama': 'Alex Pratama Google',
        'username': 'alex_pratama_123',
      };
      expect(FirebaseUserService.isDummyUser(dummyGoogle), isTrue);

      final dummyGithub = {
        'email': 'dev.github.999@vibetech.xyz',
        'nama': 'Developer GitHub Pro',
        'username': 'dev_github_999',
      };
      expect(FirebaseUserService.isDummyUser(dummyGithub), isTrue);

      final dummyCloud = {
        'email': 'cloud_1787@vibetech.xyz',
        'nama': 'Cloud Test User',
        'username': 'cloud_1787',
      };
      expect(FirebaseUserService.isDummyUser(dummyCloud), isTrue);

      final dummyDemouser = {
        'email': 'user@vibetech.com',
        'nama': 'Demo Member',
        'username': 'demouser',
      };
      expect(FirebaseUserService.isDummyUser(dummyDemouser), isTrue);

      final realUser = {
        'uid': 'usr_real_999',
        'email': 'raziek.official@gmail.com',
        'nama': 'Raziek Setiawan',
        'username': 'raziek_pro',
      };
      expect(FirebaseUserService.isDummyUser(realUser), isFalse);
    });

    test('saveUserToFirebase safely ignores dummy accounts from cloud database', () async {
      final dummyUserData = {
        'uid': 'gh_dummy_test_123',
        'nama': 'Developer GitHub Dummy',
        'username': 'dev_github_dummy',
        'email': 'dev.github.dummy@vibetech.xyz',
        'phone': '081299887766',
        'password': 'github_oauth_pass',
        'role': 'user',
        'authProvider': 'GitHub',
      };

      await FirebaseUserService.instance.deleteUserFromFirebase(docId: 'gh_dummy_test_123');
      final docId = await FirebaseUserService.instance.saveUserToFirebase(dummyUserData);
      expect(docId, 'gh_dummy_test_123');

      // Memastikan akun dummy tidak tersimpan di cloud database
      final cloudUser = await FirebaseUserService.instance.getUserFromFirebase('gh_dummy_test_123');
      expect(cloudUser, isNull);
    });

    test('GithubAuthService credentials match Firebase Authentication configuration perfectly', () {
      expect(GithubAuthService.clientId, equals('Ov23liWR0VXKPAnv1YHr'));
      expect(GithubAuthService.clientSecret, equals('7df026fa2f1dad55c2b1e1f4e1af57fa93660ed5'));
      expect(GithubAuthService.redirectUrl, equals('https://vibetech-xyz.firebaseapp.com/__/auth/handler'));
      expect(GithubAuthService.authorizationUrl, contains('client_id=Ov23liWR0VXKPAnv1YHr'));
      expect(GithubAuthService.authorizationUrl, contains('vibetech-xyz.firebaseapp.com%2F__%2Fauth%2Fhandler'));
      expect(GithubAuthService.authorizationUrl, contains('scope=read:user%20user:email'));
    });
  });
}
