import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../database/db_helper.dart';
import '../../models/service_model.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/firebase_transaction_service.dart';
import '../../services/language_service.dart';
import '../home/produk_page.dart';
import '../services/data_bot_wa_page.dart';
import '../services/data_panel_page.dart';
import '../services/data_vps_page.dart';

/// ============================================================================
/// HALAMAN DATA LAYANAN & PANDUAN AKTIF (DATA LAYANAN / PANDUAN PAGE)
/// ============================================================================
/// Halaman ini menampilkan kredensial dan panduan penggunaan layanan yang telah dibeli:
/// 1. Data VPS: IP Address, Port SSH, Root Username, Root Password, dan Tutorial Akses Putty.
/// 2. Data Panel Hosting: Server URL Pterodactyl, Username, Password, dan Tombol Login Otomatis.
/// 3. Data Bot WhatsApp: Session ID, Pairing Code, Scan QR Login, dan Status Koneksi WA.
typedef PanduanPage = DataLayananPage;

class DataLayananPage extends StatefulWidget {
  final bool isDarkMode;
  final String userEmail;
  final int initialTabIndex;

  const DataLayananPage({
    super.key,
    this.isDarkMode = true,
    this.userEmail = 'user@vibetech.com',
    this.initialTabIndex = 0,
  });

  @override
  State<DataLayananPage> createState() => _DataLayananPageState();
}

