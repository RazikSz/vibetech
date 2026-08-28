import 'package:flutter/material.dart';
import 'package:vibetech_xyz/pages/common/total_pesanan_page.dart';

// Mengekspor TotalPesananPage agar kode legacy yang mengimpor file ini tetap kompatibel
export 'package:vibetech_xyz/pages/common/total_pesanan_page.dart';

/// ============================================================================
/// HALAMAN STATUS SERVER & PELACAKAN PESANAN (STATUS SERVER PAGE)
/// ============================================================================
/// Berkas wrapper / alias untuk memastikan kompatibilitas rute lama:
/// 1. Meneruskan seluruh parameter state (tema, username, email, role) ke [TotalPesananPage].
/// 2. Mengintegrasikan pemantauan status pesanan server secara real-time dari SQLite.
class StatusServerPage extends StatelessWidget {
  /// Parameter tema tampilan (True: Cyber Dark Mode, False: Clean Light Mode)
  final bool isDarkMode;

  /// Username pengguna aktif yang sedang membuka halaman
  final String? username;

  /// Email pengguna aktif untuk filter pesanan personal di database
  final String? userEmail;

  /// Hak akses pengguna ('admin' untuk manajemen global, 'user' untuk member)
  final String? userRole;

  const StatusServerPage({
    super.key,
    this.isDarkMode = true,
    this.username,
    this.userEmail,
    this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    // Merender TotalPesananPage dengan meneruskan seluruh parameter yang diterima
    return TotalPesananPage(
      isDarkMode: isDarkMode,
      username: username,
      userEmail: userEmail,
      userRole: userRole,
    );
  }
}
