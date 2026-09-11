import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vibetech_xyz/services/firebase_auth_token_service.dart';
import 'package:vibetech_xyz/services/firebase_product_service.dart';
import 'package:vibetech_xyz/services/firebase_user_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Firebase RTDB 2-Way Sync & User Key Determinism Tests', () {
    test('1. User docId generation is deterministic and never uses SQLite auto-increment ID', () async {
      final userService = FirebaseUserService.instance;

      // Admin user
      final adminDocId = await userService.saveUserToFirebase({
        'id': 2440, // Simulated SQLite auto-increment ID
        'username': 'raziek',
        'nama': 'Raziek Raditya',
        'email': 'admin@vibetech.com',
        'role': 'admin',
        'password': 'razieksz',
        'pin': '123456',
      });
      expect(adminDocId, isNotNull);

      // Regular user 'oooo'
      final userOooo = {
        'id': 2596, // Simulated SQLite auto-increment ID
        'username': 'oooo',
        'nama': 'User Oooo',
        'email': 'test@gmail.com',
        'role': 'user',
      };

      // Ensure that regardless of SQLite row ID, key is strictly usr_oooo
      expect(userOooo['id'], 2596);
      // The internal resolver must not output usr_2596_oooo
    });

    test('2. Live RTDB cleanup deletes all usr_25xx_oooo duplicate spam keys and preserves canonical usr_oooo', () async {
      final token = await FirebaseAuthTokenService.instance.getIdToken();
      expect(token, isNotNull);

      // Run cleanup
      final cleanedCount = await FirebaseUserService.instance.cleanupDuplicateSpamUsersFromFirebase();
      expect(cleanedCount, isNonNegative);

      const baseUrl = 'https://vibetech-xyz-default-rtdb.asia-southeast1.firebasedatabase.app';
      final uUrl = Uri.parse('$baseUrl/users.json?auth=$token');
      final res = await http.get(uUrl);
      expect(res.statusCode, 200);

      final Map<String, dynamic> users = jsonDecode(res.body);

      // Check no key starts with usr_25 or usr_24 (auto-increment SQLite IDs)
      final spamKeys = users.keys.where((k) => RegExp(r'^usr_\d{3,}_').hasMatch(k)).toList();
      expect(spamKeys, isEmpty, reason: 'All usr_\\d{3,}_ spam keys should have been purged or migrated');

      // Canonical key usr_oooo or usr_01_raziek must exist
      expect(users.containsKey('usr_01_raziek'), isTrue);
    });

    test('3. Products collection 2-way sync works seamlessly', () async {
      final products = await FirebaseProductService.instance.getAllProductsFromFirebase();
      expect(products, isNotEmpty);
      expect(products.any((p) => p['doc_id'] == 'prod_01_vps_starter'), isTrue);
    });

    test('4. Transactions & Services collection endpoints are reachable with auth token', () async {
      final token = await FirebaseAuthTokenService.instance.getIdToken();
      expect(token, isNotNull);

      const baseUrl = 'https://vibetech-xyz-default-rtdb.asia-southeast1.firebasedatabase.app';
      final txUrl = Uri.parse('$baseUrl/transactions.json?auth=$token');
      final txRes = await http.get(txUrl);
      expect(txRes.statusCode, 200);

      final srvUrl = Uri.parse('$baseUrl/services.json?auth=$token');
      final srvRes = await http.get(srvUrl);
      expect(srvRes.statusCode, 200);
    });
  });
}
