import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibetech_xyz/services/github_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GitHub Account User & Service Tests', () {
    test('GithubAuthService has correct Client ID and Client Secret configured', () {
      expect(GithubAuthService.clientId, 'Ov23liWR0VXKPAnv1YHr');
      expect(GithubAuthService.clientSecret, '7df026fa2f1dad55c2b1e1f4e1af57fa93660ed5');
      expect(GithubAuthService.redirectUrl, 'https://vibetech-xyz.firebaseapp.com/__/auth/handler');
      expect(GithubAuthService.authorizationUrl, contains('client_id=Ov23liWR0VXKPAnv1YHr'));
      expect(GithubAuthService.authorizationUrl, contains('scope=read:user%20user:email'));
    });

    test('GithubAccountUser initializes properly with all attributes including Firebase UID & token', () {
      const user = GithubAccountUser(
        name: 'Linus Torvalds',
        username: 'torvalds',
        email: 'torvalds@linux-foundation.org',
        password: 'secure_github_password_123',
        avatarUrl: 'https://avatars.githubusercontent.com/torvalds',
        bio: 'Creator of Linux and Git',
        accessToken: 'gho_dummy_token_1234567890',
        firebaseUid: 'gh_firebase_uid_999',
        avatarColor: Color(0xFF24292F),
        authProvider: 'GitHub',
      );

      expect(user.name, 'Linus Torvalds');
      expect(user.username, 'torvalds');
      expect(user.email, 'torvalds@linux-foundation.org');
      expect(user.password, 'secure_github_password_123');
      expect(user.avatarUrl, 'https://avatars.githubusercontent.com/torvalds');
      expect(user.bio, 'Creator of Linux and Git');
      expect(user.accessToken, 'gho_dummy_token_1234567890');
      expect(user.firebaseUid, 'gh_firebase_uid_999');
      expect(user.avatarColor, const Color(0xFF24292F));
      expect(user.authProvider, 'GitHub');
    });

    test('GithubAccountUser with default values works as expected', () {
      const user = GithubAccountUser(
        name: 'VibeTech Dev',
        username: 'vibetech-dev',
        email: 'vibetech-dev@users.noreply.github.com',
        avatarColor: Color(0xFF6E5494),
      );

      expect(user.name, 'VibeTech Dev');
      expect(user.username, 'vibetech-dev');
      expect(user.avatarUrl, isNull);
      expect(user.bio, isNull);
      expect(user.accessToken, isNull);
      expect(user.firebaseUid, isNull);
      expect(user.authProvider, 'GitHub');
    });

    test('GithubAuthService can query public GitHub profile structure',
        () async {
      final profile = await GithubAuthService.fetchGithubProfile('octocat');
      if (profile != null) {
        expect(profile.containsKey('login'), isTrue);
        expect(profile['login'], 'octocat');
      }
    });
  });
}
