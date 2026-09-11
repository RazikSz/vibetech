import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/constants.dart';
import '../../database/db_helper.dart';
import '../../models/service_model.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/firebase_transaction_service.dart';
import '../../services/language_service.dart';
import '../home/produk_page.dart';

/// ============================================================================
/// HALAMAN DATA & MANAJEMEN BOT WHATSAPP (DATA BOT WA PAGE)
/// ============================================================================
/// Halaman khusus untuk mengelola sesi dan koneksi Bot WhatsApp:
/// 1. Tampilan Session ID dan Pairing Code 8 Digit.
/// 2. QR Code Scanner interaktif untuk menghubungkan perangkat WhatsApp.
/// 3. Pemantauan status koneksi WhatsApp (Aktif / Terputus).
class DataBotWaPage extends StatefulWidget {
  final bool isDarkMode;
  final String userEmail;

  const DataBotWaPage({
    super.key,
    required this.isDarkMode,
    this.userEmail = 'user@vibetech.com',
  });

  @override
  State<DataBotWaPage> createState() => _DataBotWaPageState();
}

class _DataBotWaPageState extends State<DataBotWaPage> {
  List<PurchasedService> _botList = [];
  String _activeEmail = 'user@vibetech.com';
  String _currentUserRole = 'user';
  bool get _isAdmin =>
      _currentUserRole == 'admin' || _currentUserRole == 'administrator';

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
    // Menginisialisasi email aktif dan memuat akun sewa Bot WhatsApp dari SQLite
    _initAndLoadBotData();

