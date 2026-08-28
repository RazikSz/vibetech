import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/constants.dart';
import '../../database/db_helper.dart';
import '../../models/service_model.dart';
import '../../services/language_service.dart';
import '../home/produk_page.dart';

/// ============================================================================
/// HALAMAN DATA & MANAJEMEN PANEL HOSTING (DATA PANEL PAGE)
/// ============================================================================
/// Halaman khusus untuk mengelola akun Panel Pterodactyl hosting:
/// 1. Tautan Server URL Login Panel.
/// 2. Username dan Password Panel Hosting.
/// 3. Tombol langsung membuka browser web menuju Dashboard Panel Pterodactyl.
class DataPanelPage extends StatefulWidget {
  final bool isDarkMode;
  final String userEmail;

  const DataPanelPage({
    super.key,
    required this.isDarkMode,
    this.userEmail = 'user@vibetech.com',
  });

  @override
  State<DataPanelPage> createState() => _DataPanelPageState();
}

class _DataPanelPageState extends State<DataPanelPage>
    with SingleTickerProviderStateMixin {
  List<PurchasedService> _panelList = [];
  bool _isLoading = true;
  String _activeEmail = 'user@vibetech.com';
  final Map<int, bool> _showPasswordMap = {};

  late AnimationController _particleController;
  final List<AppParticle> _particles = [];
  final math.Random _random = math.Random();

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
    // Inisialisasi Partikel Cyber Ambient (Dark Mode)
    _particles.addAll(AppParticle.generateList(_random, count: 20));
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _particleController.addListener(() {
      AppParticle.updatePositions(_particles);
    });

    _activeEmail = widget.userEmail;
    // Menginisialisasi email aktif dan memuat akun Panel Pterodactyl dari SQLite
    _initAndLoadPanelData();
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  /// Memuat email akun aktif yang tersimpan dan memanggil query SQLite
  Future<void> _initAndLoadPanelData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('email');
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _activeEmail = savedEmail;
      }
    } catch (_) {}
    await _loadPanelData();
  }

  /// Memuat daftar panel hosting milik pengguna dari database SQLite
  Future<void> _loadPanelData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final raw = await DatabaseHelper.instance
        .getServicesByCategory(_activeEmail, 'Panel Hosting');
    if (mounted) {
      setState(() {
        _panelList = raw.map((e) => PurchasedService.fromMap(e)).toList();
        _isLoading = false;
      });
    }
  }

  /// Menyalin teks kredensial panel ke Clipboard perangkat dengan feedback SnackBar
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

  /// Membuka tautan dashboard panel di browser eksternal atau fallback salin URL jika gagal
  Future<void> _openPanelUrl(String urlStr) async {
    final uri = Uri.tryParse(urlStr);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _copyToClipboard(urlStr, 'URL Panel');
    }
  }

  /// Menampilkan dialog simulasi penerbitan akun panel baru
  void _showAddPanelDialog() {
    final nameCtrl = TextEditingController(text: 'Panel Node.js / Pterodactyl');
    final urlCtrl =
        TextEditingController(text: 'https://panel.vibetech.xyz:8080');
    final userCtrl = TextEditingController(
        text:
            'client_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    final passCtrl = TextEditingController(
        text:
            'PanelPass#${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    final specsCtrl = TextEditingController(text: '2GB RAM, 1 vCPU, 20GB Disk');
    final priceCtrl = TextEditingController(text: '35000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          LanguageService.text(
              'Tambah Data Panel Hosting', 'Add New Hosting Panel Data'),
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: _textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(
                  nameCtrl, 'Nama Layanan Panel', Icons.cloud_rounded),
              const SizedBox(height: 12),
              _buildDialogField(urlCtrl, 'URL Login Panel', Icons.link_rounded),
              const SizedBox(height: 12),
              _buildDialogField(
                  userCtrl, 'Username Panel', Icons.person_rounded),
              const SizedBox(height: 12),
              _buildDialogField(passCtrl, 'Password Panel', Icons.lock_rounded),
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
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final now = DateTime.now();
              await DatabaseHelper.instance.createService({
                'user_email': widget.userEmail,
                'nama_produk': nameCtrl.text,
                'kategori': 'Panel Hosting',
                'harga': double.tryParse(priceCtrl.text) ?? 25000.0,
                'tanggal_beli': now.toIso8601String(),
                'tanggal_kadaluarsa':
                    now.add(const Duration(days: 30)).toIso8601String(),
                'status': 'Aktif',
                'port': '8080',
                'username': userCtrl.text,
                'password': passCtrl.text,
                'server_url': urlCtrl.text,
                'spesifikasi': specsCtrl.text,
                'extra_data': 'Node: Singapore High Performance',
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadPanelData();
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          LanguageService.text('Hapus Data Panel', 'Delete Panel Data'),
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
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadPanelData();
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
        prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
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
          LanguageService.text('Data Panel Hosting', 'Hosting Panel Data'),
          style: GoogleFonts.poppins(
              color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: AppColors.accent),
            onPressed: _showAddPanelDialog,
            tooltip: LanguageService.text('Tambah Panel', 'Add Panel'),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (widget.isDarkMode)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) {
                  return CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: AppParticlePainter(_particles),
                  );
                },
              ),
            ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _panelList.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadPanelData,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _panelList.length,
                        itemBuilder: (context, index) {
                          final item = _panelList[index];
                          return _buildPanelCard(item);
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
            Icon(Icons.cloud_outlined,
                size: 80, color: _textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              LanguageService.text(
                  'Belum Ada Panel Hosting Aktif', 'No Active Hosting Panels'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              LanguageService.text(
                'Data Panel Hosting Anda (URL Pterodactyl, Username, dan Password) akan otomatis muncul di sini setelah Anda membeli paket Panel Hosting di Katalog Produk.',
                'Your Hosting Panel data (Pterodactyl URL, Username, and Password) will automatically appear here once you purchase a hosting package.',
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
                        initialCategoryIndex: 1,
                      ),
                    ),
                  ).then((_) => _loadPanelData());
                },
                icon: const Icon(Icons.shopping_bag_outlined,
                    color: Colors.white),
                label: Text(
                  LanguageService.text('Beli Panel Hosting di Produk Page',
                      'Buy Hosting Panel on Product Page'),
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _showAddPanelDialog,
              icon: Icon(Icons.add_circle_outline_rounded,
                  color: _textSecondary, size: 16),
              label: Text(
                LanguageService.text('Atau Tambah Kredensial Manual',
                    'Or Add Credentials Manually'),
                style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelCard(PurchasedService panel) {
    final bool showPass = _showPasswordMap[panel.id ?? 0] ?? false;
    final int daysLeft = panel.daysRemaining;
    Color timerColor = AppColors.success;
    if (daysLeft < 7) {
      timerColor = AppColors.error;
    } else if (daysLeft < 14) {
      timerColor = AppColors.warning;
    }

    final panelUrl = panel.serverUrl ?? 'https://panel.vibetech.xyz:8080';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDarkMode
              ? AppColors.accent.withValues(alpha: 0.25)
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
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cloud_rounded,
                      color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        panel.namaProduk,
                        style: GoogleFonts.poppins(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        panel.spesifikasi ??
                            '1GB RAM, 1 Core CPU, 10GB Storage',
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
                        panel.status,
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
                // Panel URL Box + Open Button
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
                      const Icon(Icons.link_rounded,
                          color: AppColors.accent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          panelUrl,
                          style: GoogleFonts.spaceMono(
                            color: widget.isDarkMode
                                ? AppColors.accent
                                : const Color(0xFF9333EA),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () => _openPanelUrl(panelUrl),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.open_in_new_rounded,
                                  color: AppColors.accent, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                LanguageService.text('Buka', 'Open'),
                                style: GoogleFonts.poppins(
                                  color: AppColors.accent,
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
                const SizedBox(height: 10),

                // Username Panel
                _buildCredentialRow(
                  label: 'Username',
                  value: panel.username ?? 'client_demouser',
                  icon: Icons.person_outline_rounded,
                  onCopy: () => _copyToClipboard(
                      panel.username ?? 'client_demouser', 'Username Panel'),
                ),
                const SizedBox(height: 10),

                // Password Panel (With show/hide)
                _buildCredentialRow(
                  label: 'Password Panel',
                  value: showPass
                      ? (panel.password ?? 'panel_pass#2026')
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
                        _showPasswordMap[panel.id ?? 0] = !showPass;
                      });
                    },
                  ),
                  onCopy: () => _copyToClipboard(
                      panel.password ?? '', 'Password Panel Hosting'),
                ),
                const SizedBox(height: 10),

                // Extra info node
                if (panel.extraData != null && panel.extraData!.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.primary, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            panel.extraData!,
                            style: GoogleFonts.poppins(
                                color: _textSecondary, fontSize: 11),
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
                          'Rp ${NumberFormat('#,###', 'id_ID').format(panel.harga).replaceAll(',', '.')}',
                          style: GoogleFonts.poppins(
                            color: widget.isDarkMode
                                ? AppColors.accent
                                : AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.error, size: 20),
                          onPressed: () => _showDeleteConfirmDialog(
                              panel.id ?? 0, panel.namaProduk),
                          tooltip: LanguageService.tr('hapus'),
                        ),
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
          Icon(icon, color: AppColors.accent, size: 16),
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
