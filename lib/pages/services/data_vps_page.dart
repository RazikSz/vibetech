import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/constants.dart';
import '../../database/db_helper.dart';
import '../../models/service_model.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/firebase_transaction_service.dart';
import '../../services/language_service.dart';
import '../home/produk_page.dart';

/// ============================================================================
/// HALAMAN DATA & MANAJEMEN VPS (DATA VPS PAGE)
/// ============================================================================
/// Halaman khusus untuk mengelola seluruh VPS milik pengguna:
/// 1. Daftar IP Address, Port SSH, Root Username, dan Password VPS.
/// 2. Salin kredensial dengan satu sentuhan.
/// 3. Panduan koneksi menggunakan SSH Terminal (Putty, Termius, Command Prompt).
class DataVpsPage extends StatefulWidget {
  final bool isDarkMode;
  final String userEmail;

  const DataVpsPage({
    super.key,
    required this.isDarkMode,
    this.userEmail = 'user@vibetech.com',
  });

  @override
  State<DataVpsPage> createState() => _DataVpsPageState();
}

class _DataVpsPageState extends State<DataVpsPage> {
  List<PurchasedService> _vpsList = [];
  String _activeEmail = 'user@vibetech.com';
  String _currentUserRole = 'user';
  bool get _isAdmin =>
      _currentUserRole == 'admin' || _currentUserRole == 'administrator';
  final Map<int, bool> _showPasswordMap = {};

  Color get _bgColor =>
      widget.isDarkMode ? AppColors.darkBg : AppColors.lightBg;
  Color get _cardColor =>
      widget.isDarkMode ? AppColors.darkCard : AppColors.lightCard;
  Color get _textPrimary => widget.isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.lightTextPrimary;
  Color get _textSecondary => widget.isDarkMode
      ? AppColors.darkTextSecondary
      : AppColors.lightTextSecondary;

  @override
  void initState() {
    super.initState();
    _activeEmail = widget.userEmail;
    // Menginisialisasi email aktif dari SharedPreferences dan memuat data VPS
    _initAndLoadVpsData();

    // Hubungkan streaming listener real-time Firebase RTDB untuk pembaruan instan
    _vpsRealtimeListener = () {
      if (mounted) {
        _loadVpsData();
      }
    };
    CloudSyncService.instance.servicesNotifier
        .addListener(_vpsRealtimeListener!);
  }

  VoidCallback? _vpsRealtimeListener;

  @override
  void dispose() {
    if (_vpsRealtimeListener != null) {
      CloudSyncService.instance.servicesNotifier
          .removeListener(_vpsRealtimeListener!);
    }
    super.dispose();
  }

