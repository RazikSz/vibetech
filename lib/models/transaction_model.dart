/// ============================================================================
/// MODEL TRANSAKSI PEMBELIAN (TRANSACTION MODEL) - VIBETECH XYZ
/// ============================================================================
/// Model entitas yang merepresentasikan catatan riwayat transaksi & invoice di database SQLite:
/// 1. Pembelian Cloud VPS, Panel Pterodactyl, dan Bot WhatsApp.
/// 2. Pencatatan metode pembayaran (Saldo VibeWallet, QRIS, Virtual Account).
/// 3. Pemantauan status transaksi ('Selesai', 'Pending', 'Diproses', 'Dibatalkan').
class TransactionModel {
  /// ID Unik auto-increment tabel 'transactions'
  final int? id;

  /// Nomor Invoice unik transaksi
  final String? invoiceNo;

  /// Email akun pembeli/pemesan
  final String userEmail;

  /// Nama produk atau paket yang dibeli
  final String namaProduk;

  /// Jumlah kuantitas layanan yang dipesan
  final int jumlah;

  /// Total nominal tagihan dalam satuan Rupiah
  final double totalHarga;

  /// Tanggal transaksi dilakukan (Format ISO8601 / Tanggal String)
  final String tanggal;

  /// Status transaksi: 'Selesai', 'Pending', 'Diproses', 'Dibatalkan'
  final String status;

  /// Metode Pembayaran (QRIS, VibeWallet, Virtual Account, dll.)
  final String? paymentMethod;

  /// Catatan tambahan / deskripsi item
  final String? notes;

  TransactionModel({
    this.id,
    this.invoiceNo,
    required this.userEmail,
    required this.namaProduk,
    required this.jumlah,
    required this.totalHarga,
    required this.tanggal,
    required this.status,
    this.paymentMethod,
    this.notes,
  });

  /// Mengonversi baris tabel SQLite / Map menjadi Objek [TransactionModel]
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      invoiceNo: map['invoice_no'] as String?,
      userEmail: map['user_email'] as String? ?? '',
      namaProduk: map['nama_produk'] as String? ?? '',
      jumlah: (map['jumlah'] as num?)?.toInt() ?? 1,
      totalHarga: (map['total_harga'] as num?)?.toDouble() ?? 0.0,
      tanggal: map['tanggal'] as String? ?? '',
      status: map['status'] as String? ?? 'Pending',
      paymentMethod: map['payment_method'] as String?,
      notes: map['notes'] as String?,
    );
  }

  /// Mengonversi dokumen Firebase Firestore menjadi Objek [TransactionModel]
  factory TransactionModel.fromFirestore(Map<String, dynamic> doc, [String? docId]) {
    return TransactionModel(
      id: (doc['id'] as num?)?.toInt(),
      invoiceNo: (doc['invoice_no'] as String?) ?? docId,
      userEmail: doc['user_email'] as String? ?? '',
      namaProduk: doc['nama_produk'] as String? ?? '',
      jumlah: (doc['jumlah'] as num?)?.toInt() ?? 1,
      totalHarga: (doc['total_harga'] as num?)?.toDouble() ?? 0.0,
      tanggal: doc['tanggal'] as String? ?? '',
      status: doc['status'] as String? ?? 'Pending',
      paymentMethod: doc['payment_method'] as String?,
      notes: doc['notes'] as String?,
    );
  }

  /// Mengonversi Objek [TransactionModel] menjadi Map untuk INSERT / UPDATE ke SQLite
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (invoiceNo != null) 'invoice_no': invoiceNo,
      'user_email': userEmail,
      'nama_produk': namaProduk,
      'jumlah': jumlah,
      'total_harga': totalHarga,
      'tanggal': tanggal,
      'status': status,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (notes != null) 'notes': notes,
    };
  }

  /// Mengonversi Objek [TransactionModel] menjadi Map untuk disimpan ke Firebase Firestore
  Map<String, dynamic> toFirestore() {
    return {
      if (id != null) 'id': id,
      if (invoiceNo != null) 'invoice_no': invoiceNo,
      'user_email': userEmail,
      'nama_produk': namaProduk,
      'jumlah': jumlah,
      'total_harga': totalHarga,
      'tanggal': tanggal,
      'status': status,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (notes != null) 'notes': notes,
    };
  }

  /// Memeriksa apakah transaksi telah lunas
  bool get isPaid => status.toLowerCase() == 'selesai';
}
