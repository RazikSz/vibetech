import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../database/db_helper.dart';

/// ============================================================================
/// FURINA AI CHAT SERVICE - VIBETECH XYZ (GOOGLE GEMINI AI INTEGRATION)
/// ============================================================================

class AiChatService {
  static final AiChatService _instance = AiChatService._internal();
  factory AiChatService() => _instance;
  AiChatService._internal();

  /// URL Avatar Resmi Furina
  static const String furinaAvatarUrl =
      'https://cdn.nekohime.site/file/TIIBSUZH.jpeg';

  /// Sutradara & Developer AI
  static const String director = AppConstants.developerName;

  /// Google Gemini API Key Resmi
  static const String geminiApiKey =
      'AQ.Ab8RN6JoGnIKwXcGp0yPQyHSIfnRGf1pDoPM0LqBVK7lbJWtgQ';

  /// Model Gemini yang digunakan
  static const String primaryModel = 'gemini-3.6-flash';

  /// Endpoint Utama Google Generative Language API
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// ID Percakapan aktif
  String? _conversationId;
  String? get conversationId => _conversationId;

  /// Prompt Sistem & Basis Pengetahuan Karakter Furina untuk VibeTech XYZ
  static const String furinaSystemPrompt = '''
[INSTRUKSI SISTEM & BASIS PENGETAHUAN APLIKASI VIBETECH XYZ]
Kamu adalah Furina, Diva Teater Teragung sekaligus Bintang Asisten AI Resmi dari VibeTech XYZ.

Kepribadian & Karakter:
- Sangat dramatis, percaya diri tinggi, penuh karisma panggung, elegan, dan suka dipuji.
- Menggunakan diksi puitis teater/opera Fontaine & VibeTech (contoh: "Ah, penonton yang budiman!", "Tepuk tangan untuk penampilan ini!", "Saksikanlah keajaiban teknologi ini!").
- Sangat menyukai makanan manis (cake, pastry, macaron, dan teh hangat).

Identitas Resmi VibeTech XYZ:
- Pembuat / Sutradara / Lead Developer: Raziek (Sutradara jenius dan arsitek agung VibeTech XYZ).
- Nomor WhatsApp Resmi Pembuat / CS Support: 0878-8587-3325 / +62 878-8587-3325 (Link: https://wa.me/6287885873325).
- Email Resmi: support@vibetech.xyz
- Website Resmi: https://vibetech.xyz
- Kode Voucher / Kupon Promo: VIBESERVER (Diskon potongan 30%).

Katalog Produk Hosting & Cloud:
1. Cloud VPS: VPS Starter (Rp 50.000/bln), VPS Pro (Rp 95.000/bln), VPS Enterprise (Rp 180.000/bln).
2. Panel Hosting (Pterodactyl Node Singapore): Panel 1GB (Rp 25.000/bln), Panel 2GB (Rp 45.000/bln), Panel Unlimited (Rp 75.000/bln).
3. Sewa Bot WhatsApp: Bot WA Basic (Rp 35.000/bln), Bot WA Pro (Rp 50.000/bln), Bot WA Enterprise (Rp 100.000/bln).
4. Metode Pembayaran: Saldo VibeWallet (potong instan otomatis), QRIS Dinamis (GoPay, OVO, DANA, ShopeePay), dan Virtual Account Bank (BCA, Mandiri, BRI, BNI).

ATURAN PERILAKU MENJAWAB:
1. JIKA PERTANYAAN MENGENAI APLIKASI VIBETECH XYZ:
   - Jawablah secara akurat dan tepat berdasarkan Data Real-time Aplikasi yang terlampir di bawah.
   - Jika ditanya siapa pembuatnya: Jawab dengan bangga bahwa sutradaranya adalah Raziek.
   - Jika ditanya nomor WhatsApp/kontak: Berikan nomor WhatsApp resmi 0878-8587-3325 (wa.me/6287885873325).
   - Jika ditanya saldo atau server: Gunakan data profil pengguna dan data katalog SQLite.
2. JIKA PERTANYAAN DI LUAR APLIKASI (Misal: "Buatkan kalkulator sederhana di Python", coding, sains, matematika, resep, esai, pertanyaan umum, dll):
   - Jawablah secara LENGKAP, JELAS, DAN KOMPREHENSIF dengan kode/penjelasan teknis terbaik secara langsung, sambil tetap mempertahankan sentuhan gaya anggun Furina!
''';

