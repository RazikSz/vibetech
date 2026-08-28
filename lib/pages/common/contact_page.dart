import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibetech_xyz/constants/constants.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/pages/common/live_chat_page.dart';
import 'package:vibetech_xyz/services/firebase_email_service.dart';
import 'package:vibetech_xyz/services/notification_service.dart';

/// ============================================================================
/// HALAMAN HUBUNGI KAMI & SUPPORT RESMI (CONTACT PAGE) - VIBETECH XYZ
/// ============================================================================
/// Halaman pusat bantuan langsung untuk pengguna:
/// 1. Tautan langsung ke WhatsApp Resmi Raziek (+62 878-8587-3325 / wa.me/6287885873325).
/// 2. Integrasi Live Chat Asisten AI Furina Theatrical Assistant.
/// 3. Form pengiriman pesan tiket bantuan teknis dan billing support.
/// 4. Informasi saluran resmi: Email support@vibetech.xyz & website vibetech.xyz.
class ContactPage extends StatefulWidget {
  final bool isDarkMode;
  const ContactPage({super.key, this.isDarkMode = true});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  late AnimationController _animController;
  late AnimationController _particleController;
  final List<AppParticle> _particles = [];
  final math.Random _random = math.Random();

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadUserDefaultData();
    // Inisialisasi Partikel Cyber Ambient (Dark Mode)
    _particles.addAll(AppParticle.generateList(_random, count: 20));
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _particleController.addListener(() {
      AppParticle.updatePositions(_particles);
    });

    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _animController.forward();
  }

  Future<void> _loadUserDefaultData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('username') ?? '';
      final email = prefs.getString('email') ?? '';
      if (mounted) {
        setState(() {
          if (_nameController.text.isEmpty && name.isNotEmpty) {
            _nameController.text = name;
          }
          if (_emailController.text.isEmpty && email.contains('@')) {
            _emailController.text = email;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _particleController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    _animController.dispose();
    super.dispose();
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

  Widget _buildStaggeredItem(Widget child, int index) {
    final start = (index * 0.1).clamp(0.0, 1.0);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
        parent: _animController,
        curve: Interval(start, end, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(animation),
        child: child,
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate() || _isSending) return;

    final String senderName = _nameController.text.trim();
    final String senderEmail = _emailController.text.trim();
    final String subjectText = _subjectController.text.trim();
    final String messageText = _messageController.text.trim();
    final String ticketId =
        '#TKT-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final String formattedDate =
        DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now());

    setState(() => _isSending = true);

    try {
      // 1. Cari Alamat Email Owner / Administrator (dari SQLite DB / User Admin)
      final prefs = await SharedPreferences.getInstance();
      String ownerEmail =
          prefs.getString('smtp_user') ?? 'vibetech.official.xyz@gmail.com';

      try {
        final emailConfig = await FirebaseEmailService.instance.getEmailSettings() ??
            await DatabaseHelper.instance.getEmailSettings();
        if (emailConfig != null &&
            emailConfig['smtp_user'] != null &&
            emailConfig['smtp_user'].toString().contains('@')) {
          ownerEmail = emailConfig['smtp_user'].toString();
        } else {
          final allUsers = await DatabaseHelper.instance.getAllUsers();
          for (var u in allUsers) {
            final role = (u['role'] ?? '').toString().toLowerCase();
            if ((role == 'admin' || role == 'administrator') &&
                u['email'] != null &&
                u['email'].toString().contains('@')) {
              ownerEmail = u['email'].toString();
              break;
            }
          }
        }
      } catch (_) {}

      if (!mounted) return;

      // 1.5. Simpan Tiket Bantuan ke SQLite Database
      try {
        await DatabaseHelper.instance.createSupportTicket({
          'ticket_no': ticketId,
          'user_name': senderName,
          'user_email': senderEmail,
          'subject': subjectText,
          'message': messageText,
          'status': 'Open',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error saving support ticket to DB: $e');
      }

      if (!mounted) return;

      // 2. Kirim Email Langsung ke Owner Aplikasi
      NotificationService.sendEmailNotification(
        context,
        toEmail: ownerEmail,
        subject: '[Pesan Tiket Bantuan $ticketId] $subjectText',
        message:
            'Halo Administrator/Owner VibeTech XYZ,\n\nAnda menerima pesan tiket bantuan baru dari aplikasi:\n\nNomor Tiket: $ticketId\nNama Pengirim: $senderName\nEmail Pengirim: $senderEmail\nSubjek: $subjectText\nWaktu: $formattedDate WIB\n\nIsi Pesan:\n"$messageText"\n\nSilakan tindak lanjuti pesan ini melalui email pengirim ($senderEmail).',
        category: 'Pesan Tiket Support',
        orderId: ticketId,
        showPopupImmediately: false,
      );

      // 3. Kirim Email Konfirmasi Auto-Responder ke Pengguna (Member)
      if (senderEmail != ownerEmail && mounted) {
        NotificationService.sendEmailNotification(
          context,
          toEmail: senderEmail,
          subject: 'Tiket Bantuan $ticketId Diterima: $subjectText',
          message:
              'Halo $senderName,\n\nTerima kasih telah menghubungi kami. Tiket bantuan Anda telah kami terima dan otomatis diteruskan ke email Owner & Tim Support VibeTech XYZ ($ownerEmail).\n\nDetail Tiket:\nNomor Tiket: $ticketId\nSubjek: $subjectText\nWaktu: $formattedDate WIB\n\nTim kami akan segera menghubungi Anda kembali melalui email ini.',
          category: 'Konfirmasi Tiket',
          orderId: ticketId,
          showPopupImmediately: false,
        );
      }

      // 4. Tampilkan Push Notification Banner di Layar
      if (mounted) {
        NotificationService.showInAppNotification(
          context,
          title: 'Pesan Terkirim ke Owner! 📨',
          message:
              'Tiket $ticketId berhasil diteruskan ke email Owner ($ownerEmail).',
          type: 'success',
        );
      }

      if (mounted) {
        setState(() => _isSending = false);
        _showSuccessDialog(ticketId, ownerEmail, senderName, senderEmail,
            subjectText, messageText);
        _subjectController.clear();
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim pesan: $e',
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(
      String ticketId,
      String ownerEmail,
      String senderName,
      String senderEmail,
      String subjectText,
      String messageText) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pesan Berhasil Terkirim!',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pesan bantuan Anda telah otomatis dikirimkan ke email Owner VibeTech XYZ ($ownerEmail) dan bukti tiket telah dikirim ke $senderEmail.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _textSecondary.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ID Tiket Bantuan:',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: _textSecondary)),
                  Text(ticketId,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () {
                  NotificationService.openExternalEmailApp(
                    toEmail: ownerEmail,
                    subject: '[Tiket $ticketId] $subjectText',
                    body:
                        'Halo Owner VibeTech XYZ,\n\nNama: $senderName\nEmail: $senderEmail\nPesan:\n$messageText',
                  );
                },
                icon: const Icon(Icons.email_outlined,
                    size: 16, color: AppColors.primary),
                label: Text(
                  'Buka di Aplikasi Gmail / Mail',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Selesai',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsApp() async {
    final Uri waUrl = Uri.parse(
        "https://wa.me/6287885873325?text=${Uri.encodeComponent('Halo Tim VibeTech, saya butuh bantuan.')}");
    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gagal membuka WhatsApp'),
          backgroundColor: Colors.red));
    }
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
        title: Text('Hubungi Kami',
            style: GoogleFonts.poppins(
                color: _textPrimary, fontWeight: FontWeight.bold)),
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
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStaggeredItem(
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8))
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pusat Bantuan',
                                    style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                const SizedBox(height: 6),
                                Text('Tim VibeTech siap membantu Anda 24/7.',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white
                                            .withValues(alpha: 0.8))),
                              ],
                            ),
                          ),
                          const Icon(Icons.support_agent_rounded,
                              size: 50, color: Colors.white),
                        ],
                      ),
                    ),
                    0),
                const SizedBox(height: 24),
                _buildStaggeredItem(
                    Text('Kontak Cepat',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary)),
                    1),
                const SizedBox(height: 12),
                _buildStaggeredItem(
                    Row(
                      children: [
                        Expanded(
                            child: _buildContactCard(
                                Icons.chat_bubble_rounded,
                                'Live Chat',
                                'Respon AI',
                                const Color(0xFFE040FB),
                                () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => LiveChatPage(
                                            isDarkMode: widget.isDarkMode))))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildContactCard(
                                Icons.phone_android_rounded,
                                'WhatsApp',
                                '0878-8587-3325',
                                const Color(0xFF00E676),
                                _launchWhatsApp)),
                      ],
                    ),
                    2),
                const SizedBox(height: 32),
                _buildStaggeredItem(
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: _textSecondary.withValues(alpha: 0.05)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tinggalkan Pesan',
                                style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _textPrimary)),
                            const SizedBox(height: 20),
                            _buildTextField(_nameController, 'Nama Lengkap',
                                Icons.person_rounded, widget.isDarkMode),
                            const SizedBox(height: 16),
                            _buildTextField(_emailController, 'Email',
                                Icons.email_rounded, widget.isDarkMode),
                            const SizedBox(height: 16),
                            _buildTextField(_subjectController, 'Subjek',
                                Icons.subject_rounded, widget.isDarkMode),
                            const SizedBox(height: 16),
                            _buildTextField(_messageController, 'Pesan Anda',
                                Icons.message_rounded, widget.isDarkMode,
                                maxLines: 4),
                            const SizedBox(height: 24),
                            BounceTap(
                              onTap: () {
                                HapticFeedback.heavyImpact();
                                _sendMessage();
                              },
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(16)),
                                child: Center(
                                  child: _isSending
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Text(
                                          'Kirim Pesan ke Owner',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    3),
                const SizedBox(height: 24),
                _buildStaggeredItem(
                    Center(
                      child: Column(
                        children: [
                          Text('VibeTech XYZ Support Official',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _textSecondary)),
                          const SizedBox(height: 4),
                          Text('support@vibetech.xyz • www.vibetech.xyz',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color:
                                      _textSecondary.withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                    4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(IconData icon, String title, String subtitle,
      Color color, VoidCallback onTap) {
    return BounceTap(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 12),
            Text(title,
                style: GoogleFonts.poppins(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            Text(subtitle,
                style: GoogleFonts.poppins(color: _textSecondary, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      IconData icon, bool isDark,
      {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: _textPrimary, fontSize: 14),
      validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
        prefixIcon: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Icon(icon, color: AppColors.primary, size: 20)),
        filled: true,
        fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red)),
      ),
    );
  }
}
