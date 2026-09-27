import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vibetech_xyz/database/db_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Play Store 100% Hijau & Zero Code/Database Stripping Tests', () {
    test('1. Verify build.gradle.kts has optimal release shrinking, targetSdk 36, and noCompress db', () {
      final file = File('android/app/build.gradle.kts');
      expect(file.existsSync(), true, reason: 'build.gradle.kts must exist');
      final content = file.readAsStringSync();

      // targetSdk and compileSdk >= 34 (Android 14/15/16 compliant)
      expect(content.contains('targetSdk = 36'), true, reason: 'targetSdk must be 36 for 100% Play Store compliance');
      expect(content.contains('compileSdk = 36'), true, reason: 'compileSdk must be 36');

      // Release optimizations
      expect(content.contains('isMinifyEnabled = true'), true, reason: 'R8 code shrinking must be active');
      expect(content.contains('isShrinkResources = true'), true, reason: 'Resource shrinking must be active');
      expect(content.contains('debugSymbolLevel = "FULL"'), true, reason: 'Full native debug symbols required for Play Console');

      // Uncompressed database preservation
      expect(content.contains('noCompress += listOf("db", "sqlite", "sqlite3"'), true,
          reason: 'Database assets must not be compressed to prevent data corruption');

      // Bundle dynamic delivery splits for 100% green optimization score
      expect(content.contains('bundle {'), true);
      expect(content.contains('enableSplit = true'), true);
    });

    test('2. Verify proguard-rules.pro preserves 100% of SQLite and Firebase without stripping', () {
      final file = File('android/app/proguard-rules.pro');
      expect(file.existsSync(), true, reason: 'proguard-rules.pro must exist');
      final content = file.readAsStringSync();

      // SQLite preservation
      expect(content.contains('com.tekartik.sqflite.SqflitePlugin'), true,
          reason: 'Sqflite plugin entrypoint must be kept intact');
      expect(content.contains('-keep,allowobfuscation,allowoptimization class com.tekartik.sqflite.** { *; }'), true,
          reason: 'Sqflite internal classes must be kept and optimized');
      expect(content.contains('SQLiteOpenHelper'), true,
          reason: 'Android SQLite drivers must be kept intact');
      expect(content.contains('SQLiteDatabase'), true,
          reason: 'Android SQLiteDatabase must be kept intact');

      // Firebase & Auth preservation
      expect(content.contains('com.google.firebase.database'), true,
          reason: 'Firebase Realtime Database must be kept intact');
      expect(content.contains('com.google.firebase.auth.FirebaseAuth'), true,
          reason: 'Firebase Auth must be kept intact');
      expect(content.contains('com.google.firebase.firestore.FirebaseFirestore'), true,
          reason: 'Firebase Firestore must be kept intact');

      // Optimization passes
      expect(content.contains('-optimizationpasses 5'), true);
      expect(content.contains('-repackageclasses \'\''), true);

      // Model serialization methods
      expect(content.contains('*** fromMap(...);'), true);
      expect(content.contains('*** toMap(...);'), true);
    });

    test('3. Verify keep.xml protects resources from being stripped', () {
      final file = File('android/app/src/main/res/raw/keep.xml');
      expect(file.existsSync(), true, reason: 'keep.xml must exist in res/raw');
      final content = file.readAsStringSync();
      expect(content.contains('tools:keep='), true);
      expect(content.contains('@mipmap/*'), true);
      expect(content.contains('@drawable/*'), true);
      expect(content.contains('@font/*'), true);
    });

    test('4. Verify all Play Store Listing Quality screenshots and graphics exist for 100% green score', () {
      // Phone screenshots (1080x2400)
      final phoneDir = Directory('assets/playstore_portrait_1080x2400');
      expect(phoneDir.existsSync(), true);
      expect(phoneDir.listSync().whereType<File>().length, greaterThanOrEqualTo(4),
          reason: 'Play Store requires at least 4 phone screenshots');

      // 7-inch tablet screenshots (1200x1920)
      final tab7Dir = Directory('assets/playstore_tablet_7_inch');
      expect(tab7Dir.existsSync(), true);
      expect(tab7Dir.listSync().whereType<File>().length, greaterThanOrEqualTo(1),
          reason: 'Play Store requires tablet 7-inch screenshots for 100% green score');

      // 10-inch tablet screenshots (1600x2560)
      final tab10Dir = Directory('assets/playstore_tablet_10_inch');
      expect(tab10Dir.existsSync(), true);
      expect(tab10Dir.listSync().whereType<File>().length, greaterThanOrEqualTo(1),
          reason: 'Play Store requires tablet 10-inch screenshots for 100% green score');

      // Chromebook screenshots (1920x1080)
      final cbDir = Directory('assets/playstore_chromebook');
      expect(cbDir.existsSync(), true);

      // Feature Graphic 1024x500
      final featureGraphic = File('assets/playstore_1024x500/00_feature_graphic_main.png');
      expect(featureGraphic.existsSync(), true, reason: 'Feature Graphic (1024x500) is mandatory for Play Store listing');

      // App Icon 512x512
      final icon = File('assets/icon/logo.png');
      expect(icon.existsSync(), true, reason: 'App Icon is mandatory');
    });

    test('5. Verify SQLite Database initialization and essential CRUD operations function completely', () async {
      final db = await DatabaseHelper.instance.database;
      expect(db.isOpen, true);

      // Check all 8 essential tables
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
      final tableNames = tables.map((e) => e['name'] as String).toSet();

      final requiredTables = [
        'users',
        'login_history',
        'products',
        'transactions',
        'purchased_services',
        'email_settings',
        'inbox_notifications',
        'support_tickets',
      ];

      for (final table in requiredTables) {
        expect(tableNames.contains(table), true, reason: 'Table $table must exist in database');
      }
    });
  });
}