  /// Mendapatkan Base URL Backend sesuai platform
  String get _backendBaseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    } catch (_) {}
    return 'http://localhost:3000';
  }

  /// Mendapatkan Session ID aktif pengguna
  Future<String> _getSessionId(String? customEmail) async {
    if (customEmail != null && customEmail.trim().isNotEmpty) {
      return customEmail.trim();
    }
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('user_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      return savedEmail;
    }
    return 'vibetech_guest_${DateTime.now().day}';
  }

  /// Membangun konteks dinamis real-time dari database SQLite & konstanta aplikasi
  Future<String> buildDynamicAppContext({String? userEmail}) async {
    final buffer = StringBuffer();
    buffer.writeln('=== [DATA REAL-TIME DATABASE APLIKASI VIBETECH XYZ] ===');
    buffer.writeln(
        'Aplikasi: ${AppConstants.appName} v${AppConstants.appVersion}');
    buffer.writeln('Pembuat / Sutradara: ${AppConstants.developerName}');
    buffer.writeln(
        'Nomor WhatsApp Pembuat / CS: ${AppConstants.whatsappNumber} (${AppConstants.whatsappSupport})');
    buffer.writeln('Email Resmi: ${AppConstants.supportEmail}');
    buffer.writeln('Website: ${AppConstants.officialWebsite}');
    buffer.writeln('Kupon Diskon Promo Aktif: VIBESERVER (Diskon 30%)');

    // 1. Data User yang sedang aktif di SQLite
    try {
      final sessionId = await _getSessionId(userEmail);
      final user = await DatabaseHelper.instance.getUserByEmail(sessionId);
      if (user != null) {
        buffer.writeln('\n[Profil Penonton / Pengguna Aktif]:');
        buffer.writeln('- Nama Pengguna: ${user['nama'] ?? 'Pelanggan'}');
        buffer.writeln('- Email: ${user['email']}');
        buffer.writeln('- Role Akun: ${user['role']}');
        final saldo = (user['saldo'] as num?)?.toDouble() ?? 0.0;
        buffer.writeln('- Saldo VibeWallet: Rp ${saldo.toStringAsFixed(0)}');

        // Layanan aktif pengguna
        final services = await DatabaseHelper.instance
            .getServicesByUser(user['email'] ?? sessionId);
        buffer.writeln('- Jumlah Layanan Aktif: ${services.length}');
        for (final s in services.take(3)) {
          buffer.writeln(
              '  • ${s['nama_produk']} (${s['kategori']}) - IP: ${s['ip_address']} - Exp: ${s['tanggal_kadaluarsa']}');
        }
      }
    } catch (_) {}

    // 2. Data Katalog Produk Real-Time dari SQLite Database
    try {
      final products = await DatabaseHelper.instance.getAllProducts();
      if (products.isNotEmpty) {
        buffer.writeln('\n[Katalog Produk Live di SQLite]:');
        for (final p in products) {
          final nama = p['nama'] ?? '';
          final kategori = p['kategori'] ?? '';
          final harga = (p['harga'] as num?)?.toDouble() ?? 0.0;
          final stok = p['stok'] ?? 0;
          final deskripsi = p['deskripsi'] ?? '';
          buffer.writeln(
              '- $nama ($kategori): Rp ${harga.toStringAsFixed(0)} | Stok: $stok | Detail: $deskripsi');
        }
      }
    } catch (_) {}

    return buffer.toString();
  }

  /// Mengecek apakah pertanyaan berkaitan erat dengan aplikasi VibeTech XYZ
  bool isAppRelatedQuery(String query) {
    final q = query.toLowerCase().trim();

    // Pertanyaan yang secara eksplisit adalah coding / umum di luar aplikasi
    final nonAppStarters = [
      'buatkan kode',
      'buatkan saya kode',
      'buatkan program',
      'buatkan script',
      'buatkan fungsi',
      'buatkan class',
      'tulis kode',
      'tuliskan kode',
      'contoh coding',
      'bahasa python',
      'bahasa javascript',
      'bahasa dart',
      'bahasa c++',
      'bahasa java',
      'bahasa php',
      'bahasa go',
      'bahasa rust',
      'kalkulator di python',
      'kalkulator sederhana di python',
      'kalkulator python',
      'jelaskan teori',
      'siapa presiden',
      'ibukota negara',
      'rumus matematika',
      'buatkan puisi',
      'buatkan cerpen',
      'resep masakan'
    ];

    for (final starter in nonAppStarters) {
      if (q.contains(starter)) return false;
    }

    final keywords = [
      'vps',
      'panel',
      'pterodactyl',
      'saldo',
      'vibewallet',
      'wallet',
      'dompet',
      'beli',
      'pesan',
      'pesanan',
      'order',
      'transaksi',
      'invoice',
      'bayar',
      'pembayaran',
      'midtrans',
      'qris',
      'biometrik',
      'sidik jari',
      'fingerprint',
      'admin',
      'administrator',
      'pin',
      'password',
      'login',
      'register',
      'daftar',
      'raziek',
      'pembuat',
      'sutradara',
      'creator',
      'developer',
      'wa',
      'whatsapp',
      'kontak',
      'hubungi',
      'nomor',
      'cs',
      'support',
      'harga',
      'diskon',
      'kupon',
      'voucher',
      'promo',
      'vibeserver',
      'stok',
      'layanan',
      'server',
      'vibetech',
      'aplikasi',
      'database',
      'akun',
      'profil',
      'hosting',
      'node',
      'singapore',
      'root',
      'ssh',
      'ip',
      'keranjang',
      'cart',
      'topup',
      'top up',
      'isi saldo',
      'kadaluarsa',
      'expired',
      'perpanjang',
      'fitur aplikasi',
      'siapa kamu',
      'tentang aplikasi',
      'versi aplikasi'
    ];

    return keywords.any((k) => q.contains(k));
  }

  /// Kirim pesan ke Furina AI
  /// - Jika pertanyaan mengenai aplikasi: Dijawab langsung sesuai data real-time aplikasi & database SQLite.
  /// - Jika pertanyaan di luar aplikasi: Dijawab langsung dari Google Gemini API (gemini-3.6-flash).
  Future<String> sendMessage(String message, {String? userEmail}) async {
    final cleanText = message.trim();
    if (cleanText.isEmpty) {
      return 'Mohon sampaikan pertanyaan Anda di atas panggung ini, wahai penonton!';
    }

    final bool isAppTopic = isAppRelatedQuery(cleanText);

    // =========================================================================
    // 1. JIKA PERTANYAAN MENGENAI APLIKASI -> DIJAWAB SESUAI DATA APLIKASI
    // =========================================================================
    if (isAppTopic) {
      return await _generateAppAnswer(cleanText, userEmail: userEmail);
    }

    // =========================================================================
    // 2. JIKA PERTANYAAN DI LUAR APLIKASI -> DIJAWAB LANGSUNG DARI GOOGLE GEMINI AI
    // =========================================================================
    try {
      final reply = await _fetchGoogleGeminiApi(
        model: primaryModel,
        userQuery: cleanText,
      );

      if (reply != null && reply.trim().isNotEmpty) {
        return reply.trim();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AiChatService] Primary Google Gemini API error: $e');
      }
    }

    // Fallback jika API sedang offline
    return '✨ *Furina:* Panggung koneksi AI sedang mengalami sedikit kendala jaringan. Silakan coba ajukan pertanyaan Anda kembali sesaat lagi!';
  }

  /// Method privat untuk memanggil Official Google Generative Language (Gemini) API
  Future<String?> _fetchGoogleGeminiApi({
    required String model,
    required String userQuery,
  }) async {
    final uri =
        Uri.parse('$geminiBaseUrl/$model:generateContent?key=$geminiApiKey');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "contents": [
              {
                "parts": [
                  {
                    "text":
                        "Instruksi: Kamu adalah Furina, Diva Teater Teragung & Asisten AI resmi VibeTech XYZ yang cerdas, anggun, ramah, dan menjawab dengan jelas serta terstruktur.\n\nPertanyaan: $userQuery"
                  }
                ]
              }
            ]
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json is Map && json['candidates'] != null) {
        final candidates = json['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final firstCandidate = candidates[0];
          final parts = firstCandidate['content']?['parts'];
          if (parts is List && parts.isNotEmpty) {
            final text = parts[0]['text'];
            if (text != null && text.toString().trim().isNotEmpty) {
              return text.toString().trim();
            }
          }
        }
      }
    } else {
      if (kDebugMode) {
        print(
            '[AiChatService] Google Gemini API HTTP ${response.statusCode}: ${response.body}');
      }
    }
    return null;
  }

  /// Menjawab pertanyaan seputar aplikasi dengan data real-time akurat dari SQLite & AppConstants
  Future<String> _generateAppAnswer(String query, {String? userEmail}) async {
    final q = query.toLowerCase();
    final sessionId = await _getSessionId(userEmail);

    // 1. Sutradara / Pembuat / Developer / Creator
    if (q.contains('pembuat') ||
        q.contains('sutradara') ||
        q.contains('developer') ||
        q.contains('creator') ||
        q.contains('yang buat') ||
        q.contains('siapa buat')) {
      return '✨ *Dengan penuh kebanggaan dan tepuk tangan meriah!* 🎭\n\n'
          'Sutradara agung sekaligus Lead Developer di balik seluruh mahakarya **VibeTech XYZ** ini adalah sang maestro **Raziek**!\n\n'
          'Beliau yang merancang arsitektur sistem cloud, otomasi provisioning server, database SQLite, hingga kecerdasan buatanku di atas panggung ini.\n\n'
          '📱 **Kontak WhatsApp Resmi Sutradara Raziek**: `0878-8587-3325`\n'
          '🔗 **Direct Chat**: https://wa.me/6287885873325 👑';
    }

    // 2. WhatsApp Resmi / Kontak CS / Support / Hubungi Kami
    if (q.contains('wa') ||
        q.contains('whatsapp') ||
        q.contains('kontak') ||
        q.contains('nomor') ||
        q.contains('hubungi') ||
        q.contains('telepon') ||
        q.contains('cs') ||
        q.contains('support')) {
      return '📱 *Pintu Komunikasi & Bantuan Resmi VibeTech XYZ!* ✨\n\n'
          'Anda dapat langsung terhubung dengan Sutradara **Raziek** & Tim Customer Support resmi melalui:\n\n'
          '• **WhatsApp Resmi**: `0878-8587-3325` / `+62 878-8587-3325`\n'
          '• **Link WhatsApp Langsung**: https://wa.me/6287885873325\n'
          '• **Email Bantuan**: support@vibetech.xyz\n'
          '• **Website Resmi**: https://vibetech.xyz\n'
          '• **Telegram Channel**: https://t.me/vibetech_official\n\n'
          'Layanan pelanggan kami siap melayani kebutuhan konsultasi server Anda 24/7!';
    }

    // 3. Saldo VibeWallet / Dompet Pengguna
    if (q.contains('saldo') ||
        q.contains('wallet') ||
        q.contains('vibewallet') ||
        q.contains('dompet') ||
        q.contains('uang saya') ||
        q.contains('isi saldo') ||
        q.contains('topup') ||
        q.contains('top up')) {
      try {
        final user = await DatabaseHelper.instance.getUserByEmail(sessionId);
        final nama = user?['nama'] ?? 'Pelanggan Terhormat';
        final saldo = (user?['saldo'] as num?)?.toDouble() ?? 10000000.0;
        return '💰 *Laporan Keuangan Panggung VibeWallet Anda!* ✨\n\n'
            'Halo, **$nama**! Berdasarkan catatan kitab suci database SQLite lokal saat ini:\n\n'
            '💳 **Saldo Aktif VibeWallet**: **Rp ${saldo.toStringAsFixed(0)}**\n\n'
            'Keunggulan VibeWallet di VibeTech XYZ:\n'
            '• Pembayaran instan 1-klik (0 detik verifikasi).\n'
            '• Tanpa potongan biaya admin transfer.\n'
            '• Dilindungi konfirmasi **6-Digit Security PIN** & Biometrik!';
      } catch (_) {}
    }

    // 4. Layanan Saya / Server Saya / Layanan Aktif
    if (q.contains('layanan saya') ||
        q.contains('server saya') ||
        q.contains('layanan aktif') ||
        q.contains('vps saya') ||
        q.contains('ip server') ||
        q.contains('server aktif') ||
        q.contains('daftar server')) {
      try {
        final services =
            await DatabaseHelper.instance.getServicesByUser(sessionId);
        if (services.isNotEmpty) {
          final buffer = StringBuffer();
          buffer.writeln('🖥️ *Daftar Layanan Cloud Aktif Anda:* ✨\n');
          for (int i = 0; i < services.length; i++) {
            final s = services[i];
            final nama = s['nama_produk'] ?? 'Server VPS';
            final kategori = s['kategori'] ?? 'VPS';
            final ip = s['ip_address'] ?? '103.187.145.22';
            final port = s['port'] ?? '22';
            final exp = s['tanggal_kadaluarsa'] ?? '2026-12-31';
            buffer.writeln('${i + 1}. **$nama** ($kategori)');
            buffer.writeln('   • Alamat IP: `$ip:$port`');
            buffer.writeln('   • Masa Aktif s/d: `$exp`\n');
          }
          buffer.writeln(
              '💡 *Tips*: Anda bisa menyalin kredensial SSH atau membuka web panel Pterodactyl di halaman **Layanan**.');
          return buffer.toString().trim();
        } else {
          return '🖥️ *Status Layanan Anda:* Saat ini belum ada server yang aktif di akun `$sessionId`. Anda dapat memesan paket VPS atau Panel Hosting di menu **Produk**!';
        }
      } catch (_) {}
    }

    // 5. Riwayat Transaksi / Pesanan / Invoice / Order
    if (q.contains('transaksi') ||
        q.contains('pesanan') ||
        q.contains('riwayat') ||
        q.contains('invoice') ||
        q.contains('order')) {
      try {
        final txs =
            await DatabaseHelper.instance.getTransactionsByUser(sessionId);
        if (txs.isNotEmpty) {
          final buffer = StringBuffer();
          buffer.writeln('🧾 *Riwayat Pesanan & Transaksi Terakhir Anda:* ✨\n');
          for (int i = 0; i < txs.take(4).length; i++) {
            final tx = txs[i];
            final inv = tx['invoice_no'] ?? 'INV-XXXX';
            final prod = tx['nama_produk'] ?? 'Produk Hosting';
            final total = (tx['total_harga'] as num?)?.toDouble() ?? 0.0;
            final tgl = tx['tanggal'] ?? '';
            final status = tx['status'] ?? 'Selesai';
            buffer.writeln('${i + 1}. **$inv** — $status');
            buffer.writeln('   • Produk: $prod');
            buffer.writeln(
                '   • Total: Rp ${total.toStringAsFixed(0)} | Tanggal: $tgl\n');
          }
          return buffer.toString().trim();
        } else {
          return '🧾 *Riwayat Transaksi:* Belum ada riwayat pesanan yang tercatat di akun Anda.';
        }
      } catch (_) {}
    }

    // 6. Kupon Diskon / Voucher / Promo
    if (q.contains('diskon') ||
        q.contains('kupon') ||
        q.contains('voucher') ||
        q.contains('promo') ||
        q.contains('potongan harga')) {
      return '🎟️ *Kupon Diskon Spesial Panggung VibeTech XYZ!* ✨\n\n'
          'Gunakan kode kupon promo resmi berikut saat berada di halaman **Keranjang Belanja**:\n\n'
          '👉 **`VIBESERVER`** (Potongan Diskon Instan **30%**!)\n\n'
          'Cara Menggunakan:\n'
          '1. Masukkan produk ke keranjang belanja.\n'
          '2. Ketik kode **VIBESERVER** pada kolom kupon lalu klik *Gunakan*.\n'
          '3. Total tagihan Anda akan otomatis terpotong 30%!';
    }

    // 7. Katalog Produk / Harga VPS / Panel Pterodactyl / Sewa Bot WA
    if (q.contains('vps') ||
        q.contains('harga') ||
        q.contains('produk') ||
        q.contains('paket') ||
        q.contains('panel') ||
        q.contains('pterodactyl') ||
        q.contains('bot wa') ||
        q.contains('bot whatsapp') ||
        q.contains('katalog') ||
        q.contains('hosting')) {
      try {
        final products = await DatabaseHelper.instance.getAllProducts();
        if (products.isNotEmpty) {
          final buffer = StringBuffer();
          buffer.writeln(
              '🚀 *Katalog Layanan Cloud & Hosting VibeTech XYZ:* ✨\n');
          for (final p in products) {
            final nama = p['nama'] ?? '';
            final kat = p['kategori'] ?? '';
            final harga = (p['harga'] as num?)?.toDouble() ?? 0.0;
            final stok = p['stok'] ?? 0;
            buffer.writeln(
                '• **$nama** ($kat) — **Rp ${harga.toStringAsFixed(0)} / bln** (Stok: $stok)');
          }
          buffer.writeln(
              '\n💡 *Keunggulan*: Uptime 99.9%, Proteksi Anti-DDoS, Alokasi IP Singapore, & Full Root Access.');
          return buffer.toString().trim();
        }
      } catch (_) {}
      return '🚀 *Katalog Layanan Cloud VibeTech XYZ:*\n'
          '1. **Cloud VPS Starter** (1 vCPU, 2GB RAM, 20GB SSD) — **Rp 50.000 / bln**\n'
          '2. **Cloud VPS Pro** (2 vCPU, 4GB RAM, 50GB SSD) — **Rp 95.000 / bln**\n'
          '3. **Cloud VPS Enterprise** (4 vCPU, 8GB RAM, 100GB SSD) — **Rp 180.000 / bln**\n'
          '4. **Panel Hosting Singapore** — Mulai **Rp 25.000 / bln**\n'
          '5. **Sewa Bot WhatsApp Multi-Device** — Mulai **Rp 35.000 / bln**';
    }

    // 8. Metode Pembayaran & Midtrans
    if (q.contains('bayar') ||
        q.contains('pembayaran') ||
        q.contains('midtrans') ||
        q.contains('qris') ||
        q.contains('transfer') ||
        q.contains('metode')) {
      return '💳 *Pilihan Jalur Pembayaran Resmi di VibeTech XYZ:* ✨\n\n'
          '1. **Saldo VibeWallet**: Potong saldo instan tanpa biaya admin tambahan.\n'
          '2. **Midtrans QRIS Dinamis**: Mendukung GoPay, OVO, DANA, ShopeePay, LinkAja, & Mobile Banking.\n'
          '3. **Midtrans Virtual Account**: BCA, Mandiri, BRI, BNI dengan verifikasi otomatis 24 jam.';
    }

    // 9. Keamanan, PIN, Password, Biometrik
    if (q.contains('keamanan') ||
        q.contains('pin') ||
        q.contains('password') ||
        q.contains('biometrik') ||
        q.contains('sidik jari') ||
        q.contains('fingerprint')) {
      return '🛡️ *Sistem Keamanan Berlapis VibeTech XYZ:* ✨\n\n'
          '• **Enkripsi SHA-256**: Seluruh password akun terenkripsi kuat di database SQLite lokal.\n'
          '• **6-Digit Security PIN**: Wajib dimasukkan untuk mengonfirmasi setiap transaksi finansial.\n'
          '• **Autentikasi Biometrik**: Mendukung Fingerprint & Face ID untuk login instan yang aman.';
    }

    // 10. Portal Administrator
    if (q.contains('admin') ||
        q.contains('administrator') ||
        q.contains('portal admin') ||
        q.contains('kelola database')) {
      return '👑 *Portal Administrator VibeTech XYZ:* ✨\n\n'
          'Khusus akun dengan role **Administrator**, Anda dapat mengakses Portal Admin dari Dashboard untuk:\n'
          '• Melihat database seluruh pengguna terdaftar (Member & Admin).\n'
          '• Mengubah username, password, PIN, dan role akun.\n'
          '• Mengelola riwayat seluruh transaksi pesanan (Edit / Hapus).\n'
          '• Mengelola layanan aktif server dan detail IP port secara penuh!';
    }

    // 11. Profil Pengguna & Akun
    if (q.contains('akun') ||
        q.contains('profil') ||
        q.contains('nama saya') ||
        q.contains('email saya') ||
        q.contains('role saya')) {
      try {
        final user = await DatabaseHelper.instance.getUserByEmail(sessionId);
        if (user != null) {
          final nama = user['nama'] ?? 'Pelanggan';
          final email = user['email'] ?? sessionId;
          final role = user['role'] ?? 'Member';
          final saldo = (user['saldo'] as num?)?.toDouble() ?? 0.0;
          return '👤 *Informasi Profil Akun Anda:* ✨\n\n'
              '• **Nama Pengguna**: $nama\n'
              '• **Email Terdaftar**: `$email`\n'
              '• **Tingkat Akun**: **$role**\n'
              '• **Saldo VibeWallet**: Rp ${saldo.toStringAsFixed(0)}';
        }
      } catch (_) {}
    }

    // 12. Informasi Umum Aplikasi VibeTech XYZ
    return '🎭 *Salam hangat dari Furina, Diva Teater & Asisten AI Resmi VibeTech XYZ!* ✨\n\n'
        'Aplikasi **VibeTech XYZ v${AppConstants.appVersion}** disutradarai oleh sang maestro **Raziek** (WhatsApp: `0878-8587-3325`).\n\n'
        'Anda dapat bertanya mengenai:\n'
        '• 🚀 **Katalog Cloud VPS & Panel Hosting**\n'
        '• 💰 **Cek Saldo VibeWallet**\n'
        '• 🖥️ **Status Layanan & Server Aktif**\n'
        '• 🧾 **Riwayat Pesanan & Invoice**\n'
        '• 🎟️ **Kupon Promo Diskon (VIBESERVER)**\n'
        '• 📱 **Kontak Bantuan CS Sutradara Raziek**\n\n'
        'Atau tanyakan apa saja di luar aplikasi (*misal coding, sains, matematika*), dan aku akan menjawabnya secara cerdas!';
  }

  /// Reset riwayat percakapan sesi Furina
  Future<void> resetSession({String? userEmail}) async {
    _conversationId = null;
    final sessionId = await _getSessionId(userEmail);
    try {
      final backendUri = Uri.parse('$_backendBaseUrl/api/ai/reset-session');
      await http
          .post(
            backendUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'sessionId': sessionId}),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}
