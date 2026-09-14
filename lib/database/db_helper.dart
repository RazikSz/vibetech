import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/services/firebase_email_service.dart';
import 'package:vibetech_xyz/services/firebase_product_service.dart';
import 'package:vibetech_xyz/services/firebase_realtime_listener_service.dart';
import 'package:vibetech_xyz/services/firebase_transaction_service.dart';
import 'package:vibetech_xyz/services/firebase_user_service.dart';
import 'package:vibetech_xyz/utils/security_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static bool _schemaEnsured = false;
  static bool _transactionsEnsured = false;
  static bool _servicesEnsured = false;
  static bool _notificationsEnsured = false;
  static bool _loginHistoryEnsured = false;
  static bool _supportTicketsEnsured = false;
  static bool _emailSettingsEnsured = false;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('vibetech.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // Versi database
      onConfigure: (db) async {
        try {
          await db.execute('PRAGMA busy_timeout = 5000;');
        } catch (_) {}
      },
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    // 1. Tabel Users (Menyimpan akun Pengguna, Admin, Saldo, PIN Transaksi, dan Konfigurasi Profil)
    await db.execute('''
      CREATE TABLE users (
        id $idType,
        uid $textType UNIQUE,
        nama $textType,
        username $textType UNIQUE,
        email $textType UNIQUE,
        phone $textNullable,
        password $textType,
        pin $textNullable DEFAULT '123456',
        referralCode $textNullable,
        role $textType,
        createdAt $textType,
        saldo $realType DEFAULT 0.0,
        location $textNullable,
        avatarUrl $textNullable,
        is2FA $intType DEFAULT 1,
        language $textNullable DEFAULT 'Indonesia',
        authProvider $textNullable,
        bio $textNullable
      )
    ''');

    // 2. Tabel Login History
    await db.execute('''
      CREATE TABLE login_history (
        id $idType,
        user_email $textType,
        waktu $textType,
        provider $textType,
        status $textType
      )
    ''');

    // 3. FITUR UTAMA A: Tabel Products (Katalog Produk & Paket Layanan)
    await db.execute('''
      CREATE TABLE products (
        id $idType,
        nama $textType,
        kategori $textType,
        harga $realType,
        stok $intType,
        deskripsi $textNullable,
        diskon $realType DEFAULT 0.0
      )
    ''');

    // 4. FITUR UTAMA B: Tabel Transactions (Riwayat Pesanan & Pembelian)
    await db.execute('''
      CREATE TABLE transactions (
        id $idType,
        user_email $textType,
        nama_produk $textType,
        jumlah $intType,
        total_harga $realType,
        tanggal $textType,
        status $textType,
        payment_method $textNullable,
        invoice_no $textNullable,
        notes $textNullable
      )
    ''');

    // 5. FITUR UTAMA C: Tabel Purchased Services (Data VPS, Panel Hosting, Bot WhatsApp Aktif)
    await db.execute('''
      CREATE TABLE purchased_services (
        id $idType,
        user_email $textType,
        nama_produk $textType,
        kategori $textType,
        harga $realType,
        tanggal_beli $textType,
        tanggal_kadaluarsa $textType,
        status $textType,
        ip_address $textNullable,
        port $textNullable,
        username $textNullable,
        password $textNullable,
        server_url $textNullable,
        session_id $textNullable,
        spesifikasi $textNullable,
        extra_data $textNullable
      )
    ''');

    // 6. FITUR UTAMA D: Tabel Email Settings (Konfigurasi Server Email & SMTP Permanen)
    await db.execute('''
      CREATE TABLE email_settings (
        id $idType,
        user_email $textNullable,
        smtp_user $textType,
        smtp_pass $textType,
        smtp_host $textNullable DEFAULT 'smtp.gmail.com',
        smtp_port $intType DEFAULT 465,
        is_active INTEGER NOT NULL DEFAULT 1,
        updated_at $textNullable
      )
    ''');

    // 7. FITUR UTAMA E: Tabel Inbox Notifications (Notifikasi & Riwayat Email)
    await db.execute('''
      CREATE TABLE inbox_notifications (
        id $idType,
        user_email $textNullable,
        title $textType,
        message $textType,
        category $textNullable,
        order_id $textNullable,
        amount $textNullable,
        date_time $textNullable,
        is_read $intType DEFAULT 0,
        type $textNullable,
        sender $textNullable,
        sender_name $textNullable
      )
    ''');

    // 8. FITUR UTAMA F: Tabel Support Tickets (Pesan Bantuan Pengguna)
    await db.execute('''
      CREATE TABLE support_tickets (
        id $idType,
        ticket_no $textType,
        user_name $textType,
        user_email $textType,
        subject $textType,
        message $textType,
        status $textNullable DEFAULT 'Open',
        created_at $textNullable
      )
    ''');

    await _seedDummyData(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS products (
          id $idType,
          nama $textType,
          kategori $textType,
          harga $realType,
          stok $intType,
          deskripsi $textNullable
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS transactions (
          id $idType,
          user_email $textType,
          nama_produk $textType,
          jumlah $intType,
          total_harga $realType,
          tanggal $textType,
          status $textType
        )
      ''');
    }

    await _ensureServicesTable(db);
    await _ensureEmailSettingsTable(db);
    await _ensureLoginHistoryTable(db);
    await _ensureInboxNotificationsTable(db);
    await _ensureSupportTicketsTable(db);
    await _seedDummyData(db);
  }

  Future<void> _ensureLoginHistoryTable(Database db) async {
    if (_loginHistoryEnsured) return;
    _loginHistoryEnsured = true;
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';

    await db.execute('''
      CREATE TABLE IF NOT EXISTS login_history (
        id $idType,
        user_email $textType,
        waktu $textType,
        provider $textType,
        status $textType
      )
    ''');
  }

  Future<void> _ensureInboxNotificationsTable(Database db) async {
    if (_notificationsEnsured) return;
    _notificationsEnsured = true;
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE IF NOT EXISTS inbox_notifications (
        id $idType,
        user_email $textNullable,
        title $textType,
        message $textType,
        category $textNullable,
        order_id $textNullable,
        amount $textNullable,
        date_time $textNullable,
        is_read $intType DEFAULT 0,
        type $textNullable,
        sender $textNullable,
        sender_name $textNullable
      )
    ''');
  }

  Future<void> _ensureSupportTicketsTable(Database db) async {
    if (_supportTicketsEnsured) return;
    _supportTicketsEnsured = true;
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';

    await db.execute('''
      CREATE TABLE IF NOT EXISTS support_tickets (
        id $idType,
        ticket_no $textType,
        user_name $textType,
        user_email $textType,
        subject $textType,
        message $textType,
        status $textNullable DEFAULT 'Open',
        created_at $textNullable
      )
    ''');
  }

  Future<void> _ensureEmailSettingsTable(Database db) async {
    if (_emailSettingsEnsured) return;
    _emailSettingsEnsured = true;
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE IF NOT EXISTS email_settings (
        id $idType,
        user_email $textNullable,
        smtp_user $textType,
        smtp_pass $textType,
        smtp_host $textNullable DEFAULT 'smtp.gmail.com',
        smtp_port $intType DEFAULT 465,
        is_active INTEGER NOT NULL DEFAULT 1,
        updated_at $textNullable
      )
    ''');

    // Auto-migration jika tabel email_settings sudah ada tanpa kolom is_active
    try {
      await db.execute('ALTER TABLE email_settings ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1');
    } catch (_) {}
  }

  Future<void> _ensureServicesTable(Database db) async {
    if (_servicesEnsured) return;
    _servicesEnsured = true;
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const realType = 'REAL NOT NULL';

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchased_services (
        id $idType,
        user_email $textType,
        nama_produk $textType,
        kategori $textType,
        harga $realType,
        tanggal_beli $textType,
        tanggal_kadaluarsa $textType,
        status $textType,
        ip_address $textNullable,
        port $textNullable,
        username $textNullable,
        password $textNullable,
        server_url $textNullable,
        session_id $textNullable,
        spesifikasi $textNullable,
        extra_data $textNullable
      )
    ''');
  }

  /// PENGISIAN DATA DUMMY AWAL
  Future<void> _seedDummyData(Database db) async {
    await _ensureServicesTable(db);
    await _ensureEmailSettingsTable(db);
    await _ensureLoginHistoryTable(db);
    await _ensureInboxNotificationsTable(db);
    await _ensureSupportTicketsTable(db);

    // 0. Seed Konfigurasi Server Email Default
    final emailSettingsCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM email_settings')) ??
        0;
    if (emailSettingsCount == 0) {
      await db.insert('email_settings', {
        'user_email': 'admin@vibetech.com',
        'smtp_user': 'vibetech.official.xyz@gmail.com',
        'smtp_pass':
            SecurityHelper.deobfuscate('PC8yKXorKiwvejwpMSJ6MDcpLQ=='),
        'smtp_host': 'smtp.gmail.com',
        'smtp_port': 465,
        'is_active': 1,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    // 0.1 Seed Notifikasi Awal Default jika Kosong
    final notifCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM inbox_notifications')) ??
        0;
    if (notifCount == 0) {
      await db.insert('inbox_notifications', {
        'user_email': 'user@vibetech.com',
        'title': 'Selamat Datang di VibeTech XYZ! 🎉',
        'message':
            'Terima kasih telah bergabung di ekosistem Cloud Hosting & Digital Services VibeTech XYZ. Dapatkan performa server terbaik untuk kebutuhan bisnis dan operasional Anda.',
        'category': 'Sistem',
        'order_id': null,
        'amount': null,
        'date_time': 'Hari ini, 09:00 WIB',
        'is_read': 0,
        'type': 'info',
        'sender': 'system@vibetech.xyz',
        'sender_name': 'VibeTech Official System',
      });
      await db.insert('inbox_notifications', {
        'user_email': 'user@vibetech.com',
        'title': 'Promo Spesial Cloud Hosting 20%',
        'message':
            'Dapatkan potongan harga sebesar 20% untuk pembelian paket VPS Starter & Panel Hosting Singapore bulan ini.',
        'category': 'Promo & Diskon',
        'order_id': null,
        'amount': null,
        'date_time': 'Kemarin',
        'is_read': 1,
        'type': 'promo',
        'sender': 'promo@vibetech.xyz',
        'sender_name': 'VibeTech Promo System',
      });
    }

    // 1. Data Akun Admin Resmi Default
    final adminCount = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM users WHERE role = 'admin' OR username = 'admin' OR email = 'admin@vibetech.com'")) ??
        0;
    if (adminCount == 0) {
      final adminData = {
        'uid': 'usr_admin_001',
        'nama': 'Admin VibeTech',
        'username': 'raziek',
        'email': 'admin@vibetech.com',
        'phone': '081122334455',
        'password': 'razieksz',
        'pin': '123456',
        'referralCode': 'ADMIN2026',
        'role': 'admin',
        'createdAt': DateTime.now().toIso8601String(),
        'saldo': 9289000.0,
      };
      await db.insert('users', adminData);
      Future.microtask(() async {
        try {
          final cloudAdmin = await FirebaseUserService.instance
              .getUserFromFirebase('admin@vibetech.com');
          if (cloudAdmin == null) {
            await FirebaseUserService.instance.saveUserToFirebase(adminData);
          } else {
            // Jika sudah ada data admin di Firebase (misal sudah diedit saldo/profilnya), gunakan data Firebase!
            await db.update('users', {
              if (cloudAdmin['saldo'] != null)
                'saldo': (cloudAdmin['saldo'] as num).toDouble(),
              if (cloudAdmin['nama'] != null) 'nama': cloudAdmin['nama'],
              if (cloudAdmin['phone'] != null) 'phone': cloudAdmin['phone'],
              if (cloudAdmin['avatarUrl'] != null)
                'avatarUrl': cloudAdmin['avatarUrl'],
            }, where: 'email = ?', whereArgs: ['admin@vibetech.com']);
          }
        } catch (_) {}
      });
    }

    // 2. Data Produk Standar Resmi (VPS, Panel Hosting, Bot WhatsApp)
    final productCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM products')) ??
        0;
    if (productCount == 0) {
      final defaultProducts = [
        // Kategori: VPS (Virtual Private Server)
        {
          'nama': 'VPS Starter',
          'kategori': 'VPS',
          'harga': 50000.0,
          'stok': 25,
          'deskripsi':
              '1 vCPU, 1GB RAM, 25GB NVMe SSD, Bandwidth 1TB (Ubuntu 22.04)'
        },
        {
          'nama': 'VPS Basic',
          'kategori': 'VPS',
          'harga': 95000.0,
          'stok': 20,
          'deskripsi':
              '2 vCPU, 2GB RAM, 50GB NVMe SSD, Bandwidth 2TB (Ubuntu 22.04)'
        },
        {
          'nama': 'VPS Pro',
          'kategori': 'VPS',
          'harga': 160000.0,
          'stok': 15,
          'deskripsi':
              '4 vCPU, 4GB RAM, 80GB NVMe SSD, Bandwidth 3TB (Ubuntu 22.04)'
        },
        {
          'nama': 'VPS Enterprise',
          'kategori': 'VPS',
          'harga': 300000.0,
          'stok': 10,
          'deskripsi':
              '8 vCPU, 8GB RAM, 160GB NVMe SSD, Bandwidth 5TB (Ubuntu 22.04)'
        },

        // Kategori: Panel Hosting (Pterodactyl Node SG)
        {
          'nama': 'Panel Hosting 1GB',
          'kategori': 'Panel Hosting',
          'harga': 15000.0,
          'stok': 30,
          'deskripsi':
              '1GB RAM, 1 Core CPU, 10GB NVMe Storage (Pterodactyl Node SG)'
        },
        {
          'nama': 'Panel Hosting 2GB',
          'kategori': 'Panel Hosting',
          'harga': 30000.0,
          'stok': 25,
          'deskripsi':
              '2GB RAM, 1.5 Core CPU, 20GB NVMe Storage (Pterodactyl Node SG)'
        },
        {
          'nama': 'Panel Hosting 4GB',
          'kategori': 'Panel Hosting',
          'harga': 55000.0,
          'stok': 20,
          'deskripsi':
              '4GB RAM, 2 Core CPU, 40GB NVMe Storage (Pterodactyl Node SG)'
        },
        {
          'nama': 'Panel Hosting Unlimited',
          'kategori': 'Panel Hosting',
          'harga': 95000.0,
          'stok': 15,
          'deskripsi':
              'Unlimited RAM, 4 Core CPU, 100GB NVMe Storage (Pterodactyl Turbo)'
        },

        // Kategori: Bot WhatsApp (Automation & Multi-Device)
        {
          'nama': 'Bot WhatsApp Basic',
          'kategori': 'Bot WhatsApp',
          'harga': 25000.0,
          'stok': 40,
          'deskripsi':
              '1 Sesi WhatsApp, Auto-Reply, Broadcast Group, Uptime 99.9%'
        },
        {
          'nama': 'Bot WhatsApp Pro',
          'kategori': 'Bot WhatsApp',
          'harga': 50000.0,
          'stok': 30,
          'deskripsi':
              '3 Sesi WhatsApp, AI Gemini Integration, Auto Responder, Blast Unlimited'
        },
        {
          'nama': 'Bot WhatsApp Enterprise',
          'kategori': 'Bot WhatsApp',
          'harga': 100000.0,
          'stok': 20,
          'deskripsi':
              'Unlimited Sesi, Multi-Device AI Blast 24/7, Dedicated Node, Priority Support 24/7'
        },
      ];

      for (final p in defaultProducts) {
        await db.insert('products', p);
      }
    }

    // Catatan: purchased_services tidak di-seed secara hardcoded
    // Data layanan hanya muncul setelah transaksi nyata dilakukan.
  }

  // --- OPERASI USER ---
  Future<int> registerUser(Map<String, dynamic> row,
      {bool syncToCloud = true}) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);

    // Filter hanya kolom-kolom yang valid untuk tabel users di SQLite
    final validColumns = {
      'id',
      'uid',
      'nama',
      'username',
      'email',
      'phone',
      'password',
      'pin',
      'referralCode',
      'role',
      'createdAt',
      'saldo',
      'location',
      'avatarUrl',
      'is2FA',
      'language',
      'authProvider',
      'bio'
    };
    final Map<String, dynamic> sqliteRow = {};
    row.forEach((k, v) {
      if (validColumns.contains(k)) {
        sqliteRow[k] = v;
      }
    });

    // Proteksi Keamanan: Hash kata sandi dan PIN sebelum disimpan ke SQLite & Cloud
    if (sqliteRow['password'] != null && sqliteRow['password'].toString().isNotEmpty) {
      sqliteRow['password'] = SecurityHelper.hashPassword(sqliteRow['password'].toString());
    }
    if (sqliteRow['pin'] != null && sqliteRow['pin'].toString().isNotEmpty) {
      sqliteRow['pin'] = SecurityHelper.hashPin(sqliteRow['pin'].toString());
    }

    if (!sqliteRow.containsKey('createdAt') || sqliteRow['createdAt'] == null) {
      sqliteRow['createdAt'] = DateTime.now().toIso8601String();
    }

    final res = await db.insert('users', sqliteRow,
        conflictAlgorithm: ConflictAlgorithm.replace);

    // Background cloud sync ke Firebase (hanya jika dipanggil dari input pengguna / bukan echo cloud)
    if (syncToCloud && !FirebaseRealtimeListenerService.isApplyingCloudUpdate) {
      final dataToSync = Map<String, dynamic>.from(row);
      if (sqliteRow.containsKey('password')) {
        dataToSync['password'] = sqliteRow['password'];
      }
      if (sqliteRow.containsKey('pin')) {
        dataToSync['pin'] = sqliteRow['pin'];
      }
      // CATATAN KRITIS: JANGAN masukkan dataToSync['id'] = res!
      // ID baris SQLite bersifat lokal dan tidak boleh dijadikan prefix key Firebase RTDB
      FirebaseUserService.instance.saveUserToFirebase(dataToSync).catchError((e) {
        debugPrint(
            '[DatabaseHelper] Auto-sync registerUser ke Firebase info: $e');
        return null;
      });
    }
    return res;
  }

  static List<Map<String, dynamic>> _cachedProducts = [];
  static List<Map<String, dynamic>> get cachedProducts => List.unmodifiable(_cachedProducts);
  static void setCachedProducts(List<Map<String, dynamic>> products) {
    _cachedProducts = List.from(products);
  }

  Future<Map<String, dynamic>?> loginUser(
      String emailOrUsername, String password) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final clean = emailOrUsername.trim().toLowerCase();
    final isTryingAdmin = (clean == 'admin' || clean == 'admin@vibetech.com' || clean == 'raziek');

    // Cari akun berdasarkan email, username, atau nama, atau jika admin
    final res = await db.query(
      'users',
      where: 'LOWER(email) = ? OR LOWER(username) = ? OR LOWER(nama) = ?'
          ' OR (? = 1 AND (LOWER(role) = "admin" OR LOWER(role) = "administrator"))',
      whereArgs: [clean, clean, clean, isTryingAdmin ? 1 : 0],
    );
    if (res.isNotEmpty) {
      for (final row in res) {
        final storedPassword = row['password']?.toString() ?? '';
        final role = (row['role'] ?? '').toString().toLowerCase();
        final isAdminRow = (role == 'admin' || role == 'administrator');

        // Admin fallback check (mendukung razieksz, admin123, atau admin)
        final bool isPasswordValid = SecurityHelper.verifyPassword(password, storedPassword) ||
            (isAdminRow && (password == 'razieksz' || password == 'admin123' || password == 'admin'));

        if (isPasswordValid) {
          // Jika akun di database masih menyimpan format hash lama (vbt$sha256$) atau password belum tersinkronisasi
          if (storedPassword.startsWith('vbt\$sha256\$') ||
              (isAdminRow && !SecurityHelper.verifyPassword(password, storedPassword))) {
            final plainPass = password;
            await db.update(
              'users',
              {'password': plainPass},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
            final updatedMap = Map<String, dynamic>.from(row);
            updatedMap['password'] = plainPass;
            FirebaseUserService.instance.saveUserToFirebase(updatedMap).catchError((_) => null);
            return updatedMap;
          }
          return row;
        }
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final res = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<Map<String, dynamic>?> getUserByEmailOrUsername(
      String identifier) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final res = await db.query(
      'users',
      where: 'email = ? OR username = ? OR uid = ?',
      whereArgs: [identifier, identifier, identifier],
    );
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<void> _ensureExtraColumns(Database db) async {
    if (_schemaEnsured) return;
    _schemaEnsured = true;
    try {
      await db.execute('ALTER TABLE users ADD COLUMN location TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE users ADD COLUMN avatarUrl TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE users ADD COLUMN is2FA INTEGER DEFAULT 1;');
    } catch (_) {}
    try {
      await db.execute(
          'ALTER TABLE users ADD COLUMN language TEXT DEFAULT "Indonesia";');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE users ADD COLUMN saldo REAL DEFAULT 0.0;');
    } catch (_) {}
    try {
      await db
          .execute('ALTER TABLE users ADD COLUMN pin TEXT DEFAULT "123456";');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE users ADD COLUMN authProvider TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE users ADD COLUMN bio TEXT;');
    } catch (_) {}
    try {
      await db
          .execute('ALTER TABLE products ADD COLUMN diskon REAL DEFAULT 0.0;');
    } catch (_) {}
    try {
      final adminCheck = Sqflite.firstIntValue(await db.rawQuery(
              "SELECT COUNT(*) FROM users WHERE role = 'admin' OR username = 'admin' OR email = 'admin@vibetech.com'")) ??
          0;
      if (adminCheck == 0) {
        await db.insert('users', {
          'uid': 'usr_admin_001',
          'nama': 'Admin VibeTech',
          'username': 'raziek',
          'email': 'admin@vibetech.com',
          'phone': '081122334455',
          'password': 'razieksz',
          'pin': '123456',
          'referralCode': 'ADMIN2026',
          'role': 'admin',
          'createdAt': DateTime.now().toIso8601String(),
          'saldo': 9289000.0,
        });
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getUserByUsernameOrEmail(
      String identifier) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final res = await db.query(
      'users',
      where: 'username = ? OR email = ? OR nama = ? OR uid = ?',
      whereArgs: [identifier, identifier, identifier, identifier],
    );
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<Map<String, dynamic>?> getUserByUid(String uid) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final res = await db.query(
      'users',
      where: 'uid = ?',
      whereArgs: [uid],
    );
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<int> updateUserProfile(
      String identifier, Map<String, dynamic> data) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    int res = 0;
    try {
      res = await db.update(
        'users',
        data,
        where: 'username = ? OR email = ? OR nama = ? OR uid = ?',
        whereArgs: [identifier, identifier, identifier, identifier],
      );
    } catch (e) {
      if (data.containsKey('username')) {
        final fallback = Map<String, dynamic>.from(data)..remove('username');
        res = await db.update(
          'users',
          fallback,
          where: 'username = ? OR email = ? OR nama = ? OR uid = ?',
          whereArgs: [identifier, identifier, identifier, identifier],
        );
      }
    }
    // Auto-sync ke Firebase di latar belakang (non-blocking 0ms)
    Future.microtask(() async {
      try {
        final updatedUser = await getUserByUsernameOrEmail(identifier);
        if (updatedUser != null) {
          await FirebaseUserService.instance.saveUserToFirebase(updatedUser);
        } else {
          await FirebaseUserService.instance.updateUserInFirebase(
            uid: identifier.startsWith('usr_') ? identifier : null,
            email: identifier.contains('@') ? identifier : null,
            username:
                (!identifier.startsWith('usr_') && !identifier.contains('@'))
                    ? identifier
                    : null,
            updatedData: data,
          );
        }
      } catch (e) {
        debugPrint(
            '[DatabaseHelper] Auto-sync updateUserProfile ke Firebase gagal: $e');
      }
    });
    return res;
  }

  Future<int> updateUserByUid(String uid, Map<String, dynamic> data,
      {bool syncToCloud = true}) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    int res = 0;
    try {
      res = await db.update(
        'users',
        data,
        where: 'uid = ?',
        whereArgs: [uid],
      );
    } catch (e) {
      if (data.containsKey('username')) {
        final fallback = Map<String, dynamic>.from(data)..remove('username');
        res = await db.update(
          'users',
          fallback,
          where: 'uid = ?',
          whereArgs: [uid],
        );
      }
    }
    // Auto-sync ke Firebase di latar belakang (non-blocking 0ms)
    if (!syncToCloud || FirebaseRealtimeListenerService.isApplyingCloudUpdate) {
      return res;
    }
    Future.microtask(() async {
      try {
        final updatedUser = await getUserByUid(uid);
        if (updatedUser != null) {
          await FirebaseUserService.instance.saveUserToFirebase(updatedUser);
        } else {
          await FirebaseUserService.instance.updateUserInFirebase(
            uid: uid,
            updatedData: data,
          );
        }
      } catch (e) {
        debugPrint(
            '[DatabaseHelper] Auto-sync updateUserByUid ke Firebase gagal: $e');
      }
    });
    return res;
  }

  /// Memperbarui akun berdasarkan ID numerik primer dengan opsi kontrol sync ke cloud
  Future<int> updateUserById(int id, Map<String, dynamic> data,
      {bool syncToCloud = true}) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    int res = 0;
    try {
      res = await db.update(
        'users',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      if (data.containsKey('username')) {
        final fallback = Map<String, dynamic>.from(data)..remove('username');
        res = await db.update(
          'users',
          fallback,
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
    if (!syncToCloud || FirebaseRealtimeListenerService.isApplyingCloudUpdate) {
      return res;
    }
    Future.microtask(() async {
      try {
        final userQuery =
            await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
        if (userQuery.isNotEmpty) {
          await FirebaseUserService.instance
              .saveUserToFirebase(userQuery.first);
        }
      } catch (e) {
        debugPrint(
            '[DatabaseHelper] Auto-sync updateUserById ke Firebase gagal: $e');
      }
    });
    return res;
  }

  // --- OPERASI SALDO & PIN TRANSAKSI PER AKUN ---
  Future<double> getUserBalance(String identifier) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final clean = identifier.trim().toLowerCase();
    final res = await db.query(
      'users',
      columns: ['saldo'],
      where:
          'LOWER(username) = ? OR LOWER(email) = ? OR LOWER(nama) = ? OR uid = ?',
      whereArgs: [clean, clean, clean, identifier.trim()],
    );
    if (res.isNotEmpty && res.first['saldo'] != null) {
      return (res.first['saldo'] as num).toDouble();
    }
    return 0.0;
  }

  Future<int> updateUserBalance(String identifier, double newBalance) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final clean = identifier.trim().toLowerCase();

    final existing = await db.query(
      'users',
      where:
          'LOWER(username) = ? OR LOWER(email) = ? OR LOWER(nama) = ? OR uid = ?',
      whereArgs: [clean, clean, clean, identifier.trim()],
      limit: 1,
    );

    int resId;
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      resId = await db.update(
        'users',
        {'saldo': newBalance},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (FirebaseRealtimeListenerService.isApplyingCloudUpdate) return resId;
      Future.microtask(() async {
        try {
          final full = Map<String, dynamic>.from(existing.first);
          full['saldo'] = newBalance;
          if (FirebaseUserService.isDummyUser(full)) return;
          await FirebaseUserService.instance.saveUserToFirebase(full);
        } catch (e) {
          debugPrint(
              '[DatabaseHelper] Auto-sync updateUserBalance ke Firebase gagal: $e');
        }
      });
      return resId;
    } else {
      final uid = 'usr_${DateTime.now().millisecondsSinceEpoch}';
      final username = identifier.contains('@')
          ? identifier.split('@').first
          : identifier.trim();
      final email =
          identifier.contains('@') ? identifier.trim() : '$clean@vibetech.com';

      final newUser = {
        'uid': uid,
        'nama': username,
        'username': username,
        'email': email,
        'phone': '081234567890',
        'password': SecurityHelper.hashPassword('vbt_vault_${DateTime.now().millisecondsSinceEpoch}'),
        'pin': SecurityHelper.hashPin('123456'),
        'role': 'user',
        'createdAt': DateTime.now().toIso8601String(),
        'saldo': newBalance,
      };

      resId = await db.insert('users', newUser);
      Future.microtask(() async {
        try {
          if (FirebaseUserService.isDummyUser(newUser)) return;
          await FirebaseUserService.instance.saveUserToFirebase(newUser);
        } catch (e) {
          debugPrint(
              '[DatabaseHelper] Auto-sync insert updateUserBalance ke Firebase gagal: $e');
        }
      });
      return resId;
    }
  }

  Future<double> addSaldo(String identifier, double amount) async {
    final current = await getUserBalance(identifier);
    if (amount <= 0) return current;
    final updated = current + amount;
    await updateUserBalance(identifier, updated);
    return updated;
  }

  Future<bool> deductSaldo(String identifier, double amount) async {
    if (amount <= 0) return false;
    final current = await getUserBalance(identifier);
    if (current < amount) return false;
    final updated = current - amount;
    await updateUserBalance(identifier, updated);
    return true;
  }

  Future<bool> verifyUserPassword(
      String identifier, String currentPassword) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final res = await db.query(
      'users',
      columns: ['password'],
      where: 'username = ? OR email = ? OR nama = ? OR uid = ?',
      whereArgs: [identifier, identifier, identifier, identifier],
    );
    if (res.isNotEmpty) {
      final savedPass = res.first['password']?.toString() ?? '';
      return SecurityHelper.verifyPassword(currentPassword, savedPass);
    }
    return false;
  }

  /// Memverifikasi PIN Transaksi 6-Digit Pengguna terhadap Database SQLite
  Future<bool> verifyUserPin(String identifier, String inputPin) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final res = await db.query(
      'users',
      columns: ['id', 'pin'],
      where: 'username = ? OR email = ? OR nama = ? OR uid = ?',
      whereArgs: [identifier, identifier, identifier, identifier],
    );
    if (res.isNotEmpty) {
      final savedPin = res.first['pin']?.toString();
      // Default fallback jika pin belum terisi adalah '123456'
      if (savedPin == null || savedPin.isEmpty) {
        if (inputPin == '123456') {
          final defaultHashed = SecurityHelper.hashPin('123456');
          await db.update(
            'users',
            {'pin': defaultHashed},
            where: 'id = ?',
            whereArgs: [res.first['id']],
          );
          return true;
        }
        return false;
      }
      final isValid = SecurityHelper.verifyPin(inputPin, savedPin);
      if (isValid && SecurityHelper.isLegacyPin(savedPin)) {
        final newHashedPin = SecurityHelper.hashPin(inputPin);
        await db.update(
          'users',
          {'pin': newHashedPin},
          where: 'id = ?',
          whereArgs: [res.first['id']],
        );
      }
      return isValid;
    }
    // Jika user tidak ditemukan, tolak verifikasi
    return false;
  }

  /// Memperbarui PIN Transaksi 6-Digit Pengguna di Database SQLite
  Future<int> updateUserPin(String identifier, String newPin) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final hashedPin = SecurityHelper.hashPin(newPin);
    final res = await db.update(
      'users',
      {'pin': hashedPin},
      where: 'username = ? OR email = ? OR nama = ? OR uid = ?',
      whereArgs: [identifier, identifier, identifier, identifier],
    );
    Future.microtask(() async {
      try {
        final updatedUser = await getUserByUsernameOrEmail(identifier);
        if (updatedUser != null) {
          await FirebaseUserService.instance.saveUserToFirebase(updatedUser);
        } else {
          await FirebaseUserService.instance.updateUserInFirebase(
            uid: identifier.startsWith('usr_') ? identifier : null,
            email: identifier.contains('@') ? identifier : null,
            username:
                (!identifier.startsWith('usr_') && !identifier.contains('@'))
                    ? identifier
                    : null,
            updatedData: {'pin': hashedPin},
          );
        }
      } catch (e) {
        debugPrint(
            '[DatabaseHelper] Auto-sync updateUserPin ke Firebase gagal: $e');
      }
    });
    return res;
  }

  /// Mengambil PIN Transaksi Pengguna
  Future<String?> getUserPin(String identifier) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final res = await db.query(
      'users',
      columns: ['pin'],
      where: 'username = ? OR email = ? OR nama = ? OR uid = ?',
      whereArgs: [identifier, identifier, identifier, identifier],
    );
    if (res.isNotEmpty) {
      return res.first['pin']?.toString() ?? '123456';
    }
    return null;
  }

  Future<int> updateUserPassword(String identifier, String newPassword) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final hashedPass = SecurityHelper.hashPassword(newPassword);
    final res = await db.update(
      'users',
      {'password': hashedPass},
      where: 'username = ? OR email = ? OR nama = ? OR uid = ?',
      whereArgs: [identifier, identifier, identifier, identifier],
    );
    Future.microtask(() async {
      try {
        final updatedUser = await getUserByUsernameOrEmail(identifier);
        if (updatedUser != null) {
          await FirebaseUserService.instance.saveUserToFirebase(updatedUser);
        } else {
          await FirebaseUserService.instance.updateUserInFirebase(
            uid: identifier.startsWith('usr_') ? identifier : null,
            email: identifier.contains('@') ? identifier : null,
            username:
                (!identifier.startsWith('usr_') && !identifier.contains('@'))
                    ? identifier
                    : null,
            updatedData: {'password': hashedPass},
          );
        }
      } catch (e) {
        debugPrint(
            '[DatabaseHelper] Auto-sync updateUserPassword ke Firebase gagal: $e');
      }
    });
    return res;
  }

  Future<int> updateUser2FA(String identifier, bool is2FA) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final res = await db.update(
      'users',
      {'is2FA': is2FA ? 1 : 0},
      where: 'username = ? OR email = ? OR nama = ? OR uid = ?',
      whereArgs: [identifier, identifier, identifier, identifier],
    );
    Future.microtask(() async {
      try {
        final updatedUser = await getUserByUsernameOrEmail(identifier);
        if (updatedUser != null) {
          await FirebaseUserService.instance.saveUserToFirebase(updatedUser);
        } else {
          await FirebaseUserService.instance.updateUserInFirebase(
            uid: identifier.startsWith('usr_') ? identifier : null,
            email: identifier.contains('@') ? identifier : null,
            username:
                (!identifier.startsWith('usr_') && !identifier.contains('@'))
                    ? identifier
                    : null,
            updatedData: {'is2FA': is2FA ? 1 : 0},
          );
        }
      } catch (e) {
        debugPrint(
            '[DatabaseHelper] Auto-sync updateUser2FA ke Firebase gagal: $e');
      }
    });
    return res;
  }

  Future<int> updateUserLanguage(String identifier, String language) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final res = await db.update(
      'users',
      {'language': language},
      where: 'username = ? OR email = ? OR nama = ? OR uid = ?',
      whereArgs: [identifier, identifier, identifier, identifier],
    );
    Future.microtask(() async {
      try {
        final updatedUser = await getUserByUsernameOrEmail(identifier);
        if (updatedUser != null) {
          await FirebaseUserService.instance.saveUserToFirebase(updatedUser);
        } else {
          await FirebaseUserService.instance.updateUserInFirebase(
            uid: identifier.startsWith('usr_') ? identifier : null,
            email: identifier.contains('@') ? identifier : null,
            username:
                (!identifier.startsWith('usr_') && !identifier.contains('@'))
                    ? identifier
                    : null,
            updatedData: {'language': language},
          );
        }
      } catch (e) {
        debugPrint(
            '[DatabaseHelper] Auto-sync updateUserLanguage ke Firebase gagal: $e');
      }
    });
    return res;
  }

  // --- FITUR UTAMA A: FULL CRUD PRODUK ---
  Future<int> createProduct(Map<String, dynamic> productData) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final res = await db.insert('products', productData);
    final newProduct = Map<String, dynamic>.from(productData);
    newProduct['id'] = res;
    _cachedProducts = [newProduct, ..._cachedProducts];
    if (FirebaseRealtimeListenerService.isApplyingCloudUpdate) return res;
    try {
      final syncData = Map<String, dynamic>.from(productData);
      syncData['id'] = res;
      await FirebaseProductService.instance.saveProductToFirebase(syncData);
    } catch (e) {
      debugPrint('[DatabaseHelper] Auto-sync createProduct ke Firebase: $e');
    }
    return res;
  }

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final res = await db.query('products', orderBy: 'id DESC');
    if (res.isNotEmpty) {
      _cachedProducts = List.from(res);
    }
    return res;
  }

  Future<int> updateProduct(int id, Map<String, dynamic> productData) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final res = await db
        .update('products', productData, where: 'id = ?', whereArgs: [id]);
    _cachedProducts = _cachedProducts.map((p) {
      if (p['id'] == id) {
        final updated = Map<String, dynamic>.from(p);
        updated.addAll(productData);
        return updated;
      }
      return p;
    }).toList();
    if (FirebaseRealtimeListenerService.isApplyingCloudUpdate) return res;
    try {
      await FirebaseProductService.instance
          .updateProductInFirebase(id, productData);
    } catch (e) {
      debugPrint('[DatabaseHelper] Auto-sync updateProduct ke Firebase: $e');
    }
    return res;
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    final res = await db.delete('products', where: 'id = ?', whereArgs: [id]);
    _cachedProducts = _cachedProducts.where((p) => p['id'] != id).toList();
    if (FirebaseRealtimeListenerService.isApplyingCloudUpdate) return res;
    try {
      await FirebaseProductService.instance.deleteProductFromFirebase(id);
    } catch (e) {
      debugPrint('[DatabaseHelper] Auto-sync deleteProduct ke Firebase: $e');
    }
    return res;
  }

  /// Mereset dan mengisi ulang katalog produk resmi standar pasar ke SQLite & Firebase
  Future<void> resetCatalogToStandardProducts() async {
    final db = await instance.database;
    await _ensureExtraColumns(db);

    final defaultProducts = [
      // Kategori: VPS (Virtual Private Server)
      {
        'nama': 'VPS Starter',
        'kategori': 'VPS',
        'harga': 50000.0,
        'stok': 25,
        'deskripsi':
            '1 vCPU, 1GB RAM, 25GB NVMe SSD, Bandwidth 1TB (Ubuntu 22.04)'
      },
      {
        'nama': 'VPS Basic',
        'kategori': 'VPS',
        'harga': 95000.0,
        'stok': 20,
        'deskripsi':
            '2 vCPU, 2GB RAM, 50GB NVMe SSD, Bandwidth 2TB (Ubuntu 22.04)'
      },
      {
        'nama': 'VPS Pro',
        'kategori': 'VPS',
        'harga': 160000.0,
        'stok': 15,
        'deskripsi':
            '4 vCPU, 4GB RAM, 80GB NVMe SSD, Bandwidth 3TB (Ubuntu 22.04)'
      },
      {
        'nama': 'VPS Enterprise',
        'kategori': 'VPS',
        'harga': 300000.0,
        'stok': 10,
        'deskripsi':
            '8 vCPU, 8GB RAM, 160GB NVMe SSD, Bandwidth 5TB (Ubuntu 22.04)'
      },

      // Kategori: Panel Hosting (Pterodactyl Node SG)
      {
        'nama': 'Panel Hosting 1GB',
        'kategori': 'Panel Hosting',
        'harga': 15000.0,
        'stok': 30,
        'deskripsi':
            '1GB RAM, 1 Core CPU, 10GB NVMe Storage (Pterodactyl Node SG)'
      },
      {
        'nama': 'Panel Hosting 2GB',
        'kategori': 'Panel Hosting',
        'harga': 30000.0,
        'stok': 25,
        'deskripsi':
            '2GB RAM, 1.5 Core CPU, 20GB NVMe Storage (Pterodactyl Node SG)'
      },
      {
        'nama': 'Panel Hosting 4GB',
        'kategori': 'Panel Hosting',
        'harga': 55000.0,
        'stok': 20,
        'deskripsi':
            '4GB RAM, 2 Core CPU, 40GB NVMe Storage (Pterodactyl Node SG)'
      },
      {
        'nama': 'Panel Hosting Unlimited',
        'kategori': 'Panel Hosting',
        'harga': 95000.0,
        'stok': 15,
        'deskripsi':
            'Unlimited RAM, 4 Core CPU, 100GB NVMe Storage (Pterodactyl Turbo)'
      },

      // Kategori: Bot WhatsApp (Automation & Multi-Device)
      {
        'nama': 'Bot WhatsApp Basic',
        'kategori': 'Bot WhatsApp',
        'harga': 25000.0,
        'stok': 40,
        'deskripsi':
            '1 Sesi WhatsApp, Auto-Reply, Broadcast Group, Uptime 99.9%'
      },
      {
        'nama': 'Bot WhatsApp Pro',
        'kategori': 'Bot WhatsApp',
        'harga': 50000.0,
        'stok': 30,
        'deskripsi':
            '3 Sesi WhatsApp, AI Gemini Integration, Auto Responder, Blast Unlimited'
      },
      {
        'nama': 'Bot WhatsApp Enterprise',
        'kategori': 'Bot WhatsApp',
        'harga': 100000.0,
        'stok': 20,
        'deskripsi':
            'Unlimited Sesi, Multi-Device AI Blast 24/7, Dedicated Node, Priority Support 24/7'
      },
    ];

    for (final p in defaultProducts) {
      final existing = await db.query(
        'products',
        where: 'nama = ?',
        whereArgs: [p['nama']],
        limit: 1,
      );

      int prodId;
      if (existing.isNotEmpty) {
        prodId = existing.first['id'] as int;
        // Produk sudah ada: pertahankan diskon & data aktif yang sudah disetel user
      } else {
        prodId = await db.insert('products', p);
        final syncData = Map<String, dynamic>.from(p);
        syncData['id'] = prodId;
        Future.microtask(() async {
          try {
            await FirebaseProductService.instance
                .saveProductToFirebase(syncData);
          } catch (_) {}
        });
      }
    }
  }

  /// Memperbarui persentase diskon untuk produk tertentu
  Future<int> updateProductDiscount(int id, double discountPercent) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final res = await db.update(
      'products',
      {'diskon': discountPercent},
      where: 'id = ?',
      whereArgs: [id],
    );
    Future.microtask(() async {
      try {
        await FirebaseProductService.instance
            .updateProductDiscountInFirebase(id, discountPercent);
      } catch (e) {
        debugPrint(
            '[DatabaseHelper] Auto-sync updateProductDiscount ke Firebase: $e');
      }
    });
    return res;
  }

  /// Menerapkan diskon massal ke kategori produk atau seluruh katalog ('Semua')
  Future<int> applyCategoryDiscount(
      String category, double discountPercent) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    int res;
    if (category == 'Semua' || category == 'All') {
      res = await db.update('products', {'diskon': discountPercent});
    } else {
      res = await db.update(
        'products',
        {'diskon': discountPercent},
        where: 'kategori LIKE ?',
        whereArgs: ['%$category%'],
      );
    }
    Future.microtask(() async {
      try {
        await FirebaseProductService.instance
            .applyCategoryDiscountInFirebase(category, discountPercent);
      } catch (e) {
        debugPrint(
            '[DatabaseHelper] Auto-sync applyCategoryDiscount ke Firebase: $e');
      }
    });
    return res;
  }

  /// Menghapus / reset diskon produk tertentu (kembali ke 0%) di SQLite & Firebase
  Future<int> deleteProductDiscount(int id) async {
    return await updateProductDiscount(id, 0.0);
  }

  /// Menghapus / reset diskon kategori tertentu di SQLite & Firebase
  Future<int> removeCategoryDiscount(String category) async {
    return await applyCategoryDiscount(category, 0.0);
  }

  // --- OPERASI USER TAMBAHAN (PORTAL ADMINISTRATOR) ---

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final raw = await db.query('users', orderBy: 'id ASC');
    return raw.map((u) => Map<String, dynamic>.from(u)).toList();
  }

  /// Memperbarui seluruh data pengguna berdasarkan ID primary key (Portal Administrator)
  Future<int> updateUserFull(int id, Map<String, dynamic> data) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);

    final validColumns = {
      'id',
      'uid',
      'nama',
      'username',
      'email',
      'phone',
      'password',
      'pin',
      'referralCode',
      'role',
      'createdAt',
      'saldo',
      'location',
      'avatarUrl',
      'is2FA',
      'language',
      'authProvider',
      'bio'
    };
    final Map<String, dynamic> sqliteData = {};
    data.forEach((k, v) {
      if (validColumns.contains(k)) {
        sqliteData[k] = v;
      }
    });

    if (sqliteData['password'] != null &&
        sqliteData['password'].toString().isNotEmpty) {
      sqliteData['password'] =
          SecurityHelper.hashPassword(sqliteData['password'].toString());
    }
    if (sqliteData['pin'] != null &&
        sqliteData['pin'].toString().isNotEmpty) {
      sqliteData['pin'] =
          SecurityHelper.hashPin(sqliteData['pin'].toString());
    }

    final res = await db.update(
      'users',
      sqliteData,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (FirebaseRealtimeListenerService.isApplyingCloudUpdate) return res;
    Future.microtask(() async {
      try {
        final userQuery =
            await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
        if (userQuery.isNotEmpty) {
          final u = userQuery.first;
          await FirebaseUserService.instance.updateUserInFirebase(
            uid: u['uid']?.toString(),
            email: u['email']?.toString(),
            username: u['username']?.toString(),
            updatedData: Map<String, dynamic>.from(u),
          );
        }
      } catch (e) {
        debugPrint(
            '[DatabaseHelper] Auto-sync updateUserFull ke Firebase gagal: $e');
      }
    });
    return res;
  }

  /// Menghapus akun pengguna dari database SQLite berdasarkan ID, UID, Email, atau Username
  Future<int> deleteUser(int id,
      {String? uid, String? email, String? username}) async {
    final db = await instance.database;
    String? finalUid = uid;
    String? finalEmail = email;
    String? finalUsername = username;
    try {
      final query = await db.query(
        'users',
        where:
            'id = ? OR (uid IS NOT NULL AND uid = ?) OR (email IS NOT NULL AND email = ?) OR (username IS NOT NULL AND username = ?)',
        whereArgs: [id, uid ?? '', email ?? '', username ?? ''],
        limit: 1,
      );
      if (query.isNotEmpty) {
        finalUid ??= query.first['uid']?.toString();
        finalEmail ??= query.first['email']?.toString();
        finalUsername ??= query.first['username']?.toString();
      }
    } catch (_) {}

    final res = await db.delete(
      'users',
      where:
          'id = ? OR (uid IS NOT NULL AND uid = ? AND uid != "") OR (email IS NOT NULL AND email = ? AND email != "") OR (username IS NOT NULL AND username = ? AND username != "")',
      whereArgs: [id, finalUid ?? '', finalEmail ?? '', finalUsername ?? ''],
    );

    Future.microtask(() async {
      try {
        await FirebaseUserService.instance.deleteUserFromFirebase(
          uid: finalUid,
          email: finalEmail,
          username: finalUsername,
        );
      } catch (e) {
        debugPrint(
            '[DatabaseHelper] Auto-sync deleteUser dari Firebase gagal: $e');
      }
    });
    return res;
  }

  /// Menambahkan akun pengguna/administrator baru langsung dari Portal Admin
  Future<int> addUser(Map<String, dynamic> data,
      {bool syncToCloud = true}) async {
    final db = await instance.database;
    await _ensureExtraColumns(db);
    final cleanData = Map<String, dynamic>.from(data);
    if (cleanData['password'] != null &&
        cleanData['password'].toString().isNotEmpty) {
      cleanData['password'] =
          SecurityHelper.hashPassword(cleanData['password'].toString());
    }
    if (cleanData['pin'] != null &&
        cleanData['pin'].toString().isNotEmpty) {
      cleanData['pin'] =
          SecurityHelper.hashPin(cleanData['pin'].toString());
    }
    final res = await db.insert('users', cleanData,
        conflictAlgorithm: ConflictAlgorithm.replace);

    if (syncToCloud && !FirebaseRealtimeListenerService.isApplyingCloudUpdate) {
      Future.microtask(() async {
        try {
          final dataToSync = Map<String, dynamic>.from(cleanData);
          await FirebaseUserService.instance.saveUserToFirebase(dataToSync);
        } catch (e) {
          debugPrint('[DatabaseHelper] Auto-sync addUser ke Firebase gagal: $e');
        }
      });
    }
    return res;
  }

  // --- FITUR UTAMA B: FULL CRUD TRANSAKSI & PESANAN ---
  Future<void> _ensureTransactionsColumns(Database db) async {
    if (_transactionsEnsured) return;
    _transactionsEnsured = true;
    try {
      await db
          .execute('ALTER TABLE transactions ADD COLUMN payment_method TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN invoice_no TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN notes TEXT;');
    } catch (_) {}
  }

  /// Membersihkan duplikasi transaksi pending dan menggabungkannya ke transaksi selesai
  Future<void> cleanupDuplicateTransactions() async {
    final db = await instance.database;
    await _ensureTransactionsColumns(db);
    try {
      await db.execute('''
        DELETE FROM transactions 
        WHERE (LOWER(status) LIKE '%pending%' OR LOWER(status) LIKE '%menunggu%')
        AND invoice_no IN (
          SELECT invoice_no FROM transactions 
          WHERE (LOWER(status) LIKE '%selesai%' OR LOWER(status) LIKE '%success%' OR LOWER(status) LIKE '%lunas%') 
          AND invoice_no IS NOT NULL AND TRIM(invoice_no) != ''
        )
      ''');
      await db.execute('''
        DELETE FROM transactions
        WHERE id NOT IN (
          SELECT MAX(id) FROM transactions WHERE invoice_no IS NOT NULL AND TRIM(invoice_no) != '' GROUP BY invoice_no
        )
        AND invoice_no IS NOT NULL AND TRIM(invoice_no) != ''
      ''');
    } catch (e) {
      debugPrint('Error cleaning up duplicate transactions: $e');
    }
  }

  Future<int> createTransaction(Map<String, dynamic> transactionData) async {
    final db = await instance.database;
    await _ensureTransactionsColumns(db);

    int resultId;
    final invoice = transactionData['invoice_no']?.toString();
    if (invoice != null && invoice.trim().isNotEmpty) {
      final existing = await db.query(
        'transactions',
        where: 'invoice_no = ?',
        whereArgs: [invoice.trim()],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final id = existing.first['id'] as int;
        await db.update(
          'transactions',
          transactionData,
          where: 'id = ?',
          whereArgs: [id],
        );
        resultId = id;
      } else {
        resultId = await db.insert('transactions', transactionData);
      }
    } else {
      resultId = await db.insert('transactions', transactionData);
    }

    // Otomatis sinkronkan & simpan ke Firebase (Realtime Database & Firestore) di latar belakang
    if (FirebaseRealtimeListenerService.isApplyingCloudUpdate) return resultId;
    Future.microtask(() async {
      try {
        final dataToSync = Map<String, dynamic>.from(transactionData);
        dataToSync['id'] = resultId;
        await FirebaseTransactionService.instance
            .saveTransactionToFirebase(dataToSync);
      } catch (e) {
        debugPrint(
            '[DatabaseHelper] Auto-sync transaksi ke Firebase gagal: $e');
      }
    });

    return resultId;
  }

  static List<Map<String, dynamic>> deduplicateTransactionsList(
      List<Map<String, dynamic>> list) {
    final Map<String, Map<String, dynamic>> uniqueByInvoice = {};
    final List<Map<String, dynamic>> withoutInvoice = [];

    for (final item in list) {
      final invoice = item['invoice_no']?.toString().trim();
      if (invoice == null || invoice.isEmpty) {
        withoutInvoice.add(item);
        continue;
      }
      if (!uniqueByInvoice.containsKey(invoice)) {
        uniqueByInvoice[invoice] = item;
      } else {
        final existingSt = (uniqueByInvoice[invoice]!['status'] ?? '')
            .toString()
            .toLowerCase();
        final currentSt = (item['status'] ?? '').toString().toLowerCase();

        final bool isCurrentFinished = currentSt.contains('selesai') ||
            currentSt.contains('success') ||
            currentSt.contains('settlement') ||
            currentSt.contains('lunas') ||
            currentSt.contains('berhasil');
        final bool isExistingFinished = existingSt.contains('selesai') ||
            existingSt.contains('success') ||
            existingSt.contains('settlement') ||
            existingSt.contains('lunas') ||
            existingSt.contains('berhasil');

        if (isCurrentFinished && !isExistingFinished) {
          uniqueByInvoice[invoice] = item;
        } else if (isCurrentFinished == isExistingFinished) {
          final int existingId =
              (uniqueByInvoice[invoice]!['id'] as num?)?.toInt() ?? 0;
          final int currentId = (item['id'] as num?)?.toInt() ?? 0;
          if (currentId > existingId) {
            uniqueByInvoice[invoice] = item;
          }
        }
      }
    }

    final result = [...uniqueByInvoice.values, ...withoutInvoice];
    result.sort((a, b) => ((b['id'] as num?)?.toInt() ?? 0)
        .compareTo((a['id'] as num?)?.toInt() ?? 0));
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await instance.database;
    await _ensureTransactionsColumns(db);
    await cleanupDuplicateTransactions();
    final raw = await db.query(
      'transactions',
      orderBy: 'id DESC',
    );
    return deduplicateTransactionsList(raw);
  }

  Future<List<Map<String, dynamic>>> getTransactionsByUser(String email) async {
    final db = await instance.database;
    await _ensureTransactionsColumns(db);
    await cleanupDuplicateTransactions();
    final raw = await db.query(
      'transactions',
      where: 'user_email = ?',
      whereArgs: [email],
      orderBy: 'id DESC',
    );
    return deduplicateTransactionsList(raw);
  }

  Future<Map<String, dynamic>?> getTransactionByInvoice(String invoiceNo) async {
    final db = await instance.database;
    final res = await db.query(
      'transactions',
      where: 'invoice_no = ?',
      whereArgs: [invoiceNo],
      limit: 1,
    );
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<int> getTotalOrdersCount(
    String email, {
    bool isAdmin = false,
    bool onlyProductPurchases = false,
  }) async {
    final transactions = isAdmin
        ? await getAllTransactions()
        : await getTransactionsByUser(email);

    if (onlyProductPurchases) {
      return transactions.where((tx) {
        final nama = (tx['nama_produk'] ?? '').toString();
        return !nama.contains('Top Up') && !nama.contains('Saldo');
      }).length;
    }

    return transactions.length;
  }

  Future<Map<String, dynamic>> getUserOrdersStats(String email,
      {bool isAdmin = false}) async {
    final db = await instance.database;
    await _ensureTransactionsColumns(db);
    await cleanupDuplicateTransactions();

    final List<Map<String, dynamic>> rawTx;
    if (isAdmin || email.isEmpty) {
      rawTx = await db.query('transactions', orderBy: 'id DESC');
    } else {
      rawTx = await db.query(
        'transactions',
        where: 'user_email = ?',
        whereArgs: [email],
        orderBy: 'id DESC',
      );
    }

    final txList = deduplicateTransactionsList(rawTx);

    int total = txList.length;
    int selesai = 0;
    int pending = 0;
    int diproses = 0;
    int dibatalkan = 0;
    double totalSpent = 0.0;

    for (final tx in txList) {
      final status = (tx['status'] ?? '').toString().toLowerCase();
      final totalHarga = (tx['total_harga'] as num?)?.toDouble() ?? 0.0;

      if (status.contains('selesai') ||
          status.contains('success') ||
          status.contains('settlement') ||
          status.contains('berhasil')) {
        selesai++;
        totalSpent += totalHarga;
      } else if (status.contains('pending') ||
          status.contains('menunggu') ||
          status.contains('unpaid')) {
        pending++;
      } else if (status.contains('proses') ||
          status.contains('diproses') ||
          status.contains('active')) {
        diproses++;
        totalSpent += totalHarga;
      } else if (status.contains('batal') ||
          status.contains('cancel') ||
          status.contains('expire') ||
          status.contains('deny')) {
        dibatalkan++;
      } else {
        pending++;
      }
    }

    return {
      'total': total,
      'selesai': selesai,
      'pending': pending,
      'diproses': diproses,
      'dibatalkan': dibatalkan,
      'totalSpent': totalSpent,
    };
  }

  Future<int> updateTransaction(
      int id, Map<String, dynamic> transactionData) async {
    final db = await instance.database;
    await _ensureTransactionsColumns(db);
    final count = await db.update('transactions', transactionData,
        where: 'id = ?', whereArgs: [id]);

    if (FirebaseRealtimeListenerService.isApplyingCloudUpdate) return count;

    // Sinkronkan data transaksi lengkap terbaru ke Firebase RTDB & Firestore
    try {
      final query = await db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final Map<String, dynamic> fullData = query.isNotEmpty
          ? Map<String, dynamic>.from(query.first)
          : Map<String, dynamic>.from(transactionData);

      final String? invoice = fullData['invoice_no']?.toString();
      final String? namaProduk = fullData['nama_produk']?.toString();
      final String? userEmail = fullData['user_email']?.toString();

      await FirebaseTransactionService.instance.updateTransactionInFirebase(
        invoiceNo: invoice,
        localId: id,
        namaProduk: namaProduk,
        userEmail: userEmail,
        updatedData: fullData,
      );
    } catch (e) {
      debugPrint(
          '[DatabaseHelper] Auto-sync update transaksi ke Firebase gagal: $e');
    }

    return count;
  }

  Future<int> deleteTransaction(int id, {String? invoiceNo}) async {
    final db = await instance.database;
    await _ensureTransactionsColumns(db);

    // Ambil detail lengkap sebelum dihapus untuk pencocokan Firebase RTDB yang 100% akurat
    String? inv = invoiceNo;
    String? namaProduk;
    String? userEmail;
    try {
      final existing = await db.query('transactions',
          where: 'id = ?', whereArgs: [id], limit: 1);
      if (existing.isNotEmpty) {
        inv ??= existing.first['invoice_no']?.toString();
        namaProduk = existing.first['nama_produk']?.toString();
        userEmail = existing.first['user_email']?.toString();
      }
    } catch (_) {}

    final count = (inv != null && inv.isNotEmpty)
        ? await db.delete(
            'transactions',
            where: 'id = ? OR invoice_no = ?',
            whereArgs: [id, inv],
          )
        : await db.delete(
            'transactions',
            where: 'id = ?',
            whereArgs: [id],
          );

    // Sinkronkan penghapusan ke Firebase RTDB & Firestore
    try {
      await FirebaseTransactionService.instance.deleteTransactionFromFirebase(
        invoiceNo: inv,
        localId: id,
        namaProduk: namaProduk,
        userEmail: userEmail,
      );
    } catch (e) {
      debugPrint(
          '[DatabaseHelper] Auto-sync hapus transaksi di Firebase gagal: $e');
    }

    return count;
  }

  Future<int> deleteTransactionByInvoice(String invoiceNo) async {
    final clean = invoiceNo.trim();
    if (clean.isEmpty) return 0;
    final db = await instance.database;
    await _ensureTransactionsColumns(db);

    int? localId;
    String? namaProduk;
    String? userEmail;
    try {
      final existing = await db.query('transactions',
          where: 'invoice_no = ? OR invoice_no = ?',
          whereArgs: [clean, clean.replaceAll('INV-', '')],
          limit: 1);
      if (existing.isNotEmpty) {
        localId = (existing.first['id'] as num?)?.toInt();
        namaProduk = existing.first['nama_produk']?.toString();
        userEmail = existing.first['user_email']?.toString();
      }
    } catch (_) {}

    final count = await db.delete(
      'transactions',
      where: 'invoice_no = ? OR invoice_no = ? OR id_ref = ?',
      whereArgs: [clean, clean.replaceAll('INV-', ''), clean],
    );

    try {
      await FirebaseTransactionService.instance.deleteTransactionFromFirebase(
        invoiceNo: clean,
        localId: localId,
        namaProduk: namaProduk,
        userEmail: userEmail,
      );
    } catch (e) {
      debugPrint(
          '[DatabaseHelper] Auto-sync hapus transaksi by invoice di Firebase: $e');
    }

    return count;
  }

  // --- FITUR UTAMA C: FULL CRUD DATA LAYANAN (VPS, PANEL HOSTING, BOT WHATSAPP) ---
  Future<int> createService(Map<String, dynamic> serviceData) async {
    final db = await instance.database;
    await _ensureServicesTable(db);
    final res = await db.insert('purchased_services', serviceData);
    if (FirebaseRealtimeListenerService.isApplyingCloudUpdate) return res;
    try {
      final syncData = Map<String, dynamic>.from(serviceData);
      syncData['id'] = res;
      await FirebaseTransactionService.instance.saveServiceToFirebase(syncData);
    } catch (e) {
      debugPrint('[DatabaseHelper] Auto-sync createService ke Firebase: $e');
    }
    return res;
  }

  Future<List<Map<String, dynamic>>> getAllServices() async {
    final db = await instance.database;
    await _ensureServicesTable(db);
    return await db.query('purchased_services', orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getServicesByUser(String email) async {
    final db = await instance.database;
    await _ensureServicesTable(db);
    return await db.query(
      'purchased_services',
      where: 'user_email = ?',
      whereArgs: [email],
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getServicesByCategory(
      String email, String kategori) async {
    final db = await instance.database;
    await _ensureServicesTable(db);
    return await db.query(
      'purchased_services',
      where: 'user_email = ? AND kategori = ?',
      whereArgs: [email, kategori],
      orderBy: 'id DESC',
    );
  }

  Future<int> updateService(int id, Map<String, dynamic> serviceData) async {
    final db = await instance.database;
    await _ensureServicesTable(db);
    final res = await db.update('purchased_services', serviceData,
        where: 'id = ?', whereArgs: [id]);
    if (FirebaseRealtimeListenerService.isApplyingCloudUpdate) return res;
    try {
      final existing = await db.query('purchased_services',
          where: 'id = ?', whereArgs: [id], limit: 1);
      final fullData = existing.isNotEmpty
          ? Map<String, dynamic>.from(existing.first)
          : Map<String, dynamic>.from(serviceData);
      fullData.addAll(serviceData);
      fullData['id'] = id;
      await FirebaseTransactionService.instance.saveServiceToFirebase(fullData);
    } catch (e) {
      debugPrint('[DatabaseHelper] Auto-sync updateService ke Firebase: $e');
    }
    return res;
  }

  Future<int> deleteService(int id) async {
    final db = await instance.database;
    await _ensureServicesTable(db);
    final res =
        await db.delete('purchased_services', where: 'id = ?', whereArgs: [id]);
    if (FirebaseRealtimeListenerService.isApplyingCloudUpdate) return res;
    try {
      await FirebaseTransactionService.instance.deleteServiceFromFirebase(id);
    } catch (e) {
      debugPrint('[DatabaseHelper] Auto-sync deleteService ke Firebase: $e');
    }
    return res;
  }

  Future<Map<String, int>> getServicesCountByCategory(String email) async {
    final db = await instance.database;
    await _ensureServicesTable(db);
    final vpsCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM purchased_services WHERE user_email = ? AND kategori LIKE "%VPS%"',
            [email])) ??
        0;
    final panelCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM purchased_services WHERE user_email = ? AND (kategori LIKE "%Panel%" OR kategori LIKE "%Hosting%")',
            [email])) ??
        0;
    final botCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM purchased_services WHERE user_email = ? AND (kategori LIKE "%Bot%" OR kategori LIKE "%WA%")',
            [email])) ??
        0;
    return {
      'VPS': vpsCount,
      'Panel': panelCount,
      'Bot WA': botCount,
      'Total': vpsCount + panelCount + botCount,
    };
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  // --- RIWAYAT LOGIN (LOGIN HISTORY) ---
  Future<int> insertLoginHistory(Map<String, dynamic> data) async {
    final db = await instance.database;
    await _ensureLoginHistoryTable(db);
    return await db.insert('login_history', data);
  }

  Future<List<Map<String, dynamic>>> getLoginHistory(
      {String? userEmail}) async {
    final db = await instance.database;
    await _ensureLoginHistoryTable(db);
    if (userEmail != null && userEmail.trim().isNotEmpty) {
      return await db.query(
        'login_history',
        where: 'user_email = ?',
        whereArgs: [userEmail.trim()],
        orderBy: 'id DESC',
      );
    }
    return await db.query('login_history', orderBy: 'id DESC');
  }

  // --- FITUR UTAMA E: INBOX NOTIFICATIONS (NOTIFIKASI & RIWAYAT EMAIL MASUK) ---
  Future<int> insertNotification(Map<String, dynamic> data) async {
    final db = await instance.database;
    await _ensureInboxNotificationsTable(db);
    return await db.insert('inbox_notifications', data);
  }

  Future<List<Map<String, dynamic>>> getNotificationsByUser(
    String userEmail, {
    String? category,
    bool unreadOnly = false,
  }) async {
    final db = await instance.database;
    await _ensureInboxNotificationsTable(db);

    String whereClause = 'user_email = ? OR user_email IS NULL';
    List<dynamic> whereArgs = [userEmail];

    if (category != null && category.isNotEmpty && category != 'Semua') {
      whereClause += ' AND category LIKE ?';
      whereArgs.add('%$category%');
    }

    if (unreadOnly) {
      whereClause += ' AND is_read = 0';
    }

    return await db.query(
      'inbox_notifications',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );
  }

  Future<int> markNotificationAsRead(int id) async {
    final db = await instance.database;
    await _ensureInboxNotificationsTable(db);
    return await db.update(
      'inbox_notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markAllNotificationsAsRead(String userEmail) async {
    final db = await instance.database;
    await _ensureInboxNotificationsTable(db);
    return await db.update(
      'inbox_notifications',
      {'is_read': 1},
      where: 'user_email = ? OR user_email IS NULL',
      whereArgs: [userEmail],
    );
  }

  Future<int> deleteNotification(int id) async {
    final db = await instance.database;
    await _ensureInboxNotificationsTable(db);
    return await db.delete(
      'inbox_notifications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearAllNotifications(String userEmail) async {
    final db = await instance.database;
    await _ensureInboxNotificationsTable(db);
    return await db.delete(
      'inbox_notifications',
      where: 'user_email = ? OR user_email IS NULL',
      whereArgs: [userEmail],
    );
  }

  // --- FITUR UTAMA F: SUPPORT TICKETS (TIKET PESAN BANTUAN) ---
  Future<int> createSupportTicket(Map<String, dynamic> data) async {
    final db = await instance.database;
    await _ensureSupportTicketsTable(db);
    return await db.insert('support_tickets', data);
  }

  Future<List<Map<String, dynamic>>> getSupportTickets(
      {String? userEmail}) async {
    final db = await instance.database;
    await _ensureSupportTicketsTable(db);
    if (userEmail != null && userEmail.trim().isNotEmpty) {
      return await db.query(
        'support_tickets',
        where: 'user_email = ?',
        whereArgs: [userEmail.trim()],
        orderBy: 'id DESC',
      );
    }
    return await db.query('support_tickets', orderBy: 'id DESC');
  }

  Future<int> updateSupportTicketStatus(int id, String status) async {
    final db = await instance.database;
    await _ensureSupportTicketsTable(db);
    return await db.update(
      'support_tickets',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getUsersCount() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM users')) ??
        0;
    return count;
  }

  // --- FITUR UTAMA D: FULL CRUD KONFIGURASI SERVER EMAIL (SMTP SETTINGS) ---
  /// Menyimpan atau memperbarui konfigurasi server email (SMTP) ke database SQLite secara permanen dan otomatis aktif
  Future<int> saveEmailSettings({
    required String smtpUser,
    required String smtpPass,
    String smtpHost = 'smtp.gmail.com',
    int smtpPort = 465,
    String? userEmail,
    bool syncToCloud = true,
  }) async {
    final db = await instance.database;
    await _ensureEmailSettingsTable(db);

    final cleanPass = smtpPass.replaceAll(' ', '').trim();
    final cleanUser = smtpUser.trim();
    final cleanHost = smtpHost.trim().isEmpty ? 'smtp.gmail.com' : smtpHost.trim();
    final timestamp = DateTime.now().toIso8601String();

    final data = <String, dynamic>{
      'user_email': userEmail?.trim(),
      'smtp_user': cleanUser,
      'smtp_pass': cleanPass,
      'smtp_host': cleanHost,
      'smtp_port': smtpPort,
      'is_active': 1,
      'updated_at': timestamp,
    };

    // 1. Simpan/Perbarui record untuk user_email spesifik (jika disediakan)
    int result = 0;
    if (userEmail != null && userEmail.trim().isNotEmpty) {
      final existing = await db.query(
        'email_settings',
        where: 'user_email = ?',
        whereArgs: [userEmail.trim()],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final id = existing.first['id'] as int;
        result = await db.update(
          'email_settings',
          data,
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        result = await db.insert('email_settings', data);
      }
    }

    // 2. Selalu simpan / perbarui juga ke record global (user_email IS NULL)
    // agar seluruh notifikasi sistem, invoice, dan transaksi otomatis selalu menggunakan konfigurasi aktif ini
    final globalData = Map<String, dynamic>.from(data);
    globalData['user_email'] = null;
    final globalExisting = await db.query(
      'email_settings',
      where: 'user_email IS NULL',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (globalExisting.isNotEmpty) {
      final globalId = globalExisting.first['id'] as int;
      final updateRes = await db.update(
        'email_settings',
        globalData,
        where: 'id = ?',
        whereArgs: [globalId],
      );
      if (result == 0) result = updateRes;
    } else {
      final insertRes = await db.insert('email_settings', globalData);
      if (result == 0) result = insertRes;
    }

    // 3. Simpan ke SharedPreferences secara instan sebagai runtime cache & redundansi permanen
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('smtp_user', cleanUser);
      await prefs.setString('smtp_pass', cleanPass);
      await prefs.setString('smtp_host', cleanHost);
      await prefs.setInt('smtp_port', smtpPort);
      await prefs.setBool('smtp_is_active', true);
      await prefs.setString('smtp_updated_at', timestamp);
    } catch (_) {}

    // 4. Sinkronkan secara otomatis ke Google Cloud Firestore & Firebase di latar belakang (Non-blocking)
    if (syncToCloud) {
      FirebaseEmailService.instance
          .saveEmailSettings(
            smtpUser: cleanUser,
            smtpPass: cleanPass,
            smtpHost: cleanHost,
            smtpPort: smtpPort,
            userEmail: userEmail,
          )
          .catchError((e) {
        debugPrint('[DatabaseHelper] Background sync email settings info: $e');
        return false;
      });
    }

    return result;
  }

  /// Mengambil data konfigurasi server email (SMTP) dari database SQLite secara cerdas
  Future<Map<String, dynamic>?> getEmailSettings({String? userEmail}) async {
    final db = await instance.database;
    await _ensureEmailSettingsTable(db);

    // 1. Cari berdasarkan user_email terlebih dahulu dengan sandi non-kosong
    if (userEmail != null && userEmail.trim().isNotEmpty) {
      final res = await db.query(
        'email_settings',
        where: 'user_email = ? AND smtp_pass IS NOT NULL AND smtp_pass != ""',
        whereArgs: [userEmail.trim()],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (res.isNotEmpty) return res.first;

      // Coba record apapun untuk user ini jika ada
      final anyUserRes = await db.query(
        'email_settings',
        where: 'user_email = ?',
        whereArgs: [userEmail.trim()],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (anyUserRes.isNotEmpty &&
          (anyUserRes.first['smtp_pass']?.toString().isNotEmpty ?? false)) {
        return anyUserRes.first;
      }
    }

    // 2. Cari setting global aktif (user_email IS NULL) dengan sandi non-kosong
    final globalSettings = await db.query(
      'email_settings',
      where: 'user_email IS NULL AND smtp_pass IS NOT NULL AND smtp_pass != ""',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (globalSettings.isNotEmpty) return globalSettings.first;

    // 3. Fallback: ambil konfigurasi email dengan sandi valid terbaru di database
    final activeAny = await db.query(
      'email_settings',
      where: 'smtp_pass IS NOT NULL AND smtp_pass != ""',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (activeAny.isNotEmpty) return activeAny.first;

    // 4. Fallback record terakhir di database
    final globalRes = await db.query(
      'email_settings',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (globalRes.isNotEmpty) return globalRes.first;

    // 5. Fallback ke SharedPreferences jika database belum termuat
    try {
      final prefs = await SharedPreferences.getInstance();
      final u = prefs.getString('smtp_user');
      final p = prefs.getString('smtp_pass');
      if (u != null && u.isNotEmpty && p != null && p.isNotEmpty) {
        return {
          'smtp_user': u,
          'smtp_pass': p,
          'smtp_host': prefs.getString('smtp_host') ?? 'smtp.gmail.com',
          'smtp_port': prefs.getInt('smtp_port') ?? 465,
          'is_active': 1,
          'updated_at': prefs.getString('smtp_updated_at') ??
              DateTime.now().toIso8601String(),
        };
      }
    } catch (_) {}

    return null;
  }

  /// Menghapus konfigurasi server email
  Future<int> deleteEmailSettings({String? userEmail}) async {
    final db = await instance.database;
    await _ensureEmailSettingsTable(db);
    if (userEmail != null && userEmail.trim().isNotEmpty) {
      return await db.delete(
        'email_settings',
        where: 'user_email = ?',
        whereArgs: [userEmail.trim()],
      );
    }
    return await db.delete('email_settings');
  }
}
