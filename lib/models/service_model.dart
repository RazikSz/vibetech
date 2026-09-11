/// ============================================================================
/// MODEL LAYANAN AKTIF PENGGUNA (PURCHASED SERVICE MODEL) - VIBETECH XYZ
/// ============================================================================
/// Model yang merepresentasikan data server dan instance aktif milik pengguna:
/// 1. Cloud VPS: IP Public, SSH Port 22, User Root, Encrypted Password.
/// 2. Panel Hosting: Pterodactyl URL, Akun Akses, Node Resource.
/// 3. Bot WhatsApp: Session ID, Pairing Code 8 Digit, Status WhatsApp Web.
class PurchasedService {
  /// ID Unik auto-increment tabel 'purchased_services'
  final int? id;

  /// Email akun pemilik layanan
  final String userEmail;

  /// Nama paket layanan (contoh: "VPS Starter (Ubuntu 22.04)")
  final String namaProduk;

  /// Kategori layanan: 'VPS', 'Panel Hosting', 'Bot WhatsApp'
  final String kategori;

  /// Nominal harga pembelian dalam Rupiah
  final double harga;

  /// Tanggal transaksi pembelian (Format ISO8601)
  final String tanggalBeli;

  /// Tanggal masa aktif berakhir (Format ISO8601)
  final String tanggalKadaluarsa;

  /// Status layanan: 'Aktif', 'Expired', 'Maintenance', 'Pending'
  final String status;

  // --- Kredensial Khusus VPS / Panel ---
  final String? ipAddress;
  final String? port;
  final String? username;
  final String? password;
  final String? serverUrl;

  // --- Kredensial Khusus Bot WhatsApp ---
  final String? sessionId;

  // --- Spesifikasi Teknis & Metadata Tambahan ---
  final String? spesifikasi;
  final String? extraData;

  PurchasedService({
    this.id,
    required this.userEmail,
    required this.namaProduk,
    required this.kategori,
    required this.harga,
    required this.tanggalBeli,
    required this.tanggalKadaluarsa,
    required this.status,
    this.ipAddress,
    this.port,
    this.username,
    this.password,
    this.serverUrl,
    this.sessionId,
    this.spesifikasi,
    this.extraData,
  });

  /// Mengonversi baris tabel SQLite menjadi objek [PurchasedService]
  factory PurchasedService.fromMap(Map<String, dynamic> map) {
    return PurchasedService(
      id: (map['id'] as num?)?.toInt() ?? int.tryParse(map['id']?.toString() ?? ''),
      userEmail: map['user_email'] as String? ?? '',
      namaProduk: map['nama_produk'] as String? ?? '',
      kategori: map['kategori'] as String? ?? '',
      harga: (map['harga'] as num?)?.toDouble() ?? 0.0,
      tanggalBeli: map['tanggal_beli'] as String? ?? '',
      tanggalKadaluarsa: map['tanggal_kadaluarsa'] as String? ?? '',
      status: map['status'] as String? ?? 'Aktif',
      ipAddress: map['ip_address'] as String?,
      port: map['port'] as String?,
      username: map['username'] as String?,
      password: map['password'] as String?,
      serverUrl: map['server_url'] as String?,
      sessionId: map['session_id'] as String?,
      spesifikasi: map['spesifikasi'] as String?,
      extraData: map['extra_data'] as String?,
    );
  }

  /// Mengonversi Objek menjadi Map untuk query SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_email': userEmail,
      'nama_produk': namaProduk,
      'kategori': kategori,
      'harga': harga,
      'tanggal_beli': tanggalBeli,
      'tanggal_kadaluarsa': tanggalKadaluarsa,
      'status': status,
      'ip_address': ipAddress,
      'port': port,
      'username': username,
      'password': password,
      'server_url': serverUrl,
      'session_id': sessionId,
      'spesifikasi': spesifikasi,
      'extra_data': extraData,
    };
  }

  /// Menghitung sisa hari masa aktif layanan
  int get daysRemaining {
    try {
      final exp = DateTime.parse(tanggalKadaluarsa);
      final now = DateTime.now();
      return exp.difference(now).inDays;
    } catch (_) {
      return 30;
    }
  }

  /// Status apakah masa aktif telah habis
  bool get isExpired => daysRemaining <= 0;
}
