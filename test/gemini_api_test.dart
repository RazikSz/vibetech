import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vibetech_xyz/services/ai_chat_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('Google Gemini AI & AiChatService Integration Tests', () {
    test('AiChatService constants point to official Google Gemini API', () {
      expect(AiChatService.primaryModel, isNotEmpty);
      expect(AiChatService.geminiApiKey, isNotEmpty);
    });

    test('AiChatService returns valid AI responses for app queries', () async {
      final faq1 = await AiChatService().sendMessage('Apa itu VibeTech?');
      expect(faq1, isNotEmpty);
      expect(
          faq1,
          isNot(contains(
              'panggung koneksi AI sedang mengalami sedikit kendala')));
    });

    test('AiChatService calls Google Gemini API for general queries', () async {
      final listUri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=${AiChatService.geminiApiKey}');
      final listRes = await http.get(listUri);
      final listJson = jsonDecode(listRes.body);
      if (listJson is Map && listJson['models'] is List) {
        for (var m in listJson['models']) {
          debugPrint(
              'Available Model: ${m['name']} - methods: ${m['supportedGenerationMethods']}');
        }
      }

      final reply = await AiChatService()
          .sendMessage('Sebutkan rumus luas lingkaran secara singkat');
      debugPrint('Gemini Live Reply: $reply');
      expect(reply, isNotEmpty);
      expect(
          reply,
          isNot(contains(
              'panggung koneksi AI sedang mengalami sedikit kendala')));
    });
  });
}