  /// Membaca email pengguna aktif yang tersimpan dan memicu pemuatan data dari SQLite
  Future<void> _initAndLoadVpsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('email');
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _activeEmail = savedEmail;
      }
      final savedRole = prefs.getString('role');
      if (savedRole != null && savedRole.isNotEmpty) {
        _currentUserRole = savedRole.toLowerCase();
      }
    } catch (_) {}
    await _loadVpsData();
  }

  /// Memuat daftar VPS aktif milik pengguna dari tabel 'purchased_services' SQLite
  Future<void> _loadVpsData() async {
    if (!mounted) return;
    try {
      final raw = await DatabaseHelper.instance
          .getServicesByCategory(_activeEmail, 'VPS')
          .timeout(const Duration(seconds: 4), onTimeout: () => []);
      if (mounted) {
        setState(() {
          _vpsList = raw.map((e) => PurchasedService.fromMap(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('[DataVpsPage] Error loading VPS data: $e');
    }
  }

  /// Menyalin kredensial (IP, Password, SSH Command) ke Clipboard perangkat
  /// Memberikan feedback getaran (Haptic) dan notifikasi SnackBar hijau
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              '$label ${LanguageService.text('berhasil disalin!', 'copied successfully!')}',
              style: GoogleFonts.poppins(),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Menampilkan dialog simulasi penambahan / provisioning manual VPS baru
  void _showAddVpsDialog() {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.text(
            'Akses Ditolak! Hanya Administrator yang dapat menambah data VPS manual.',
            'Access Denied! Only Administrators can add manual VPS data.',
          )),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final nameCtrl = TextEditingController(text: 'VPS Ubuntu 22.04');
    // Menghasilkan IP publik unik acak dalam blok 103.187.x.x
    final ipCtrl = TextEditingController(
        text:
            '103.187.${100 + (DateTime.now().millisecond % 150)}.${10 + (DateTime.now().second % 200)}');
    final userCtrl = TextEditingController(text: 'root');
    final passCtrl = TextEditingController(
        text:
            'VpsRoot#${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    final specsCtrl =
        TextEditingController(text: '2 vCPU, 4GB RAM, 50GB NVMe SSD');
    final priceCtrl = TextEditingController(text: '75000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          LanguageService.text('Tambah Data VPS Baru', 'Add New VPS Data'),
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: _textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameCtrl, 'Nama VPS', Icons.dns_rounded),
              const SizedBox(height: 12),
              _buildDialogField(ipCtrl, 'IP Address', Icons.language_rounded),
              const SizedBox(height: 12),
              _buildDialogField(userCtrl, 'SSH Username', Icons.person_rounded),
              const SizedBox(height: 12),
              _buildDialogField(passCtrl, 'Root Password', Icons.lock_rounded),
              const SizedBox(height: 12),
              _buildDialogField(specsCtrl, 'Spesifikasi', Icons.memory_rounded),
              const SizedBox(height: 12),
              _buildDialogField(
                  priceCtrl, 'Harga (Rp)', Icons.attach_money_rounded,
                  keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LanguageService.tr('batal'),
                style: GoogleFonts.poppins(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (nameCtrl.text.isEmpty || ipCtrl.text.isEmpty) return;
              final now = DateTime.now();
              await DatabaseHelper.instance.createService({
                'user_email': _activeEmail,
                'nama_produk': nameCtrl.text,
                'kategori': 'VPS',
                'harga': double.tryParse(priceCtrl.text) ?? 50000.0,
                'tanggal_beli': now.toIso8601String(),
                'tanggal_kadaluarsa':
                    now.add(const Duration(days: 30)).toIso8601String(),
                'status': 'Aktif',
                'ip_address': ipCtrl.text,
                'port': '22',
                'username': userCtrl.text,
                'password': passCtrl.text,
                'spesifikasi': specsCtrl.text,
                'extra_data': 'OS: Ubuntu 22.04 LTS',
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadVpsData();
            },
            child: Text(LanguageService.tr('simpan'),
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(int id, String name) {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.text(
            'Akses Ditolak! Hanya Administrator yang dapat menghapus data VPS.',
            'Access Denied! Only Administrators can delete VPS data.',
          )),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          LanguageService.text('Hapus Data VPS', 'Delete VPS Data'),
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: _textPrimary),
        ),
        content: Text(
          LanguageService.text(
              'Apakah Anda yakin ingin menghapus $name dari daftar layanan?',
              'Are you sure you want to delete $name from your services?'),
          style: GoogleFonts.poppins(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LanguageService.tr('batal'),
                style: GoogleFonts.poppins(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await DatabaseHelper.instance.deleteService(id);
              await FirebaseTransactionService.instance.deleteServiceFromFirebase(
                id,
                namaProduk: name,
                userEmail: _activeEmail,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadVpsData();
            },
            child: Text(LanguageService.tr('hapus'),
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(
      TextEditingController ctrl, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: widget.isDarkMode
            ? const Color(0xFF1E293B)
            : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: _textPrimary),
        title: Text(
          LanguageService.text('Data VPS Server', 'VPS Server Data'),
          style: GoogleFonts.poppins(
              color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.cyan),
              onPressed: _showAddVpsDialog,
              tooltip: LanguageService.text('Tambah VPS', 'Add VPS'),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (widget.isDarkMode)
            const CyberParticlesLayer(count: 20),
          _vpsList.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                      onRefresh: _loadVpsData,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _vpsList.length,
                        itemBuilder: (context, index) {
                          final item = _vpsList[index];
                          return _buildVpsCard(item);
                        },
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dns_outlined,
                size: 80, color: _textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              LanguageService.text(
                  'Belum Ada Layanan VPS Aktif', 'No Active VPS Services'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              LanguageService.text(
                'Data VPS Anda (IP Address, SSH, dan Root Password) akan otomatis muncul di sini setelah Anda membeli paket VPS di Katalog Produk.',
                'Your VPS data (IP Address, SSH, and Root Password) will automatically appear here once you purchase a VPS package.',
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProdukPage(
                        isDarkMode: widget.isDarkMode,
                        initialCategoryIndex: 0,
                      ),
                    ),
                  ).then((_) => _loadVpsData());
                },
                icon: const Icon(Icons.shopping_bag_outlined,
                    color: Colors.white),
                label: Text(
                  LanguageService.text(
                      'Beli VPS di Produk Page', 'Buy VPS on Product Page'),
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            if (_isAdmin) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _showAddVpsDialog,
                icon: Icon(Icons.add_circle_outline_rounded,
                    color: _textSecondary, size: 16),
                label: Text(
                  LanguageService.text('Atau Tambah Kredensial Manual',
                      'Or Add Credentials Manually'),
                  style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVpsCard(PurchasedService vps) {
    final bool showPass = _showPasswordMap[vps.id ?? 0] ?? false;
    final int daysLeft = vps.daysRemaining;
    Color timerColor = AppColors.success;
    if (daysLeft < 7) {
      timerColor = AppColors.error;
    } else if (daysLeft < 14) {
      timerColor = AppColors.warning;
    }

    final String sshCommand =
        'ssh ${vps.username ?? "root"}@${vps.ipAddress ?? "127.0.0.1"}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDarkMode
              ? AppColors.primary.withValues(alpha: 0.25)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: widget.isDarkMode ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.dns_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vps.namaProduk,
                        style: GoogleFonts.poppins(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        vps.spesifikasi ?? '1 vCPU, 2GB RAM, 20GB SSD',
                        style: GoogleFonts.poppins(
                          color: _textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        vps.status,
                        style: GoogleFonts.poppins(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Credentials Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // IP Address Row
                _buildCredentialRow(
                  label: 'IP Server',
                  value: vps.ipAddress ?? '103.187.142.88',
                  icon: Icons.language_rounded,
                  onCopy: () =>
                      _copyToClipboard(vps.ipAddress ?? '', 'IP Address VPS'),
                ),
                const SizedBox(height: 10),

                // Port & Username
                Row(
                  children: [
                    Expanded(
                      child: _buildCredentialRow(
                        label: 'Port SSH',
                        value: vps.port ?? '22',
                        icon: Icons.tag_rounded,
                        onCopy: () =>
                            _copyToClipboard(vps.port ?? '22', 'Port SSH'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildCredentialRow(
                        label: 'User SSH',
                        value: vps.username ?? 'root',
                        icon: Icons.person_outline_rounded,
                        onCopy: () => _copyToClipboard(
                            vps.username ?? 'root', 'Username SSH'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Password Row (With show/hide)
                _buildCredentialRow(
                  label: 'Root Password',
                  value: showPass
                      ? (vps.password ?? 'vps_pass#2026')
                      : '••••••••••••',
                  icon: Icons.key_rounded,
                  trailing: IconButton(
                    icon: Icon(
                      showPass
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: _textSecondary,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        _showPasswordMap[vps.id ?? 0] = !showPass;
                      });
                    },
                  ),
                  onCopy: () =>
                      _copyToClipboard(vps.password ?? '', 'Password Root VPS'),
                ),
                const SizedBox(height: 12),

                // SSH Command One-Click Box
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isDarkMode
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.terminal_rounded,
                          color: AppColors.cyan, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sshCommand,
                          style: GoogleFonts.spaceMono(
                            color: widget.isDarkMode
                                ? AppColors.cyan
                                : const Color(0xFF0F766E),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () =>
                            _copyToClipboard(sshCommand, 'Perintah SSH'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.cyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.copy_rounded,
                                  color: AppColors.cyan, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                LanguageService.text('Salin', 'Copy'),
                                style: GoogleFonts.poppins(
                                  color: AppColors.cyan,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Expiry & Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, color: timerColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '$daysLeft ${LanguageService.tr('sisa_hari')}',
                          style: GoogleFonts.poppins(
                            color: timerColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Rp ${NumberFormat('#,###', 'id_ID').format(vps.harga).replaceAll(',', '.')}',
                          style: GoogleFonts.poppins(
                            color: widget.isDarkMode
                                ? AppColors.cyan
                                : AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AppColors.error, size: 20),
                            onPressed: () => _showDeleteConfirmDialog(
                                vps.id ?? 0, vps.namaProduk),
                            tooltip: LanguageService.tr('hapus'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow({
    required String label,
    required String value,
    required IconData icon,
    Widget? trailing,
    required VoidCallback onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF1E293B).withValues(alpha: 0.6)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDarkMode
              ? const Color(0xFF334155).withValues(alpha: 0.5)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              color: _textSecondary,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: _textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing,
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded, color: _textSecondary, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
