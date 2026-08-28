import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/database/db_helper.dart';

/// ============================================================================
/// LAYANAN MULTI-BAHASA (LANGUAGE & LOCALIZATION SERVICE) - VIBETECH XYZ
/// ============================================================================
/// Layanan global untuk menangani lokalisasi antarmuka dua bahasa (ID / EN):
/// 1. Berbasis [ValueNotifier<String>] untuk perubahan bahasa instan tanpa restart aplikasi.
/// 2. Menyimpan preferensi bahasa ke [SharedPreferences] dan database SQLite pengguna.
/// 3. Dilengkapi kamus terjemahan lengkap ([translations]) dan helper function [tr()] & [text()].
class LanguageService {
  /// Notifier bahasa aktif saat ini ('Indonesia' atau 'English')
  static final ValueNotifier<String> languageNotifier =
      ValueNotifier<String>('Indonesia');

  /// Mengambil nama bahasa aktif
  static String get currentLanguage => languageNotifier.value;

  /// Memeriksa apakah mode bahasa Inggris sedang aktif
  static bool get isEnglish =>
      languageNotifier.value == 'English' || languageNotifier.value == 'en';

  /// Memuat preferensi bahasa yang tersimpan di SharedPreferences
  static Future<void> initLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('app_language') ?? 'Indonesia';
      languageNotifier.value = savedLang;
    } catch (e) {
      debugPrint('Error initializing language: $e');
    }
  }

  /// Mengubah bahasa aktif dan menyimpannya ke SharedPreferences serta SQLite
  static Future<void> setLanguage(String langKey, {String? username}) async {
    languageNotifier.value = langKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', langKey);
      if (username != null && username.isNotEmpty) {
        await DatabaseHelper.instance.updateUserLanguage(username, langKey);
      }
    } catch (e) {
      debugPrint('Error saving language: $e');
    }
  }

  /// Utility untuk langsung memilih teks secara inline berdasarkan bahasa yang aktif
  static String text(String idText, String enText) {
    return isEnglish ? enText : idText;
  }

  /// Kamus Terjemahan Global (Dictionary) per kunci lokalisasi
  static final Map<String, Map<String, String>> translations = {
    // General / Common
    'app_title': {'id': 'VibeTech XYZ', 'en': 'VibeTech XYZ'},
    'beranda': {'id': 'Beranda', 'en': 'Home'},
    'produk': {'id': 'Produk', 'en': 'Products'},
    'keranjang': {'id': 'Keranjang', 'en': 'Cart'},
    'profil': {'id': 'Profil', 'en': 'Profile'},
    'batal': {'id': 'Batal', 'en': 'Cancel'},
    'simpan': {'id': 'Simpan', 'en': 'Save'},
    'hapus': {'id': 'Hapus', 'en': 'Delete'},
    'keluar': {'id': 'Keluar', 'en': 'Logout'},
    'aktif': {'id': 'Aktif', 'en': 'Active'},
    'nonaktif': {'id': 'Nonaktif', 'en': 'Disabled'},
    'berhasil': {'id': 'Berhasil', 'en': 'Success'},
    'pending': {'id': 'Pending', 'en': 'Pending'},
    'gagal': {'id': 'Gagal', 'en': 'Failed'},
    'kembali': {'id': 'Kembali', 'en': 'Back'},
    'tutup': {'id': 'Tutup', 'en': 'Close'},
    'konfirmasi': {'id': 'Konfirmasi', 'en': 'Confirm'},

    // Profile Page
    'profil_saya': {'id': 'Profil Saya', 'en': 'My Profile'},
    'informasi_akun': {'id': 'Informasi Akun', 'en': 'Account Information'},
    'nama_lengkap': {'id': 'Nama Lengkap', 'en': 'Full Name'},
    'email': {'id': 'Email', 'en': 'Email'},
    'no_telepon': {'id': 'No. Telepon', 'en': 'Phone Number'},
    'lokasi': {'id': 'Lokasi', 'en': 'Location'},
    'pengaturan': {'id': 'Pengaturan', 'en': 'Settings'},
    'edit_profil': {'id': 'Edit Profil', 'en': 'Edit Profile'},
    'ubah_password': {'id': 'Ubah Password', 'en': 'Change Password'},
    '2fa_keamanan': {'id': '2FA Keamanan', 'en': '2FA Security'},
    'bahasa': {'id': 'Bahasa', 'en': 'Language'},
    'pilih_bahasa': {'id': 'Pilih Bahasa', 'en': 'Select Language'},
    'notifikasi': {'id': 'Notifikasi', 'en': 'Notifications'},
    'push_notification': {'id': 'Push Notification', 'en': 'Push Notification'},
    'email_notification': {
      'id': 'Email Notification',
      'en': 'Email Notification'
    },
    'lainnya': {'id': 'Lainnya', 'en': 'Others'},
    'pusat_bantuan': {'id': 'Pusat Bantuan', 'en': 'Help Center'},
    'tentang_aplikasi': {'id': 'Tentang Aplikasi', 'en': 'About Application'},
    'beri_rating': {'id': 'Beri Rating', 'en': 'Rate Us'},
    'kebijakan_privasi': {'id': 'Kebijakan Privasi', 'en': 'Privacy Policy'},
    'keluar_dari_akun': {'id': 'Keluar dari Akun', 'en': 'Logout Account'},
    'member_premium': {'id': 'Member Premium', 'en': 'Premium Member'},
    'pesanan': {'id': 'Pesanan', 'en': 'Orders'},
    'layanan': {'id': 'Layanan', 'en': 'Services'},
    'transaksi': {'id': 'Transaksi', 'en': 'Transactions'},
    'password_saat_ini': {'id': 'Password Saat Ini', 'en': 'Current Password'},
    'password_baru': {'id': 'Password Baru', 'en': 'New Password'},
    'konfirmasi_password_baru': {
      'id': 'Konfirmasi Password Baru',
      'en': 'Confirm New Password'
    },
    'url_foto_profil': {'id': 'URL Foto Profil', 'en': 'Profile Photo URL'},
    'konfirmasi_keluar': {
      'id': 'Konfirmasi Keluar',
      'en': 'Logout Confirmation'
    },
    'yakin_keluar': {
      'id': 'Apakah Anda yakin ingin keluar dari akun?',
      'en': 'Are you sure you want to log out of your account?'
    },
    'bahasa_diubah': {
      'id': 'Bahasa diubah ke Bahasa Indonesia',
      'en': 'Language changed to English'
    },

    // Dashboard Page
    'dashboard_utama': {'id': 'Dashboard Utama', 'en': 'Main Dashboard'},
    'halo': {'id': 'Halo,', 'en': 'Hello,'},
    'selamat_datang_kembali': {
      'id': 'Selamat datang kembali di VibeTech XYZ',
      'en': 'Welcome back to VibeTech XYZ'
    },
    'ringkasan_layanan': {'id': 'Ringkasan Layanan', 'en': 'Services Overview'},
    'layanan_aktif': {'id': 'Layanan Aktif', 'en': 'Active Services'},
    'lihat_detail': {'id': 'Lihat Detail', 'en': 'View Details'},
    'belanja_layanan_baru': {
      'id': 'Belanja Layanan Baru',
      'en': 'Shop New Services'
    },
    'metode_pembayaran_billing': {
      'id': 'Metode Pembayaran & Billing',
      'en': 'Payment Methods & Billing'
    },
    'bantuan_dukungan': {'id': 'Bantuan & Dukungan', 'en': 'Help & Support'},
    'cari_layanan': {'id': 'Cari layanan...', 'en': 'Search services...'},
    'top_up_saldo': {'id': 'Top Up Saldo', 'en': 'Top Up Balance'},
    'beli_sekarang': {'id': 'Beli Sekarang', 'en': 'Buy Now'},
    'status': {'id': 'Status', 'en': 'Status'},
    'kadaluarsa': {'id': 'Kadaluarsa', 'en': 'Expiry'},
    'spesifikasi': {'id': 'Spesifikasi', 'en': 'Specifications'},
    'harga': {'id': 'Harga', 'en': 'Price'},
    'saldo_anda': {'id': 'Saldo VibeWallet', 'en': 'VibeWallet Balance'},
    'member_pro': {'id': 'Member Pro', 'en': 'Member Pro'},
    'promo_spesial': {
      'id': 'Promo Spesial Cloud VPS',
      'en': 'Special Cloud VPS Promo'
    },
    'kode_promo': {
      'id': 'Gunakan Kode Promo: VIBESERVER',
      'en': 'Use Promo Code: VIBESERVER'
    },

    // Products Page
    'katalog_produk': {
      'id': 'Katalog Produk & Layanan',
      'en': 'Product & Service Catalog'
    },
    'cari_produk': {
      'id': 'Cari VPS, Panel Hosting, Bot WA...',
      'en': 'Search VPS, Hosting Panel, WA Bot...'
    },
    'semua': {'id': 'Semua', 'en': 'All'},
    'kategori': {'id': 'Kategori', 'en': 'Categories'},
    'beli_produk': {'id': 'Beli Produk', 'en': 'Buy Product'},
    'detail_produk': {'id': 'Detail Produk', 'en': 'Product Details'},
    'sewa_sekarang': {'id': 'Sewa Sekarang', 'en': 'Rent Now'},
    'tambah_ke_keranjang': {'id': 'Tambah ke Keranjang', 'en': 'Add to Cart'},
    'stok_tersedia': {'id': 'Stok Tersedia', 'en': 'Stock Available'},
    'habis': {'id': 'Habis', 'en': 'Out of Stock'},
    'durasi_sewa': {'id': 'Durasi Sewa', 'en': 'Rental Duration'},
    'bulan': {'id': 'Bulan', 'en': 'Month(s)'},
    'total_harga': {'id': 'Total Harga', 'en': 'Total Price'},
    'pesan_sekarang': {'id': 'Pesan Sekarang', 'en': 'Order Now'},
    'manajemen_produk': {
      'id': 'Manajemen Produk (Admin)',
      'en': 'Product Management (Admin)'
    },
    'tambah_produk_baru': {'id': 'Tambah Produk Baru', 'en': 'Add New Product'},

    // Cart Page
    'keranjang_belanja': {'id': 'Keranjang Belanja', 'en': 'Shopping Cart'},
    'keranjang_kosong': {
      'id': 'Keranjang Anda Kosong',
      'en': 'Your Cart is Empty'
    },
    'belum_ada_produk': {
      'id': 'Belum ada produk yang ditambahkan.',
      'en': 'No products added yet.'
    },
    'mulai_belanja': {'id': 'Mulai Belanja', 'en': 'Start Shopping'},
    'ringkasan_belanja': {'id': 'Ringkasan Belanja', 'en': 'Shopping Summary'},
    'total_pembayaran': {'id': 'Total Pembayaran', 'en': 'Total Payment'},
    'lanjut_pembayaran': {
      'id': 'Lanjut ke Pembayaran',
      'en': 'Proceed to Payment'
    },
    'hapus_semua': {'id': 'Hapus Semua', 'en': 'Clear All'},
    'item': {'id': 'Item', 'en': 'Item(s)'},
    'item_ditambahkan': {
      'id': 'Item berhasil ditambahkan ke keranjang!',
      'en': 'Item successfully added to cart!'
    },

    // Auth Pages
    'selamat_datang': {'id': 'Selamat Datang', 'en': 'Welcome'},
    'masuk_ke_akun': {
      'id': 'Masuk ke Akun Anda',
      'en': 'Log in to your account'
    },
    'username_email': {'id': 'Username / Email', 'en': 'Username / Email'},
    'password': {'id': 'Password', 'en': 'Password'},
    'lupa_password': {'id': 'Lupa Password?', 'en': 'Forgot Password?'},
    'masuk': {'id': 'Masuk', 'en': 'Log In'},
    'belum_punya_akun': {
      'id': 'Belum punya akun?',
      'en': "Don't have an account?"
    },
    'daftar_sekarang': {'id': 'Daftar Sekarang', 'en': 'Register Now'},
    'atau_masuk_dengan': {'id': 'atau masuk dengan', 'en': 'or log in with'},
    'buat_akun_baru': {'id': 'Buat Akun Baru', 'en': 'Create New Account'},
    'daftar_layanan': {
      'id': 'Daftar untuk memulai layanan VibeTech',
      'en': 'Register to start VibeTech services'
    },
    'username': {'id': 'Username', 'en': 'Username'},
    'konfirmasi_password': {
      'id': 'Konfirmasi Password',
      'en': 'Confirm Password'
    },
    'daftar': {'id': 'Daftar', 'en': 'Register'},
    'sudah_punya_akun': {
      'id': 'Sudah punya akun?',
      'en': 'Already have an account?'
    },
    'masuk_di_sini': {'id': 'Masuk di sini', 'en': 'Log in here'},
    'reset_password': {'id': 'Reset Password', 'en': 'Reset Password'},
    'masukkan_email_reset': {
      'id': 'Masukkan email Anda untuk mereset password',
      'en': 'Enter your email to reset password'
    },
    'kirim_instruksi': {
      'id': 'Kirim Instruksi Reset',
      'en': 'Send Reset Instructions'
    },
    'kembali_ke_login': {'id': 'Kembali ke Login', 'en': 'Back to Login'},
    'login_biometrik': {'id': 'Login Biometrik', 'en': 'Biometric Login'},

    // Payment & Billing
    'tagihan_billing': {'id': 'Tagihan & Billing', 'en': 'Billing & Invoices'},
    'halaman_pembayaran': {'id': 'Halaman Pembayaran', 'en': 'Payment Page'},
    'pembayaran': {'id': 'Pembayaran', 'en': 'Payment'},
    'pilih_metode_pembayaran': {
      'id': 'Pilih Metode Pembayaran',
      'en': 'Select Payment Method'
    },
    'bayar_sekarang': {'id': 'Bayar Sekarang', 'en': 'Pay Now'},
    'verifikasi': {'id': 'Verifikasi', 'en': 'Verify'},
    'pembayaran_selesai': {
      'id': 'Pembayaran Selesai',
      'en': 'Payment Complete'
    },
    'menunggu_pembayaran': {
      'id': 'Menunggu Pembayaran',
      'en': 'Awaiting Payment'
    },
    'invoice': {'id': 'Nomor Invoice', 'en': 'Invoice Number'},
    'subtotal': {'id': 'Subtotal', 'en': 'Subtotal'},
    'biaya_admin': {'id': 'Biaya Admin', 'en': 'Admin Fee'},
    'gratis': {'id': 'Gratis (Rp 0)', 'en': 'Free (Rp 0)'},
    'countdown_bayar': {
      'id': 'Selesaikan pembayaran dalam:',
      'en': 'Complete payment in:'
    },
    'struk_digital': {
      'id': 'Struk Bukti Pembayaran Digital',
      'en': 'Digital Payment Receipt'
    },
    'saldo_tidak_cukup': {
      'id': 'Saldo VibeWallet tidak mencukupi!',
      'en': 'Insufficient VibeWallet balance!'
    },

    // Top Up Page
    'topup_title': {
      'id': 'Top Up Saldo VibeWallet',
      'en': 'Top Up VibeWallet Balance'
    },
    'pilih_nominal': {
      'id': 'Pilih Nominal Deposit',
      'en': 'Select Deposit Amount'
    },
    'nominal_kustom': {'id': 'Nominal Kustom (Rp)', 'en': 'Custom Amount (Rp)'},
    'metode_deposit': {'id': 'Metode Deposit', 'en': 'Deposit Method'},
    'topup_berhasil': {
      'id': 'Top Up Saldo Berhasil!',
      'en': 'Top Up Successful!'
    },
    'saldo_ditambahkan': {
      'id': 'Saldo berhasil ditambahkan ke akun Anda.',
      'en': 'Balance successfully credited to your account.'
    },

    // Support & Notification
    'live_chat': {'id': 'Live Chat Dukungan', 'en': 'Support Live Chat'},
    'hubungi_kami': {'id': 'Hubungi Kami', 'en': 'Contact Us'},
    'pesan': {'id': 'Pesan', 'en': 'Messages'},
    'ketik_pesan': {'id': 'Ketik pesan...', 'en': 'Type a message...'},
    'kirim': {'id': 'Kirim', 'en': 'Send'},
    'furina_title': {
      'id': 'Furina AI Theatrical Assistant',
      'en': 'Furina AI Theatrical Assistant'
    },
    'furina_subtitle': {
      'id': 'Online • Disutradarai oleh Raziek',
      'en': 'Online • Directed by Raziek'
    },
    'tanya_furina': {
      'id': 'Tanyakan sesuatu pada Furina AI...',
      'en': 'Ask something to Furina AI...'
    },
    'reset_sesi': {'id': 'Reset Sesi Chat', 'en': 'Reset Chat Session'},
    'saran_pertanyaan': {
      'id': 'Saran Pertanyaan Panggung:',
      'en': 'Stage Prompt Suggestions:'
    },

    // Data Layanan / Server Manager
    'data_layanan': {'id': 'Data Layanan', 'en': 'My Services'},
    'data_vps': {'id': 'Data VPS', 'en': 'VPS Data'},
    'panel_hosting': {'id': 'Panel Hosting', 'en': 'Hosting Panel'},
    'bot_whatsapp': {'id': 'Bot WhatsApp', 'en': 'WhatsApp Bot'},
    'kredensial_akses': {
      'id': 'Kredensial & Akses',
      'en': 'Credentials & Access'
    },
    'salin_ip': {'id': 'Salin IP', 'en': 'Copy IP'},
    'salin_password': {'id': 'Salin Password', 'en': 'Copy Password'},
    'salin_ssh': {'id': 'Salin Perintah SSH', 'en': 'Copy SSH Command'},
    'salin_berhasil': {
      'id': 'Berhasil disalin ke clipboard!',
      'en': 'Copied to clipboard!'
    },
    'tambah_layanan': {'id': 'Tambah Layanan', 'en': 'Add Service'},
    'detail_layanan': {'id': 'Detail Layanan', 'en': 'Service Details'},
    'kelola_layanan': {'id': 'Kelola Layanan', 'en': 'Manage Service'},
    'masa_aktif': {'id': 'Masa Aktif', 'en': 'Active Period'},
    'kadaluarsa_pada': {'id': 'Kadaluarsa pada', 'en': 'Expires on'},
    'sisa_hari': {'id': 'hari lagi', 'en': 'days left'},
    'perpanjang_layanan': {
      'id': 'Perpanjang Layanan (+30 Hari)',
      'en': 'Extend Service (+30 Days)'
    },
    'perpanjang_sukses': {
      'id': 'Layanan berhasil diperpanjang 30 hari!',
      'en': 'Service successfully extended by 30 days!'
    },
    'buka_panel': {
      'id': 'Buka Web Panel Pterodactyl',
      'en': 'Open Pterodactyl Web Panel'
    },
    'scan_qr_wa': {
      'id': 'Pindai QR Code WhatsApp Web',
      'en': 'Scan WhatsApp Web QR Code'
    },
    'pairing_code': {
      'id': 'Pairing Code 8-Digit',
      'en': '8-Digit Pairing Code'
    },
    'session_id': {'id': 'Session ID', 'en': 'Session ID'},
    'server_online': {'id': 'ONLINE 99.9% UPTIME', 'en': 'ONLINE 99.9% UPTIME'},

    // Total Pesanan / Orders
    'total_pesanan': {'id': 'Total Pesanan', 'en': 'Total Orders'},
    'semua_pesanan': {'id': 'Semua Pesanan', 'en': 'All Orders'},
    'filter_status': {'id': 'Filter Status', 'en': 'Filter Status'},
    'selesai': {'id': 'Selesai', 'en': 'Completed'},
    'diproses': {'id': 'Diproses', 'en': 'Processing'},
    'dibatalkan': {'id': 'Dibatalkan', 'en': 'Cancelled'},
    'cetak_invoice': {
      'id': 'Cetak Struk / Invoice',
      'en': 'Print Receipt / Invoice'
    },
    'salin_invoice': {'id': 'Salin Nomor Invoice', 'en': 'Copy Invoice Number'},

    // Portal Administrator & Database Pengguna
    'portal_admin': {
      'id': 'Portal Administrator',
      'en': 'Administrator Portal'
    },
    'database_pengguna': {'id': 'Database Pengguna', 'en': 'User Database'},
    'kelola_database': {'id': 'Kelola Database', 'en': 'Manage Database'},
    'daftar_pengguna': {
      'id': 'Daftar Pengguna & Admin',
      'en': 'Users & Admins List'
    },
    'edit_pengguna': {'id': 'Edit Pengguna', 'en': 'Edit User'},
    'tambah_pengguna': {'id': 'Tambah Pengguna', 'en': 'Add User'},
    'pin_transaksi': {
      'id': 'PIN Transaksi (6-Digit)',
      'en': 'Transaction PIN (6-Digit)'
    },
    'riwayat_pembelian_user': {
      'id': 'Riwayat Pembelian Pengguna',
      'en': 'User Purchase History'
    },
    'semua_role': {'id': 'Semua Akun', 'en': 'All Accounts'},
    'role_member': {'id': 'Member', 'en': 'Member'},
    'role_admin': {'id': 'Administrator', 'en': 'Administrator'},
  };

  static String tr(String key) {
    if (translations.containsKey(key)) {
      final map = translations[key]!;
      return isEnglish ? (map['en'] ?? key) : (map['id'] ?? key);
    }
    return key;
  }
}