class _DataLayananPageState extends State<DataLayananPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeEmail = 'user@vibetech.com';
  String _userRole = 'user';
  List<PurchasedService> _allServices = [];
  bool _isLoading = false;
  final Map<int, bool> _showPasswordMap = {};
  Timer? _liveSyncTimer;
  VoidCallback? _servicesRealtimeListener;

  bool get _isAdmin {
    final email = _activeEmail.toLowerCase();
    final role = _userRole.toLowerCase();
    return role == 'admin' ||
        role == 'administrator' ||
        email == 'admin@vibetech.com' ||
        email == 'raziek';
  }

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
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    // Pasang listener streaming real-time Firebase RTDB untuk layanan aktif
    _servicesRealtimeListener = () async {
      try {
        final data =
            await DatabaseHelper.instance.getServicesByUser(_activeEmail);
        if (mounted) {
          setState(() {
            _allServices =
                data.map((e) => PurchasedService.fromMap(e)).toList();
          });
        }
      } catch (_) {}
    };
    CloudSyncService.instance.servicesNotifier
        .addListener(_servicesRealtimeListener!);

    _initAndLoadServices();
  }

  @override
  void dispose() {
    if (_servicesRealtimeListener != null) {
      CloudSyncService.instance.servicesNotifier
          .removeListener(_servicesRealtimeListener!);
    }
    _liveSyncTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initAndLoadServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('email');
      final savedRole = prefs.getString('role');
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _activeEmail = savedEmail;
      }
      if (savedRole != null && savedRole.isNotEmpty) {
        _userRole = savedRole;
      }
    } catch (_) {}
    CloudSyncService.instance.syncAllFromCloud();
    await _loadServicesFromDB();

    // Pasang Live Sync Timer cadangan untuk Data Layanan
    _liveSyncTimer?.cancel();
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (mounted && !_isLoading) {
        try {
          await FirebaseTransactionService.instance
              .syncServicesFromFirebase(userEmail: _activeEmail);
          final data =
              await DatabaseHelper.instance.getServicesByUser(_activeEmail);
          if (mounted) {
            setState(() {
              _allServices =
                  data.map((e) => PurchasedService.fromMap(e)).toList();
            });
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _loadServicesFromDB({bool showSyncToast = false}) async {
    if (!mounted) return;

    // 1. Baca data termutakhir dari SQLite lokal terlebih dahulu (INSTAN 0ms)
    try {
      final localData = await DatabaseHelper.instance
          .getServicesByUser(_activeEmail)
          .timeout(const Duration(seconds: 3), onTimeout: () => []);
      if (mounted) {
        setState(() {
          _allServices = localData.map((e) => PurchasedService.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[DataLayananPage] Error read local: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    // 2. Sinkronkan dari Firebase di latar belakang tanpa menahan antarmuka
    try {
      await FirebaseTransactionService.instance
          .syncServicesFromFirebase(userEmail: _activeEmail)
          .timeout(const Duration(seconds: 5), onTimeout: () => 0);
      final freshData = await DatabaseHelper.instance
          .getServicesByUser(_activeEmail)
          .timeout(const Duration(seconds: 3), onTimeout: () => []);
      if (mounted) {
        setState(() {
          _allServices = freshData.map((e) => PurchasedService.fromMap(e)).toList();
          _isLoading = false;
        });

        if (showSyncToast) {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      LanguageService.text(
                        'Data layanan berhasil disinkronkan dari Firebase Realtime Database!',
                        'Services synced from Firebase Realtime Database!',
                      ),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
      }
    } catch (e) {
      debugPrint('[DataLayananPage] Cloud sync error: $e');
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<PurchasedService> _getFilteredServices(String category) {
    return _allServices.where((srv) {
      final matchesCategory = category == 'Semua' ||
          srv.kategori.toLowerCase().contains(category.toLowerCase());
      final matchesQuery = _searchQuery.isEmpty ||
          srv.namaProduk.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (srv.ipAddress?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false) ||
          (srv.serverUrl?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false) ||
          (srv.sessionId?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false) ||
          (srv.spesifikasi
                  ?.toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ??
              false);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label ${LanguageService.text("Berhasil Disalin!", "Copied Successfully!")}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    text,
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openUrl(String urlStr) async {
    final uri = Uri.tryParse(urlStr);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _copyToClipboard(urlStr, 'URL Panel');
    }
  }

  void _showQrCodeModal(PurchasedService bot) {
    int activeMode = 0; // 0: QR Code, 1: 8-Digit Pairing Code
    String currentTimestamp = DateTime.now().millisecondsSinceEpoch.toString();

    String getPairingCode() {
      if (bot.extraData != null && bot.extraData!.contains(':')) {
        return bot.extraData!.split(':').last.trim();
      }
      return 'VBWA-${bot.id != null ? (1000 + bot.id! * 37) : "8821"}';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final String qrData =
              'VIBETECH-WA-AUTH:${bot.sessionId ?? "SESSION-DEFAULT"}:$currentTimestamp';
          final String pairCode = getPairingCode();

          return Container(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(
                color: widget.isDarkMode
                    ? AppColors.emerald.withValues(alpha: 0.3)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Grabber Bar
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header with WhatsApp Theme
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF25D366)
                                    .withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.chat_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageService.text(
                                'Tautkan WhatsApp Bot',
                                'Link WhatsApp Bot',
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary,
                              ),
                            ),
                            Text(
                              bot.namaProduk,
                              style: GoogleFonts.poppins(
                                color: _textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: _textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Dual Mode Segmented Switch
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => activeMode = 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: activeMode == 0
                                  ? AppColors.emerald
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: activeMode == 0
                                  ? [
                                      BoxShadow(
                                        color: AppColors.emerald
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 16,
                                  color: activeMode == 0
                                      ? Colors.white
                                      : _textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  LanguageService.text(
                                      'Scan QR Code', 'Scan QR Code'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: activeMode == 0
                                        ? Colors.white
                                        : _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => activeMode = 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: activeMode == 1
                                  ? AppColors.emerald
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: activeMode == 1
                                  ? [
                                      BoxShadow(
                                        color: AppColors.emerald
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.pin_rounded,
                                  size: 16,
                                  color: activeMode == 1
                                      ? Colors.white
                                      : _textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  LanguageService.text(
                                      'Pairing Code', 'Pairing Code'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: activeMode == 1
                                        ? Colors.white
                                        : _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // MODE 0: QR CODE VIEW
                if (activeMode == 0) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF25D366).withValues(alpha: 0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF25D366).withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 190.0,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF0F172A),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Pulsing Live Status
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.emerald.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.emerald,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          LanguageService.text(
                            'Menunggu pemindaian WhatsApp...',
                            'Waiting for WhatsApp scan...',
                          ),
                          style: GoogleFonts.poppins(
                            color: AppColors.emerald,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Step-by-Step Pills
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.isDarkMode
                            ? const Color(0xFF334155).withValues(alpha: 0.5)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStepRow(
                            '1',
                            LanguageService.text(
                                'Buka aplikasi WhatsApp di HP Anda',
                                'Open WhatsApp on your phone')),
                        const SizedBox(height: 6),
                        _buildStepRow(
                            '2',
                            LanguageService.text(
                                'Menu Titik Tiga / Pengaturan > Perangkat Tertaut',
                                'Menu / Settings > Linked Devices')),
                        const SizedBox(height: 6),
                        _buildStepRow(
                            '3',
                            LanguageService.text(
                                'Klik "Tautkan Perangkat" & scan QR code di atas',
                                'Tap "Link a Device" and scan the QR above')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setModalState(() {
                              currentTimestamp = DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString();
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded,
                              size: 16, color: AppColors.emerald),
                          label: Text(
                            LanguageService.text('Perbarui QR', 'Refresh QR'),
                            style: GoogleFonts.poppins(
                              color: AppColors.emerald,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.emerald),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emerald,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            LanguageService.text('Selesai', 'Done'),
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // MODE 1: 8-DIGIT PAIRING CODE VIEW
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.emerald.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emerald.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          LanguageService.text(
                              'KODE TAUTAN 8-DIGIT', '8-DIGIT PAIRING CODE'),
                          style: GoogleFonts.poppins(
                            color: _textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Segmented Digit Display
                        Wrap(
                          spacing: 6,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: pairCode.split('').map((char) {
                            if (char == '-' || char == ' ') {
                              return Container(
                                width: 14,
                                height: 44,
                                alignment: Alignment.center,
                                child: Text(
                                  '-',
                                  style: GoogleFonts.spaceMono(
                                    color: AppColors.emerald,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }
                            return Container(
                              width: 34,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: widget.isDarkMode
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      AppColors.emerald.withValues(alpha: 0.6),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.emerald
                                        .withValues(alpha: 0.1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Text(
                                char,
                                style: GoogleFonts.spaceMono(
                                  color: widget.isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _copyToClipboard(pairCode, 'Pairing Code WA'),
                            icon: const Icon(Icons.copy_rounded,
                                size: 16, color: Colors.white),
                            label: Text(
                              LanguageService.text(
                                  'Salin Kode Pairing', 'Copy Pairing Code'),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Step-by-Step for Pairing Code
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.isDarkMode
                            ? const Color(0xFF334155).withValues(alpha: 0.5)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStepRow(
                            '1',
                            LanguageService.text(
                                'Buka WhatsApp > Perangkat Tertaut > Tautkan Perangkat',
                                'WhatsApp > Linked Devices > Link a Device')),
                        const SizedBox(height: 6),
                        _buildStepRow(
                            '2',
                            LanguageService.text(
                                'Pilih "Tautkan dengan nomor telepon saja"',
                                'Select "Link with phone number instead"')),
                        const SizedBox(height: 6),
                        _buildStepRow(
                            '3',
                            LanguageService.text(
                                'Ketik 8-digit kode pairing di atas',
                                'Enter the 8-digit pairing code above')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isDarkMode
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        LanguageService.text('Tutup', 'Close'),
                        style: GoogleFonts.poppins(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.emerald,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: _textSecondary,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  void _showAddServiceDialog() {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.text(
            'Akses Ditolak! Hanya Administrator yang dapat menambah data layanan manual.',
            'Access Denied! Only Administrators can add manual service data.',
          )),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    String selectedCategory = 'VPS';
    final nameCtrl = TextEditingController(text: 'VPS Ubuntu 22.04');
    final ipCtrl = TextEditingController(
        text:
            '103.187.${100 + (DateTime.now().millisecond % 150)}.${10 + (DateTime.now().second % 200)}');
    final userCtrl = TextEditingController(text: 'root');
    final passCtrl = TextEditingController(
        text:
            'Vibe#${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    final specsCtrl =
        TextEditingController(text: '2 vCPU, 4GB RAM, 50GB NVMe SSD');
    final priceCtrl = TextEditingController(text: '50000');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            LanguageService.text('Tambah Data Layanan', 'Add Service Data'),
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: _textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  dropdownColor: _cardColor,
                  isExpanded: true,
                  style: GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Kategori Layanan',
                    labelStyle: GoogleFonts.poppins(
                        color: _textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: widget.isDarkMode
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'VPS', child: Text('Data VPS')),
                    DropdownMenuItem(
                        value: 'Panel Hosting', child: Text('Panel Hosting')),
                    DropdownMenuItem(
                        value: 'Bot WhatsApp', child: Text('Bot WhatsApp')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedCategory = val;
                        if (val == 'VPS') {
                          nameCtrl.text = 'VPS Ubuntu 22.04';
                          specsCtrl.text = '2 vCPU, 4GB RAM, 50GB NVMe SSD';
                          userCtrl.text = 'root';
                        } else if (val == 'Panel Hosting') {
                          nameCtrl.text = 'Panel Pterodactyl 2GB';
                          specsCtrl.text = '2GB RAM, 1 Core CPU, 20GB Storage';
                          userCtrl.text = 'panel_client';
                        } else {
                          nameCtrl.text = 'Bot WA Multi-Device';
                          specsCtrl.text = '5 Grup, Auto-reply, Blast AI';
                          userCtrl.text = _activeEmail;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildDialogField(
                    nameCtrl, 'Nama Produk', Icons.inventory_2_rounded),
                const SizedBox(height: 12),
                if (selectedCategory == 'VPS') ...[
                  _buildDialogField(
                      ipCtrl, 'IP Address', Icons.language_rounded),
                  const SizedBox(height: 12),
                  _buildDialogField(
                      userCtrl, 'User SSH', Icons.person_outline_rounded),
                  const SizedBox(height: 12),
                  _buildDialogField(
                      passCtrl, 'Root Password', Icons.lock_outline_rounded),
                ] else if (selectedCategory == 'Panel Hosting') ...[
                  _buildDialogField(ipCtrl, 'URL Panel', Icons.link_rounded),
                  const SizedBox(height: 12),
                  _buildDialogField(
                      userCtrl, 'Username', Icons.person_outline_rounded),
                  const SizedBox(height: 12),
                  _buildDialogField(
                      passCtrl, 'Password', Icons.lock_outline_rounded),
                ] else ...[
                  _buildDialogField(
                      ipCtrl, 'Session ID', Icons.fingerprint_rounded),
                  const SizedBox(height: 12),
                  _buildDialogField(
                      passCtrl, 'Pairing Code', Icons.qr_code_scanner_rounded),
                ],
                const SizedBox(height: 12),
                _buildDialogField(
                    specsCtrl, 'Spesifikasi', Icons.memory_rounded),
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
                if (nameCtrl.text.isEmpty) return;
                final now = DateTime.now();
                await DatabaseHelper.instance.createService({
                  'user_email': _activeEmail,
                  'nama_produk': nameCtrl.text,
                  'kategori': selectedCategory,
                  'harga': double.tryParse(priceCtrl.text) ?? 50000.0,
                  'tanggal_beli': now.toIso8601String(),
                  'tanggal_kadaluarsa':
                      now.add(const Duration(days: 30)).toIso8601String(),
                  'status': 'Aktif',
                  'ip_address': selectedCategory == 'VPS' ? ipCtrl.text : null,
                  'port': selectedCategory == 'VPS'
                      ? '22'
                      : (selectedCategory == 'Panel Hosting' ? '8080' : null),
                  'username': userCtrl.text,
                  'password': passCtrl.text,
                  'server_url': selectedCategory == 'Panel Hosting'
                      ? (ipCtrl.text.startsWith('http')
                          ? ipCtrl.text
                          : 'https://panel.vibetech.xyz:8080')
                      : null,
                  'session_id':
                      selectedCategory == 'Bot WhatsApp' ? ipCtrl.text : null,
                  'spesifikasi': specsCtrl.text,
                  'extra_data': selectedCategory == 'Bot WhatsApp'
                      ? 'PAIR-CODE: ${passCtrl.text}'
                      : (selectedCategory == 'VPS'
                          ? 'OS: Ubuntu 22.04 LTS'
                          : 'Node: Singapore High-Speed'),
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadServicesFromDB();
              },
              child: Text(LanguageService.tr('simpan'),
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditServiceDialog(PurchasedService srv) {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.text(
            'Akses Ditolak! Hanya Administrator yang dapat mengubah konfigurasi layanan.',
            'Access Denied! Only Administrators can edit service configuration.',
          )),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    String selectedStatus = srv.status;
    final nameCtrl = TextEditingController(text: srv.namaProduk);
    final ipCtrl = TextEditingController(text: srv.ipAddress ?? srv.sessionId ?? srv.serverUrl ?? '');
    final userCtrl = TextEditingController(text: srv.username ?? '');
    final passCtrl = TextEditingController(text: srv.password ?? '');
    final portCtrl = TextEditingController(text: srv.port ?? '');
    final specsCtrl = TextEditingController(text: srv.spesifikasi ?? '');
    final priceCtrl = TextEditingController(text: srv.harga.toInt().toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dContext, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: AppColors.accent, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  LanguageService.text('Edit Data Layanan', 'Edit Service Data'),
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: _textPrimary, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(nameCtrl, 'Nama Layanan', Icons.inventory_2_rounded),
                const SizedBox(height: 12),
                if (srv.kategori.toLowerCase().contains('vps')) ...[
                  _buildDialogField(ipCtrl, 'IP Address', Icons.language_rounded),
                  const SizedBox(height: 12),
                  _buildDialogField(portCtrl, 'Port SSH', Icons.numbers_rounded),
                  const SizedBox(height: 12),
                  _buildDialogField(userCtrl, 'User SSH', Icons.person_outline_rounded),
                  const SizedBox(height: 12),
                  _buildDialogField(passCtrl, 'Password Root', Icons.lock_outline_rounded),
                ] else if (srv.kategori.toLowerCase().contains('panel')) ...[
                  _buildDialogField(ipCtrl, 'URL Panel', Icons.link_rounded),
                  const SizedBox(height: 12),
                  _buildDialogField(userCtrl, 'Username Panel', Icons.person_outline_rounded),
                  const SizedBox(height: 12),
                  _buildDialogField(passCtrl, 'Password Panel', Icons.lock_outline_rounded),
                ] else ...[
                  _buildDialogField(ipCtrl, 'Session ID / Pairing', Icons.fingerprint_rounded),
                  const SizedBox(height: 12),
                  _buildDialogField(passCtrl, 'Pairing Code', Icons.qr_code_scanner_rounded),
                ],
                const SizedBox(height: 12),
                _buildDialogField(specsCtrl, 'Spesifikasi / Catatan', Icons.memory_rounded),
                const SizedBox(height: 12),
                _buildDialogField(priceCtrl, 'Harga (Rp)', Icons.attach_money_rounded,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  dropdownColor: _cardColor,
                  style: GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Status Layanan',
                    labelStyle: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Aktif', child: Text('Aktif (Online)')),
                    DropdownMenuItem(value: 'Expired', child: Text('Expired (Kadaluarsa)')),
                    DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance (Perbaikan)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedStatus = val);
                    }
                  },
                ),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);

                final updatedData = {
                  'id': srv.id,
                  'user_email': srv.userEmail,
                  'nama_produk': nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : srv.namaProduk,
                  'kategori': srv.kategori,
                  'harga': double.tryParse(priceCtrl.text) ?? srv.harga,
                  'status': selectedStatus,
                  'ip_address': srv.kategori.toLowerCase().contains('vps') ? ipCtrl.text.trim() : srv.ipAddress,
                  'port': portCtrl.text.trim().isNotEmpty ? portCtrl.text.trim() : srv.port,
                  'username': userCtrl.text.trim(),
                  'password': passCtrl.text.trim(),
                  'server_url': srv.kategori.toLowerCase().contains('panel') ? ipCtrl.text.trim() : srv.serverUrl,
                  'session_id': srv.kategori.toLowerCase().contains('bot') ? ipCtrl.text.trim() : srv.sessionId,
                  'spesifikasi': specsCtrl.text.trim(),
                  'tanggal_beli': srv.tanggalBeli,
                  'tanggal_kadaluarsa': srv.tanggalKadaluarsa,
                  'extra_data': srv.extraData,
                };

                // 1. Update UI secara instan (0ms) tanpa spinner loading
                final updatedObj = PurchasedService.fromMap(updatedData);
                setState(() {
                  final idx = _allServices.indexWhere((s) =>
                      (srv.id != null && s.id == srv.id) ||
                      (s.namaProduk.toLowerCase() == srv.namaProduk.toLowerCase() &&
                          s.userEmail.toLowerCase() == srv.userEmail.toLowerCase()));
                  if (idx != -1) {
                    _allServices[idx] = updatedObj;
                  }
                });

                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      LanguageService.text(
                        'Data layanan berhasil diperbarui!',
                        'Service data updated successfully!',
                      ),
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: AppColors.emerald,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ),
                );

                // 2. Eksekusi simpan ke SQLite lokal & Firebase RTDB di latar belakang
                Future.microtask(() async {
                  try {
                    final db = await DatabaseHelper.instance.database;
                    if (srv.id != null && srv.id! > 0) {
                      await db.update('purchased_services', updatedData,
                          where: 'id = ?', whereArgs: [srv.id]);
                    }
                    await db.update(
                      'purchased_services',
                      updatedData,
                      where: 'LOWER(user_email) = ? AND LOWER(nama_produk) = ?',
                      whereArgs: [srv.userEmail.toLowerCase(), srv.namaProduk.toLowerCase()],
                    );

                    await FirebaseTransactionService.instance.updateServiceInFirebase(
                      id: srv.id ?? 0,
                      docId: srv.extraData,
                      namaProduk: srv.namaProduk,
                      userEmail: srv.userEmail,
                      updatedData: updatedData,
                    );
                  } catch (e) {
                    debugPrint('[DataLayananPage] Error edit background: $e');
                  }
                });
              },
              child: Text(LanguageService.tr('simpan'),
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(PurchasedService srv) {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.text(
            'Akses Ditolak! Hanya Administrator yang dapat menghapus data layanan.',
            'Access Denied! Only Administrators can delete service data.',
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
          LanguageService.text('Hapus Data Layanan', 'Delete Service Data'),
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: _textPrimary),
        ),
        content: Text(
          LanguageService.text('Apakah Anda yakin ingin menghapus ${srv.namaProduk}?',
              'Are you sure you want to delete ${srv.namaProduk}?'),
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
              Navigator.pop(ctx);

              // 1. Update UI seketika (0ms - kartu langsung hilang tanpa muter-muter)
              setState(() {
                _allServices.removeWhere((s) =>
                    (srv.id != null && s.id == srv.id) ||
                    (s.namaProduk.toLowerCase() == srv.namaProduk.toLowerCase() &&
                        s.userEmail.toLowerCase() == srv.userEmail.toLowerCase()));
              });

              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    LanguageService.text(
                      'Layanan ${srv.namaProduk} berhasil dihapus!',
                      'Service ${srv.namaProduk} deleted successfully!',
                    ),
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 2),
                ),
              );

              // 2. Eksekusi Hapus dari SQLite lokal & Firebase RTDB di latar belakang
              Future.microtask(() async {
                try {
                  final db = await DatabaseHelper.instance.database;
                  if (srv.id != null && srv.id! > 0) {
                    await db.delete('purchased_services',
                        where: 'id = ?', whereArgs: [srv.id]);
                  }
                  await db.delete(
                    'purchased_services',
                    where: 'LOWER(user_email) = ? AND LOWER(nama_produk) = ?',
                    whereArgs: [srv.userEmail.toLowerCase(), srv.namaProduk.toLowerCase()],
                  );

                  await FirebaseTransactionService.instance.deleteServiceFromFirebase(
                    srv.id ?? 0,
                    docId: srv.extraData,
                    namaProduk: srv.namaProduk,
                    userEmail: srv.userEmail,
                  );
                } catch (e) {
                  debugPrint('[DataLayananPage] Error delete background: $e');
                }
              });
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
          LanguageService.text(
              'Data Layanan & Kredensial', 'My Services & Credentials'),
          style: GoogleFonts.poppins(
            color: _textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: AppColors.accent),
            onPressed: () => _loadServicesFromDB(showSyncToast: true),
            tooltip: LanguageService.text('Sinkronkan dari Firebase', 'Sync from Firebase'),
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.cyan),
              onPressed: _showAddServiceDialog,
              tooltip: LanguageService.tr('tambah_layanan'),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: widget.isDarkMode ? AppColors.cyan : AppColors.primary,
          unselectedLabelColor: _textSecondary,
          indicatorColor:
              widget.isDarkMode ? AppColors.cyan : AppColors.primary,
          indicatorWeight: 3,
          labelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
          tabs: [
            Tab(text: LanguageService.text('Semua', 'All')),
            Tab(text: LanguageService.text('Data VPS', 'Data VPS')),
            Tab(text: LanguageService.text('Panel Hosting', 'Panel Hosting')),
            Tab(text: LanguageService.text('Bot WhatsApp', 'Bot WhatsApp')),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Quick Shortcut Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: LanguageService.text(
                      'Cari IP VPS, Domain Panel, Session Bot...',
                      'Search VPS IP, Panel Domain, Bot Session...',
                    ),
                    hintStyle: GoogleFonts.poppins(
                        color: _textSecondary, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.primary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: _cardColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: _textSecondary.withValues(alpha: 0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 10),

                // Quick Navigation Cards
                Row(
                  children: [
                    _buildShortcutButton(
                      title: 'VPS',
                      icon: Icons.dns_rounded,
                      color: AppColors.primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DataVpsPage(
                            isDarkMode: widget.isDarkMode,
                            userEmail: widget.userEmail,
                          ),
                        ),
                      ).then((_) => _loadServicesFromDB()),
                    ),
                    const SizedBox(width: 8),
                    _buildShortcutButton(
                      title: 'Panel',
                      icon: Icons.cloud_rounded,
                      color: AppColors.accent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DataPanelPage(
                            isDarkMode: widget.isDarkMode,
                            userEmail: widget.userEmail,
                          ),
                        ),
                      ).then((_) => _loadServicesFromDB()),
                    ),
                    const SizedBox(width: 8),
                    _buildShortcutButton(
                      title: 'Bot WA',
                      icon: Icons.chat_bubble_rounded,
                      color: AppColors.emerald,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DataBotWaPage(
                            isDarkMode: widget.isDarkMode,
                            userEmail: widget.userEmail,
                          ),
                        ),
                      ).then((_) => _loadServicesFromDB()),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Bar Views
          Expanded(
            child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildServiceListView(
                          _getFilteredServices('Semua'), 'Semua'),
                      _buildServiceListView(_getFilteredServices('VPS'), 'VPS'),
                      _buildServiceListView(
                          _getFilteredServices('Panel Hosting'),
                          'Panel Hosting'),
                      _buildServiceListView(
                          _getFilteredServices('Bot WhatsApp'), 'Bot WhatsApp'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceListView(List<PurchasedService> list, String category) {
    int catIdx = 0;
    if (category.contains('Panel')) {
      catIdx = 1;
    } else if (category.contains('Bot') || category.contains('WA')) {
      catIdx = 2;
    }

    if (list.isEmpty) {
      IconData emptyIcon = Icons.inventory_2_outlined;
      Color emptyColor = AppColors.primary;
      if (category.contains('VPS')) {
        emptyIcon = Icons.dns_outlined;
        emptyColor = AppColors.primary;
      } else if (category.contains('Panel')) {
        emptyIcon = Icons.cloud_outlined;
        emptyColor = AppColors.accent;
      } else if (category.contains('Bot') || category.contains('WA')) {
        emptyIcon = Icons.chat_bubble_outline_rounded;
        emptyColor = AppColors.emerald;
      }

      return RefreshIndicator(
        onRefresh: () => _loadServicesFromDB(showSyncToast: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.isDarkMode
                      ? emptyColor.withValues(alpha: 0.2)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: widget.isDarkMode ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: emptyColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(emptyIcon, size: 54, color: emptyColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    category == 'Semua'
                        ? LanguageService.text(
                            'Belum Ada Layanan Aktif', 'No Active Services Yet')
                        : LanguageService.text('Belum Ada Layanan $category',
                            'No $category Active Yet'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LanguageService.text(
                      'Data kredensial layanan seperti IP VPS, Domain Panel, dan QR Session Bot WA akan otomatis muncul di sini setelah Anda berhasil membeli dari Katalog Produk.',
                      'Credentials like VPS IP, Panel Domain, and Bot WA QR will automatically appear here once you complete a purchase from the Product Catalog.',
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: _textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProdukPage(
                              isDarkMode: widget.isDarkMode,
                              initialCategoryIndex: catIdx,
                            ),
                          ),
                        ).then((_) => _loadServicesFromDB());
                      },
                      icon: const Icon(Icons.shopping_bag_outlined,
                          color: Colors.white, size: 18),
                      label: Text(
                        category == 'Semua'
                            ? LanguageService.text(
                                'Beli Layanan di Katalog Produk',
                                'Buy Services from Catalog')
                            : LanguageService.text(
                                'Beli $category di Produk Page',
                                'Buy $category from Product Page'),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: emptyColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _showAddServiceDialog,
                      icon: Icon(Icons.add_circle_outline_rounded,
                          color: _textSecondary, size: 16),
                      label: Text(
                        LanguageService.text('Atau Tambah Kredensial Manual',
                            'Or Add Credentials Manually'),
                        style: GoogleFonts.poppins(
                          color: _textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _buildCategoryGuide(category),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadServicesFromDB(showSyncToast: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: list.length + 1,
        itemBuilder: (context, index) {
          if (index < list.length) {
            final srv = list[index];
            return _buildUniversalServiceCard(srv);
          }
          return _buildCategoryGuide(category);
        },
      ),
    );
  }

  Widget _buildCategoryGuide(String category) {
    final bool showVps = category == 'Semua' || category.contains('VPS');
    final bool showPanel = category == 'Semua' || category.contains('Panel');
    final bool showBot = category == 'Semua' ||
        category.contains('Bot') ||
        category.contains('WA');

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDarkMode
              ? const Color(0xFF334155).withValues(alpha: 0.4)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: category != 'Semua',
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.menu_book_rounded,
                color: AppColors.primary, size: 20),
          ),
          title: Text(
            category == 'Semua'
                ? LanguageService.text('Panduan & Tutorial Semua Layanan',
                    'All Services User Guides')
                : LanguageService.text(
                    'Panduan & Tutorial $category', '$category User Guide'),
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            LanguageService.text('Langkah-langkah koneksi & konfigurasi',
                'Connection & setup step-by-step'),
            style: GoogleFonts.poppins(color: _textSecondary, fontSize: 11),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  if (showVps) ...[
                    _buildGuideItem(
                      icon: Icons.dns_rounded,
                      color: AppColors.primary,
                      title: 'Panduan Akses & Koneksi VPS (SSH)',
                      steps: [
                        'Catat IP Address, Port SSH (22), dan Password Root VPS di kartu atas.',
                        'Buka Terminal di Windows (PowerShell/CMD), Mac, atau aplikasi PuTTY.',
                        'Ketik perintah: ssh root@<IP_VPS> (Ganti <IP_VPS> dengan IP Anda).',
                        'Masukkan Password Root yang tertera (teks password tidak akan muncul saat diketik, ini normal).',
                        'Setelah berhasil login, perbarui sistem dengan: apt update && apt upgrade -y',
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (showPanel) ...[
                    _buildGuideItem(
                      icon: Icons.cloud_rounded,
                      color: AppColors.accent,
                      title:
                          'Panduan Akses & Manajemen Panel Hosting (Pterodactyl)',
                      steps: [
                        'Klik tombol "Buka Panel" di kartu panel Anda untuk menuju web portal.',
                        'Masukkan Username dan Password Panel yang tercantum pada kartu kredensial.',
                        'Pilih server Anda di halaman utama Console untuk melihat resource CPU & RAM.',
                        'Gunakan menu "File Manager" untuk mengunggah file bot atau source code.',
                        'Klik tombol "Start" di console untuk menyalakan server atau bot Anda.',
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (showBot) ...[
                    _buildGuideItem(
                      icon: Icons.chat_bubble_rounded,
                      color: AppColors.emerald,
                      title:
                          'Panduan Menghubungkan Bot WhatsApp (Scan QR / Pairing Code)',
                      steps: [
                        'Buka WhatsApp di HP Anda > Menu Titik Tiga (Android) / Pengaturan (iOS).',
                        'Pilih "Perangkat Tertaut (Linked Devices)" > "Tautkan Perangkat".',
                        'Klik tombol "Scan QR Code Autentikasi" di kartu di atas dan arahkan kamera HP ke QR Code, ATAU',
                        'Pilih "Tautkan dengan nomor telepon" di WA lalu masukkan Pairing Code 8-digit yang tersedia.',
                        'Bot WhatsApp Anda akan aktif 24/7 dan merespons pesan secara otomatis.',
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideItem({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> steps,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...steps.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key + 1}. ',
                    style: GoogleFonts.poppins(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: GoogleFonts.poppins(
                        color: _textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUniversalServiceCard(PurchasedService srv) {
    final bool isVps = srv.kategori.toLowerCase().contains('vps');
    final bool isPanel = srv.kategori.toLowerCase().contains('panel') ||
        srv.kategori.toLowerCase().contains('hosting');
    final bool isBot = srv.kategori.toLowerCase().contains('bot') ||
        srv.kategori.toLowerCase().contains('wa');

    Color themeColor = AppColors.primary;
    IconData categoryIcon = Icons.dns_rounded;
    if (isPanel) {
      themeColor = AppColors.accent;
      categoryIcon = Icons.cloud_rounded;
    } else if (isBot) {
      themeColor = AppColors.emerald;
      categoryIcon = Icons.chat_bubble_rounded;
    }

    final bool showPass = _showPasswordMap[srv.id ?? 0] ?? false;
    final int daysLeft = srv.daysRemaining;
    Color timerColor = AppColors.success;
    if (daysLeft < 7) {
      timerColor = AppColors.error;
    } else if (daysLeft < 14) {
      timerColor = AppColors.warning;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDarkMode
              ? themeColor.withValues(alpha: 0.25)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: widget.isDarkMode ? 0.25 : 0.04),
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
              color: themeColor.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(categoryIcon, color: themeColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        srv.namaProduk,
                        style: GoogleFonts.poppins(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        srv.spesifikasi ?? 'Standard Specification',
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
                        srv.status,
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

          // Credentials Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isVps) ...[
                  // VPS View
                  _buildCredentialRow(
                    label: 'IP Server',
                    value: srv.ipAddress ?? '103.187.142.88',
                    icon: Icons.language_rounded,
                    color: themeColor,
                    onCopy: () =>
                        _copyToClipboard(srv.ipAddress ?? '', 'IP Address VPS'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCredentialRow(
                          label: 'Port SSH',
                          value: srv.port ?? '22',
                          icon: Icons.tag_rounded,
                          color: themeColor,
                          onCopy: () =>
                              _copyToClipboard(srv.port ?? '22', 'Port SSH'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCredentialRow(
                          label: 'User SSH',
                          value: srv.username ?? 'root',
                          icon: Icons.person_outline_rounded,
                          color: themeColor,
                          onCopy: () => _copyToClipboard(
                              srv.username ?? 'root', 'Username SSH'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildCredentialRow(
                    label: 'Root Password',
                    value: showPass
                        ? (srv.password ?? 'vps_pass#2026')
                        : '••••••••••••',
                    icon: Icons.key_rounded,
                    color: themeColor,
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
                          _showPasswordMap[srv.id ?? 0] = !showPass;
                        });
                      },
                    ),
                    onCopy: () => _copyToClipboard(
                        srv.password ?? '', 'Password Root VPS'),
                  ),
                  const SizedBox(height: 10),
                  _buildSshCommandBox(
                      'ssh ${srv.username ?? "root"}@${srv.ipAddress ?? "127.0.0.1"}'),
                ] else if (isPanel) ...[
                  // Panel Hosting View
                  _buildPanelUrlBox(
                      srv.serverUrl ?? 'https://panel.vibetech.xyz:8080'),
                  const SizedBox(height: 10),
                  _buildCredentialRow(
                    label: 'Username',
                    value: srv.username ?? 'client_demouser',
                    icon: Icons.person_outline_rounded,
                    color: themeColor,
                    onCopy: () => _copyToClipboard(
                        srv.username ?? 'client_demouser', 'Username Panel'),
                  ),
                  const SizedBox(height: 10),
                  _buildCredentialRow(
                    label: 'Password Panel',
                    value: showPass
                        ? (srv.password ?? 'panel_pass#2026')
                        : '••••••••••••',
                    icon: Icons.key_rounded,
                    color: themeColor,
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
                          _showPasswordMap[srv.id ?? 0] = !showPass;
                        });
                      },
                    ),
                    onCopy: () => _copyToClipboard(
                        srv.password ?? '', 'Password Panel Hosting'),
                  ),
                ] else ...[
                  // Bot WhatsApp View
                  _buildCredentialRow(
                    label: 'Session ID',
                    value: srv.sessionId ?? 'WA-SESSION-VB7721',
                    icon: Icons.fingerprint_rounded,
                    color: themeColor,
                    onCopy: () => _copyToClipboard(
                        srv.sessionId ?? '', 'Session ID Bot WA'),
                  ),
                  const SizedBox(height: 10),
                  _buildPairingCodeBox(srv.extraData ?? 'PAIR-CODE: VBWA-8821'),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showQrCodeModal(srv),
                      icon: const Icon(Icons.qr_code_2_rounded,
                          color: AppColors.emerald, size: 18),
                      label: Text(
                        LanguageService.text('Scan QR Code Autentikasi',
                            'Scan Authentication QR Code'),
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
                ],
                const SizedBox(height: 14),

                // Card Footer: Expiry & Price & Delete
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
                          'Rp ${NumberFormat('#,###', 'id_ID').format(srv.harga).replaceAll(',', '.')}',
                          style: GoogleFonts.poppins(
                            color: widget.isDarkMode
                                ? AppColors.cyan
                                : AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (_isAdmin) ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: AppColors.accent, size: 20),
                            onPressed: () => _showEditServiceDialog(srv),
                            tooltip: LanguageService.text('Edit Layanan', 'Edit Service'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AppColors.error, size: 20),
                            onPressed: () => _showDeleteConfirmDialog(srv),
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
    required Color color,
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
          Icon(icon, color: color, size: 16),
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

  Widget _buildSshCommandBox(String sshCommand) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF070B14)
            : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDarkMode
              ? AppColors.cyan.withValues(alpha: 0.35)
              : const Color(0xFF334155),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Terminal Title Bar with 3 Dots
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Color(0xFFEF4444), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Text(
                      'Terminal SSH (Port 22)',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _copyToClipboard(sshCommand, 'Perintah SSH'),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.copy_rounded,
                            color: AppColors.cyan, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          LanguageService.text('Salin', 'Copy'),
                          style: GoogleFonts.poppins(
                            color: AppColors.cyan,
                            fontSize: 10.5,
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
          // Command Text
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                const Text(
                  '\$ ',
                  style: TextStyle(
                    color: AppColors.emerald,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Expanded(
                  child: Text(
                    sshCommand,
                    style: GoogleFonts.spaceMono(
                      color: AppColors.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelUrlBox(String panelUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF0F1426)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDarkMode
              ? AppColors.accent.withValues(alpha: 0.35)
              : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.language_rounded,
                color: AppColors.accent, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Web Panel Pterodactyl',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  panelUrl,
                  style: GoogleFonts.spaceMono(
                    color: widget.isDarkMode
                        ? AppColors.accent
                        : const Color(0xFF9333EA),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _openUrl(panelUrl),
            icon: const Icon(Icons.open_in_new_rounded,
                size: 13, color: Colors.white),
            label: Text(
              LanguageService.text('Buka', 'Open'),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairingCodeBox(String extra) {
    String pairingCode = 'VBWA-8821';
    if (extra.contains(':')) {
      pairingCode = extra.split(':').last.trim();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF0A1820)
            : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDarkMode
              ? AppColors.emerald.withValues(alpha: 0.35)
              : const Color(0xFF86EFAC),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded,
                color: AppColors.emerald, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LanguageService.text(
                      'Pairing Code 8-Digit', '8-Digit Pairing Code'),
                  style:
                      GoogleFonts.poppins(color: _textSecondary, fontSize: 10),
                ),
                Text(
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
              ],
            ),
          ),
          InkWell(
            onTap: () => _copyToClipboard(pairingCode, 'Pairing Code WA'),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy_rounded,
                      color: AppColors.emerald, size: 13),
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
    );
  }
}