    // Hubungkan streaming listener real-time Firebase RTDB untuk pembaruan instan
    _botRealtimeListener = () {
      if (mounted) {
        _loadBotData();
      }
    };
    CloudSyncService.instance.servicesNotifier
        .addListener(_botRealtimeListener!);
  }

  VoidCallback? _botRealtimeListener;

  @override
  void dispose() {
    if (_botRealtimeListener != null) {
      CloudSyncService.instance.servicesNotifier
          .removeListener(_botRealtimeListener!);
    }
    super.dispose();
  }

  /// Membaca email aktif dari SharedPreferences dan memanggil query SQLite
  Future<void> _initAndLoadBotData() async {
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
    await _loadBotData();
  }

  /// Memuat daftar Bot WhatsApp milik pengguna dari database SQLite
  Future<void> _loadBotData() async {
    if (!mounted) return;
    try {
      final raw = await DatabaseHelper.instance
          .getServicesByCategory(_activeEmail, 'Bot WhatsApp')
          .timeout(const Duration(seconds: 4), onTimeout: () => []);
      if (mounted) {
        setState(() {
          _botList = raw.map((e) => PurchasedService.fromMap(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('[DataBotWaPage] Error loading Bot WA data: $e');
    }
  }

  /// Menyalin Pairing Code atau Session ID ke Clipboard perangkat
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
        backgroundColor: AppColors.emerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Menampilkan modal lembar bawah (Bottom Sheet) berisi QR Code untuk scan tautan WhatsApp Web
  void _showQrCodeModal(PurchasedService bot) {
    // Membangun string autentikasi QR WhatsApp simulasi
    final String qrData =
        'VIBETECH-WA-AUTH:${bot.sessionId ?? "SESSION-DEFAULT"}:${DateTime.now().millisecondsSinceEpoch}';

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: _textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              LanguageService.text(
                  'Scan QR Code WhatsApp', 'Scan WhatsApp QR Code'),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              LanguageService.text(
                'Buka WhatsApp di HP Anda > Perangkat Tertaut > Tautkan Perangkat',
                'Open WhatsApp on phone > Linked Devices > Link a Device',
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emerald.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0F172A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.emerald,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  LanguageService.text(
                      'Menunggu pemindaian...', 'Waiting for scan...'),
                  style: GoogleFonts.poppins(
                    color: AppColors.emerald,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  LanguageService.text('Tutup', 'Close'),
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showAddBotDialog() {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.text(
            'Akses Ditolak! Hanya Administrator yang dapat menambah data Bot WA manual.',
            'Access Denied! Only Administrators can add manual WhatsApp Bot data.',
          )),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final nameCtrl = TextEditingController(text: 'Bot WA Multi-Device');
    final sessionCtrl = TextEditingController(
        text:
            'WA-SESSION-VB${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final pairCtrl = TextEditingController(
        text: 'VBWA-${1000 + (DateTime.now().millisecond % 9000)}');
    final specsCtrl =
        TextEditingController(text: 'Unlimited Grup, Auto-reply, Blast AI');
    final priceCtrl = TextEditingController(text: '50000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          LanguageService.text(
              'Tambah Data Bot WhatsApp', 'Add New WhatsApp Bot Data'),
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: _textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameCtrl, 'Nama Bot', Icons.smart_toy_rounded),
              const SizedBox(height: 12),
              _buildDialogField(
                  sessionCtrl, 'Session ID', Icons.fingerprint_rounded),
              const SizedBox(height: 12),
              _buildDialogField(
                  pairCtrl, 'Pairing Code', Icons.qr_code_scanner_rounded),
              const SizedBox(height: 12),
              _buildDialogField(
                  specsCtrl, 'Fitur / Spesifikasi', Icons.checklist_rounded),
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
              backgroundColor: AppColors.emerald,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final now = DateTime.now();
              await DatabaseHelper.instance.createService({
                'user_email': _activeEmail,
                'nama_produk': nameCtrl.text,
                'kategori': 'Bot WhatsApp',
                'harga': double.tryParse(priceCtrl.text) ?? 50000.0,
                'tanggal_beli': now.toIso8601String(),
                'tanggal_kadaluarsa':
                    now.add(const Duration(days: 30)).toIso8601String(),
                'status': 'Aktif',
                'username': _activeEmail,
                'session_id': sessionCtrl.text,
                'spesifikasi': specsCtrl.text,
                'extra_data': 'PAIR-CODE: ${pairCtrl.text}',
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadBotData();
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
            'Akses Ditolak! Hanya Administrator yang dapat menghapus data Bot WA.',
            'Access Denied! Only Administrators can delete WhatsApp Bot data.',
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
          LanguageService.text('Hapus Data Bot WA', 'Delete WhatsApp Bot Data'),
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
              _loadBotData();
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
        prefixIcon: Icon(icon, color: AppColors.emerald, size: 20),
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
          LanguageService.text('Data Bot WhatsApp', 'WhatsApp Bot Data'),
          style: GoogleFonts.poppins(
              color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.emerald),
              onPressed: _showAddBotDialog,
              tooltip: LanguageService.text('Tambah Bot', 'Add Bot'),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (widget.isDarkMode)
            const CyberParticlesLayer(count: 20),
          _botList.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                      onRefresh: _loadBotData,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _botList.length,
                        itemBuilder: (context, index) {
                          final item = _botList[index];
                          return _buildBotCard(item);
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
            Icon(Icons.chat_bubble_outline_rounded,
                size: 80, color: _textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              LanguageService.text(
                  'Belum Ada Bot WhatsApp Aktif', 'No Active WhatsApp Bots'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              LanguageService.text(
                'Data Bot WhatsApp Anda (Session ID, Pairing Code, dan Scan QR) akan otomatis muncul di sini setelah Anda membeli paket Bot WhatsApp di Katalog Produk.',
                'Your WhatsApp Bot data (Session ID, Pairing Code, and Scan QR) will automatically appear here once you purchase a bot package.',
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
                        initialCategoryIndex: 2,
                      ),
                    ),
                  ).then((_) => _loadBotData());
                },
                icon: const Icon(Icons.shopping_bag_outlined,
                    color: Colors.white),
                label: Text(
                  LanguageService.text('Beli Bot WhatsApp di Produk Page',
                      'Buy WhatsApp Bot on Product Page'),
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
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
                onPressed: _showAddBotDialog,
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

  Widget _buildBotCard(PurchasedService bot) {
    final int daysLeft = bot.daysRemaining;
    Color timerColor = AppColors.success;
    if (daysLeft < 7) {
      timerColor = AppColors.error;
    } else if (daysLeft < 14) {
      timerColor = AppColors.warning;
    }

    final String session = bot.sessionId ?? 'WA-SESSION-VB7721';
    final String extra = bot.extraData ?? 'PAIR-CODE: VBWA-8821';
    String pairingCode = 'VBWA-8821';
    if (extra.contains(':')) {
      pairingCode = extra.split(':').last.trim();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDarkMode
              ? AppColors.emerald.withValues(alpha: 0.25)
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
              color: AppColors.emerald.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: AppColors.emerald, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bot.namaProduk,
                        style: GoogleFonts.poppins(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        bot.spesifikasi ?? '5 Grup, Auto-reply, Blast AI',
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
                        bot.status,
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
                // Session ID Row
                _buildCredentialRow(
                  label: 'Session ID',
                  value: session,
                  icon: Icons.fingerprint_rounded,
                  onCopy: () => _copyToClipboard(session, 'Session ID Bot WA'),
                ),
                const SizedBox(height: 10),

                // Pairing Code Box + Copy
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
                      const Icon(Icons.qr_code_scanner_rounded,
                          color: AppColors.emerald, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Pairing Code: ',
                        style: GoogleFonts.poppins(
                            color: _textSecondary, fontSize: 12),
                      ),
                      Expanded(
                        child: Text(
                          pairingCode,
                          style: GoogleFonts.spaceMono(
                            color: widget.isDarkMode
                                ? AppColors.emerald
                                : const Color(0xFF047857),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () =>
                            _copyToClipboard(pairingCode, 'Pairing Code WA'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.copy_rounded,
                                  color: AppColors.emerald, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                LanguageService.text('Salin', 'Copy'),
                                style: GoogleFonts.poppins(
                                  color: AppColors.emerald,
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

                // Button View QR Code
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showQrCodeModal(bot),
                    icon: const Icon(Icons.qr_code_2_rounded,
                        color: AppColors.emerald, size: 18),
                    label: Text(
                      LanguageService.text('Tampilkan QR Code Autentikasi',
                          'Show Authentication QR Code'),
                      style: GoogleFonts.poppins(
                        color: AppColors.emerald,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.emerald.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
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
                          'Rp ${NumberFormat('#,###', 'id_ID').format(bot.harga).replaceAll(',', '.')}',
                          style: GoogleFonts.poppins(
                            color: widget.isDarkMode
                                ? AppColors.emerald
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
                                bot.id ?? 0, bot.namaProduk),
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
          Icon(icon, color: AppColors.emerald, size: 16),
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
