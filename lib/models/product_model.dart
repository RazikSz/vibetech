/// ============================================================================
/// MODEL PRODUK LAYANAN (PRODUCT MODEL) - VIBETECH XYZ
/// ============================================================================
/// Model entitas yang merepresentasikan item produk katalog di database SQLite:
/// 1. Cloud VPS (KVM VPS, High Frequency Server, NVMe SSD).
/// 2. Panel Hosting (Pterodactyl Game Server Singapore).
/// 3. Sewa Bot WhatsApp (Bot WA Basic, Pro, Enterprise).
/// 4. Manajemen Diskon Terintegrasi (Persentase Diskon & Harga Promo Otomatis).
class Product {
  /// ID Unik auto-increment dari tabel SQLite 'products'
  final int? id;

  /// Nama paket layanan (misal: "VPS Starter", "Game Hosting Panel SG")
  final String nama;

  /// Kategori produk: 'VPS', 'Panel Hosting', atau 'Bot WhatsApp'
  final String kategori;

  /// Harga sewa normal per bulan dalam satuan Rupiah (REAL di SQLite)
  final double harga;

  /// Sisa ketersediaan stok server/slot instance (INTEGER di SQLite)
  final int stok;

  /// Deskripsi spesifikasi teknis (CPU, RAM, Storage, Bandwidth)
  final String? deskripsi;

  /// Persentase diskon produk (REAL di SQLite, default: 0.0%)
  final double diskon;

  Product({
    this.id,
    required this.nama,
    required this.kategori,
    required this.harga,
    required this.stok,
    this.deskripsi,
    this.diskon = 0.0,
  });

  /// Mengonversi data Map/Row dari SQLite Database menjadi Objek [Product]
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      nama: map['nama'] as String? ?? 'Layanan Cloud',
      kategori: map['kategori'] as String? ?? 'VPS',
      harga: (map['harga'] as num?)?.toDouble() ?? 0.0,
      stok: (map['stok'] as num?)?.toInt() ?? 0,
      deskripsi: map['deskripsi'] as String?,
      diskon: (map['diskon'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Mengonversi Objek [Product] menjadi Map untuk operasi INSERT / UPDATE ke SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'kategori': kategori,
      'harga': harga,
      'stok': stok,
      'deskripsi': deskripsi,
      'diskon': diskon,
    };
  }

  /// Status apakah produk masih tersedia untuk dipesan
  bool get isAvailable => stok > 0;

  /// Status apakah produk sedang memiliki promo diskon aktif
  bool get hasDiscount => diskon > 0;

  /// Perhitungan harga final setelah potongan diskon
  double get hargaDiskon =>
      diskon > 0 ? (harga * (1.0 - (diskon / 100.0))) : harga;

  /// Besaran nominal potongan harga yang dihemat pengguna
  double get hematHarga => diskon > 0 ? (harga * (diskon / 100.0)) : 0.0;
}
