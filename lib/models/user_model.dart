/// ============================================================================
/// MODEL AKUN PENGGUNA (USER MODEL) - VIBETECH XYZ
/// ============================================================================
/// Model entitas yang merepresentasikan data akun pengguna di SQLite dan Firebase:
/// 1. Identitas akun (UID, Nama Lengkap, Username, Email, Nomor Telepon).
/// 2. Keamanan & Akses (Password, PIN Transaksi 6-Digit, Role Pengguna/Admin, 2FA).
/// 3. Saldo VibeWallet, Lokasi Profil, Avatar URL, Kode Referral, dan Preferensi Bahasa.
class UserModel {
  /// ID Unik auto-increment tabel 'users' di SQLite lokal
  final int? id;

  /// UID unik akun pengguna (Firebase Auth / UUID identitas)
  final String uid;

  /// Nama lengkap pengguna
  final String nama;

  /// Username unik pengguna
  final String username;

  /// Email terdaftar pengguna
  final String email;

  /// Nomor telepon / WhatsApp pengguna
  final String? phone;

  /// Kata sandi akun (terenkripsi / hash)
  final String password;

  /// PIN transaksi 6-digit untuk otorisasi pembayaran (default '123456')
  final String pin;

  /// Kode referral pengguna
  final String? referralCode;

  /// Peran akun: 'user' atau 'admin' / 'administrator'
  final String role;

  /// Waktu pembuatan akun (Format ISO 8601 String)
  final String createdAt;

  /// Saldo aktif VibeWallet pengguna
  final double saldo;

  /// Lokasi tempat tinggal pengguna (misal: 'Jakarta, Indonesia')
  final String? location;

  /// URL foto profil / avatar pengguna
  final String? avatarUrl;

  /// Status autentikasi dua faktor (2FA) (1 = Aktif, 0 = Nonaktif)
  final int is2FA;

  /// Preferensi bahasa aplikasi (misal: 'Indonesia', 'English')
  final String language;

  /// Waktu terakhir data akun diperbarui di cloud
  final String? updatedAt;

  UserModel({
    this.id,
    required this.uid,
    required this.nama,
    required this.username,
    required this.email,
    this.phone,
    required this.password,
    this.pin = '123456',
    this.referralCode,
    this.role = 'user',
    required this.createdAt,
    this.saldo = 0.0,
    this.location,
    this.avatarUrl,
    this.is2FA = 1,
    this.language = 'Indonesia',
    this.updatedAt,
  });

  /// Mengonversi baris tabel SQLite / Map menjadi objek [UserModel]
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      uid: map['uid']?.toString() ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
      nama: map['nama']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString(),
      password: map['password']?.toString() ?? '',
      pin: map['pin']?.toString() ?? '123456',
      referralCode: map['referralCode']?.toString(),
      role: map['role']?.toString() ?? 'user',
      createdAt: map['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      saldo: (map['saldo'] as num?)?.toDouble() ?? 0.0,
      location: map['location']?.toString(),
      avatarUrl: map['avatarUrl']?.toString(),
      is2FA: (map['is2FA'] as num?)?.toInt() ?? 1,
      language: map['language']?.toString() ?? 'Indonesia',
      updatedAt: map['updatedAt']?.toString() ?? map['updated_at']?.toString(),
    );
  }

  /// Mengonversi dokumen Firebase Cloud Firestore / Realtime Database menjadi objek [UserModel]
  factory UserModel.fromFirestore(Map<String, dynamic> doc, [String? docId]) {
    return UserModel(
      id: (doc['id'] as num?)?.toInt(),
      uid: (doc['uid']?.toString()) ?? docId ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
      nama: doc['nama']?.toString() ?? '',
      username: doc['username']?.toString() ?? '',
      email: doc['email']?.toString() ?? '',
      phone: doc['phone']?.toString(),
      password: doc['password']?.toString() ?? '',
      pin: doc['pin']?.toString() ?? '123456',
      referralCode: doc['referralCode']?.toString() ?? doc['referral_code']?.toString(),
      role: doc['role']?.toString() ?? 'user',
      createdAt: doc['createdAt']?.toString() ?? doc['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      saldo: (doc['saldo'] as num?)?.toDouble() ?? 0.0,
      location: doc['location']?.toString(),
      avatarUrl: doc['avatarUrl']?.toString() ?? doc['avatar_url']?.toString(),
      is2FA: (doc['is2FA'] as num?)?.toInt() ?? (doc['is_2fa'] == true ? 1 : 0),
      language: doc['language']?.toString() ?? 'Indonesia',
      updatedAt: doc['updatedAt']?.toString() ?? doc['updated_at']?.toString(),
    );
  }

  /// Mengonversi Objek [UserModel] menjadi Map untuk INSERT / UPDATE ke SQLite lokal
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'uid': uid,
      'nama': nama,
      'username': username,
      'email': email,
      if (phone != null) 'phone': phone,
      'password': password,
      'pin': pin,
      if (referralCode != null) 'referralCode': referralCode,
      'role': role,
      'createdAt': createdAt,
      'saldo': saldo,
      if (location != null) 'location': location,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'is2FA': is2FA,
      'language': language,
    };
  }

  /// Mengonversi Objek [UserModel] menjadi Map untuk disimpan ke Firebase (Cloud Firestore & RTDB)
  Map<String, dynamic> toFirestore() {
    return {
      if (id != null) 'id': id,
      'uid': uid,
      'nama': nama,
      'username': username,
      'email': email,
      'phone': phone ?? '',
      'password': password,
      'pin': pin,
      'referralCode': referralCode ?? '',
      'role': role,
      'createdAt': createdAt,
      'saldo': saldo,
      'location': location ?? '',
      'avatarUrl': avatarUrl ?? '',
      'is2FA': is2FA,
      'language': language,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  /// Memeriksa apakah akun merupakan administrator
  bool get isAdmin =>
      role.toLowerCase() == 'admin' || role.toLowerCase() == 'administrator';

  /// Memeriksa apakah akun merupakan user biasa
  bool get isUser => !isAdmin;

  /// Memeriksa apakah 2FA diaktifkan
  bool get isTwoFactorEnabled => is2FA == 1;

  /// Menyalin objek dengan nilai properti yang diperbarui
  UserModel copyWith({
    int? id,
    String? uid,
    String? nama,
    String? username,
    String? email,
    String? phone,
    String? password,
    String? pin,
    String? referralCode,
    String? role,
    String? createdAt,
    double? saldo,
    String? location,
    String? avatarUrl,
    int? is2FA,
    String? language,
    String? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      nama: nama ?? this.nama,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      pin: pin ?? this.pin,
      referralCode: referralCode ?? this.referralCode,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      saldo: saldo ?? this.saldo,
      location: location ?? this.location,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      is2FA: is2FA ?? this.is2FA,
      language: language ?? this.language,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
