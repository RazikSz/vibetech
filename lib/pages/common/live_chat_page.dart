import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:vibetech_xyz/constants/constants.dart';
import 'package:vibetech_xyz/models/support_ticket_model.dart';
import 'package:vibetech_xyz/services/ai_chat_service.dart';
import 'package:vibetech_xyz/services/firebase_ticket_service.dart';

/// ============================================================================
/// HALAMAN LIVE CHAT & TIKET BANTUAN (LIVE CHAT & HELPDESK SUPPORT SYSTEM)
/// ============================================================================
/// Menyediakan 2 Modul Terintegrasi:
/// 1. Asisten AI Diva Furina bertema panggung teater mewah (Google Gemini).
/// 2. Sistem Tiket Bantuan Terstruktur (Helpdesk):
///    - Kategori: Billing, Teknis Server, Request Fitur Bot WA, Gangguan Jaringan.
///    - Status: Open (Kuning), In Progress (Biru), Resolved (Hijau).
///    - Sinkronisasi ganda SQLite Lokal & Firebase Realtime Database (/support_tickets).
class LiveChatPage extends StatefulWidget {
  final bool isDarkMode;
  final String? userEmail;

  const LiveChatPage({
    super.key,
    required this.isDarkMode,
    this.userEmail,
  });

  @override
  State<LiveChatPage> createState() => _LiveChatPageState();
}

class _LiveChatPageState extends State<LiveChatPage>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiChatService _aiService = AiChatService();

  // Tab State: 0 = Chat Furina AI, 1 = Tiket Bantuan (Helpdesk)
  int _selectedTabIndex = 0;

  // Filter Tiket State
  String _ticketStatusFilter = 'Semua';
  String _ticketCategoryFilter = 'Semua';
  List<SupportTicket> _userTickets = [];
  bool _isLoadingTickets = false;
  VoidCallback? _ticketListener;

  bool _isGenerating = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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

  final List<Map<String, dynamic>> _messages = [];

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

    _initPulseAnimation();
    _loadInitialWelcomeMessage();

    // Memuat tiket bantuan dari SQLite dan mendengarkan event Firebase RTDB
    _loadUserTickets();
    _ticketListener = () {
      if (mounted) _loadUserTickets();
    };
    FirebaseTicketService.instance.ticketsUpdateNotifier
        .addListener(_ticketListener!);
  }

  void _initPulseAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _loadInitialWelcomeMessage() {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    _messages.add({
      'text': '🎭 *Selamat datang di Panggung Kemegahan VibeTech XYZ!* ✨\n\n'
          'Aku adalah **Furina**, Diva Teater Teragung sekaligus Asisten AI resmi Anda yang disutradarai oleh sang maestro **Raziek**.\n\n'
          'Ada yang ingin Anda tanyakan seputar **Cloud VPS**, **Panel Hosting Pterodactyl**, atau **Sewa Bot WhatsApp**? '
          'Atau ingin melaporkan kendala teknis? Anda juga bisa membuka tab **Tiket Bantuan** di atas untuk terhubung langsung dengan teknisi kami!',
      'isUser': false,
      'time': timeStr,
    });
  }

  @override
  void dispose() {
    if (_ticketListener != null) {
      FirebaseTicketService.instance.ticketsUpdateNotifier
          .removeListener(_ticketListener!);
    }
    _particleController.dispose();
    _pulseController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================================
  // LOGIKA TIKET BANTUAN (HELPDESK CUSTOMER SUPPORT)
  // ============================================================================

  Future<void> _loadUserTickets() async {
    final email = widget.userEmail ?? 'user@vibetech.com';
    setState(() => _isLoadingTickets = true);
    try {
      final list =
          await FirebaseTicketService.instance.getTicketsByUser(email);
      if (mounted) {
        setState(() {
          _userTickets = list;
          _isLoadingTickets = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTickets = false);
    }
  }

  void _showCreateTicketModal() {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String selectedCategory = 'Billing & Pembayaran';
    String selectedPriority = 'Normal';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.add_comment_rounded,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Buat Tiket Bantuan Baru',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Pilihan Kategori Masalah
                Text(
                  'Kategori Bantuan',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isDarkMode
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: _cardColor,
                      value: selectedCategory,
                      items: [
                        'Billing & Pembayaran',
                        'Teknis Server (VPS/Panel)',
                        'Request Fitur Bot WA',
                        'Gangguan Jaringan & Downtime',
                      ].map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat,
                              style: GoogleFonts.poppins(
                                  color: _textPrimary, fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedCategory = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Pilihan Prioritas
                Text(
                  'Tingkat Prioritas',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: ['Normal', 'Tinggi (High)', 'Kritis / Urgent'].map((p) {
                    final isSel = selectedPriority == p;
                    Color color = AppColors.primary;
                    if (p.contains('Tinggi')) color = AppColors.warning;
                    if (p.contains('Kritis')) color = AppColors.error;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p,
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: isSel ? Colors.white : _textSecondary,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                        selected: isSel,
                        selectedColor: color,
                        backgroundColor: _bgColor,
                        onSelected: (val) {
                          setModalState(() => selectedPriority = p);
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // Subjek Kendala
                Text(
                  'Subjek Kendala',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: subjectCtrl,
                  style: GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Contoh: Kendala akses SSH pada VPS Starter',
                    hintStyle: GoogleFonts.poppins(color: _textSecondary, fontSize: 12),
                    filled: true,
                    fillColor: _bgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Pesan & Detail Masalah
                Text(
                  'Detail Keluhan / Pesan',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: messageCtrl,
                  maxLines: 4,
                  style: GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        'Jelaskan kendala teknis atau pertanyaan secara spesifik...',
                    hintStyle: GoogleFonts.poppins(color: _textSecondary, fontSize: 12),
                    filled: true,
                    fillColor: _bgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 18),

                // Tombol Submit
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (subjectCtrl.text.trim().isEmpty ||
                                messageCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Harap lengkapi subjek dan detail keluhan!'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }

                            setModalState(() => isSubmitting = true);
                            HapticFeedback.mediumImpact();

                            final email = widget.userEmail ?? 'user@vibetech.com';
                            final ticket = await FirebaseTicketService.instance.createTicket(
                              userName: email.split('@').first,
                              userEmail: email,
                              category: selectedCategory,
                              priority: selectedPriority,
                              subject: subjectCtrl.text.trim(),
                              message: messageCtrl.text.trim(),
                            );

                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Tiket ${ticket.ticketNo} berhasil dikirim dan tersinkronkan ke Firebase Realtime Database!',
                                ),
                                backgroundColor: AppColors.emerald,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );

                            _loadUserTickets();
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Kirim Tiket Bantuan',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTicketDetailModal(SupportTicket ticket) {
    Color statusColor = AppColors.warning;
    if (ticket.isInProgress) {
      statusColor = AppColors.cyan;
    } else if (ticket.isResolved) {
      statusColor = AppColors.emerald;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      ticket.status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    ticket.ticketNo,
                    style: GoogleFonts.jetBrainsMono(
                      color: _textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                ticket.subject,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kategori: ${ticket.category} • Prioritas: ${ticket.priority}',
                style: GoogleFonts.poppins(fontSize: 11.5, color: _textSecondary),
              ),
              const SizedBox(height: 14),

              // Detail Pesan Pengguna
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isDarkMode
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keluhan / Pesan Anda:',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: _textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ticket.message,
                      style: GoogleFonts.poppins(fontSize: 13, color: _textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Tanggapan Resmi VibeTech Support
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_rounded,
                            size: 16, color: AppColors.cyan),
                        const SizedBox(width: 6),
                        Text(
                          'Tanggapan Resmi Tim Support VibeTech:',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.cyan,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ticket.response ??
                          'Tim teknisi kami sedang menganalisis server dan log Anda. Kami akan memperbarui status secepatnya.',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: _textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Tombol Tandai Selesai jika belum resolved
              if (!ticket.isResolved)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await FirebaseTicketService.instance.updateTicketStatus(
                        ticket.ticketNo,
                        'Resolved',
                        adminResponse: 'Kendala telah dikonfirmasi selesai oleh pengguna.',
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tiket berhasil ditandai Selesai (Resolved)!'),
                          backgroundColor: AppColors.emerald,
                        ),
                      );
                      _loadUserTickets();
                    },
                    icon: const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 18),
                    label: Text(
                      'Tandai Tiket Sudah Terselesaikan',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // LOGIKA CHAT FURINA AI (THEATRICAL ASSISTANT)
  // ============================================================================

  Future<void> _sendMessage([String? presetText]) async {
    final rawText = presetText ?? _messageController.text;
    final userText = rawText.trim();
    if (userText.isEmpty || _isGenerating) return;

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _messages.add({
        'text': userText,
        'isUser': true,
        'time': timeStr,
      });
      if (presetText == null) {
        _messageController.clear();
      }
      _isGenerating = true;
    });

    _scrollToBottom();
    HapticFeedback.lightImpact();

    try {
      final reply = await _aiService.sendMessage(
        userText,
        userEmail: widget.userEmail,
      );

      if (mounted) {
        final replyTime = DateTime.now();
        final replyTimeStr =
            '${replyTime.hour.toString().padLeft(2, '0')}:${replyTime.minute.toString().padLeft(2, '0')}';

        setState(() {
          _messages.add({
            'text': reply,
            'isUser': false,
            'time': replyTimeStr,
          });
          _isGenerating = false;
        });
        _scrollToBottom();
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'text':
                'Aiya! Ada sedikit kesalahan teknis di atas panggung! Sutradara ${AiChatService.director} harus segera memeriksa koneksinya! ✨',
            'isUser': false,
            'time': timeStr,
          });
          _isGenerating = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Naskah berhasil disalin ke papan klip!',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showResetSessionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.theater_comedy, color: AppColors.accent, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mulai Babak Baru?',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Ini akan mengosongkan riwayat percakapan panggung dengan Furina AI dan memulai sesi dialog baru.',
          style: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: _textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _aiService.resetSession(userEmail: widget.userEmail);
              setState(() {
                _messages.clear();
                _loadInitialWelcomeMessage();
              });
              HapticFeedback.mediumImpact();
            },
            child: Text(
              'Mulai Ulang',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCharacterInfoModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(ctx).padding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      AiChatService.furinaAvatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.theater_comedy,
                        size: 38,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Furina AI ✨',
                  style: GoogleFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Theatrical Grand Diva & VibeTech Mastermind',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.movie_creation_outlined,
                        'Sutradara & Pencipta',
                        AiChatService.director,
                      ),
                      const Divider(height: 20),
                      _buildInfoRow(
                        Icons.cloud_queue_rounded,
                        'Platform Resmi',
                        'VibeTech XYZ Infrastructure',
                      ),
                      const Divider(height: 20),
                      _buildInfoRow(
                        Icons.cake_outlined,
                        'Kesenangan Khusus',
                        'Dessert Manis & Tepuk Tangan',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Tutup & Lanjutkan Pertunjukan',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String val) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: _textSecondary,
                ),
              ),
              Text(
                val,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // BUILD METHOD UTAMA (TAB SYSTEM: FURINA AI VS TIKET BANTUAN)
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        iconTheme: IconThemeData(color: _textPrimary),
        titleSpacing: 0,
        title: InkWell(
          onTap: _showCharacterInfoModal,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: ClipOval(
                      child: Image.network(
                        AiChatService.furinaAvatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.theater_comedy,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _selectedTabIndex == 0
                                  ? 'Furina AI Assistant'
                                  : 'Helpdesk & Tiket Bantuan',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              size: 14, color: AppColors.cyan),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.emerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _selectedTabIndex == 0
                                  ? 'Diva Panggung Siap Membantu 24/7'
                                  : 'Sistem Terhubung ke Cloud RTDB',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.emerald,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (_selectedTabIndex == 0) ...[
            IconButton(
              tooltip: 'Profil Karakter',
              icon: const Icon(Icons.info_outline_rounded, size: 22),
              onPressed: _showCharacterInfoModal,
            ),
            IconButton(
              tooltip: 'Mulai Babak Baru',
              icon: const Icon(Icons.refresh_rounded, size: 22),
              onPressed: _showResetSessionDialog,
            ),
          ] else ...[
            IconButton(
              tooltip: 'Refresh Tiket',
              icon: const Icon(Icons.sync_rounded, size: 22, color: AppColors.cyan),
              onPressed: () {
                _loadUserTickets();
                FirebaseTicketService.instance.syncTicketsFromFirebase(
                    userEmail: widget.userEmail);
              },
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: _selectedTabIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _showCreateTicketModal,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
              label: Text(
                'Buat Tiket Baru',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
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
          Column(
            children: [
              // Segmented Tab Switcher (Chat AI vs Tiket Bantuan)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isDarkMode
                        ? AppColors.primary.withValues(alpha: 0.25)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSegmentButton(
                        title: '🎭 Chat Furina AI',
                        isSelected: _selectedTabIndex == 0,
                        onTap: () => setState(() => _selectedTabIndex = 0),
                      ),
                    ),
                    Expanded(
                      child: _buildSegmentButton(
                        title: '🎫 Tiket Bantuan',
                        isSelected: _selectedTabIndex == 1,
                        badgeCount: _userTickets
                            .where((t) => t.isOpen || t.isInProgress)
                            .length,
                        onTap: () {
                          setState(() => _selectedTabIndex = 1);
                          _loadUserTickets();
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Konten Sesuai Tab Terpilih
              Expanded(
                child: _selectedTabIndex == 0
                    ? _buildChatBody()
                    : _buildHelpdeskBody(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : _textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : AppColors.warning,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: GoogleFonts.poppins(
                    color: isSelected ? AppColors.primary : Colors.black87,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // HELPDESK BODY (DAFTAR TIKET & STATISTIK)
  // ============================================================================

  Widget _buildHelpdeskBody() {
    final filteredTickets = _userTickets.where((t) {
      if (_ticketStatusFilter != 'Semua' &&
          t.status.toLowerCase() != _ticketStatusFilter.toLowerCase()) {
        return false;
      }
      if (_ticketCategoryFilter != 'Semua' &&
          !t.category.toLowerCase().contains(_ticketCategoryFilter.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    final totalCount = _userTickets.length;
    final openCount = _userTickets.where((t) => t.isOpen).length;
    final inProgressCount = _userTickets.where((t) => t.isInProgress).length;
    final resolvedCount = _userTickets.where((t) => t.isResolved).length;

    return RefreshIndicator(
      onRefresh: () => FirebaseTicketService.instance
          .syncTicketsFromFirebase(userEmail: widget.userEmail),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
        children: [
          // Banner Penjelasan Helpdesk
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.cyan.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.support_agent_rounded,
                      color: AppColors.cyan, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pusat Bantuan & Tiket Terpadu',
                        style: GoogleFonts.poppins(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        'Keluhan server, bot WA & kendala tagihan diproses langsung oleh teknisi VibeTech 24/7.',
                        style: GoogleFonts.poppins(
                          color: _textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4 Kartu Mini Statistik
          Row(
            children: [
              _buildMiniStatCard('Total', totalCount.toString(), AppColors.primary),
              const SizedBox(width: 8),
              _buildMiniStatCard('Open', openCount.toString(), AppColors.warning),
              const SizedBox(width: 8),
              _buildMiniStatCard('Diproses', inProgressCount.toString(), AppColors.cyan),
              const SizedBox(width: 8),
              _buildMiniStatCard('Selesai', resolvedCount.toString(), AppColors.emerald),
            ],
          ),
          const SizedBox(height: 12),

          // Filter Kategori Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'Semua',
                'Billing',
                'Teknis Server',
                'Request Fitur Bot WA',
                'Gangguan Jaringan',
              ].map((cat) {
                final isSelected = _ticketCategoryFilter == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(cat, style: GoogleFonts.poppins(fontSize: 11)),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withValues(alpha: 0.25),
                    backgroundColor: _cardColor,
                    labelStyle: GoogleFonts.poppins(
                      color: isSelected ? AppColors.cyan : _textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      setState(() => _ticketCategoryFilter = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Filter Status Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Semua', 'Open', 'In Progress', 'Resolved'].map((st) {
                final isSelected = _ticketStatusFilter == st;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(st, style: GoogleFonts.poppins(fontSize: 11)),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withValues(alpha: 0.25),
                    backgroundColor: _cardColor,
                    labelStyle: GoogleFonts.poppins(
                      color: isSelected ? AppColors.cyan : _textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      setState(() => _ticketStatusFilter = st);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Daftar Tiket atau Empty State
          if (_isLoadingTickets)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (filteredTickets.isEmpty)
            _buildEmptyTicketState()
          else
            ...filteredTickets.map((ticket) => _buildTicketCard(ticket)),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: _textSecondary,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    Color statusColor = AppColors.warning;
    if (ticket.isInProgress) {
      statusColor = AppColors.cyan;
    } else if (ticket.isResolved) {
      statusColor = AppColors.emerald;
    }

    String formattedDate = ticket.createdAt;
    try {
      final dt = DateTime.parse(ticket.createdAt);
      formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showTicketDetailModal(ticket),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          ticket.status,
                          style: GoogleFonts.poppins(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ticket.ticketNo,
                    style: GoogleFonts.jetBrainsMono(
                      color: _textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formattedDate,
                    style: GoogleFonts.poppins(color: _textSecondary, fontSize: 10.5),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                ticket.subject,
                style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ticket.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(color: _textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ticket.category,
                      style: GoogleFonts.poppins(
                        color: AppColors.accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Prioritas: ${ticket.priority}',
                      style: GoogleFonts.poppins(color: _textSecondary, fontSize: 10.5),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        'Lihat Detail',
                        style: GoogleFonts.poppins(
                          color: AppColors.cyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 11, color: AppColors.cyan),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTicketState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          children: [
            Icon(Icons.confirmation_number_outlined,
                size: 64, color: _textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text(
              'Belum Ada Tiket Bantuan',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tekan tombol "+ Buat Tiket Baru" untuk menyampaikan keluhan seputar server, tagihan, atau bot WhatsApp Anda.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: _textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // CHAT BODY (PERCAKAPAN DENGAN FURINA AI)
  // ============================================================================

  Widget _buildChatBody() {
    return Column(
      children: [
        // Banner Teater Stage
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
                AppColors.accent.withValues(alpha: 0.08),
              ],
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.theater_comedy,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Panggung Tanya Jawab VPS, Hosting & Bot WhatsApp Aktif',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Messages List
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final isUser = message['isUser'] as bool;
              final text = message['text'] as String;
              final time = message['time'] as String;

              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                builder: (context, val, child) {
                  return Transform.scale(
                    scale: val,
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: child,
                  );
                },
                child: Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    child: Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (!isUser) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 6, bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome,
                                    size: 12, color: AppColors.accent),
                                const SizedBox(width: 4),
                                Text(
                                  'Furina ✨',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            gradient: isUser
                                ? const LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.accent
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isUser ? null : _cardColor,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: isUser
                                  ? const Radius.circular(18)
                                  : const Radius.circular(4),
                              bottomRight: isUser
                                  ? const Radius.circular(4)
                                  : const Radius.circular(18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isUser
                                    ? AppColors.primary.withValues(alpha: 0.25)
                                    : Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: isUser
                                ? null
                                : Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.12),
                                  ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                text,
                                style: GoogleFonts.poppins(
                                  color: isUser ? Colors.white : _textPrimary,
                                  fontSize: 13.5,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Wrap(
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  children: [
                                    if (!isUser) ...[
                                      InkWell(
                                        onTap: () => _copyToClipboard(text),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2),
                                          child: Icon(
                                            Icons.copy_rounded,
                                            size: 13,
                                            color: _textSecondary
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ),
                                    ],
                                    Text(
                                      time,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: isUser
                                            ? Colors.white.withValues(alpha: 0.75)
                                            : _textSecondary
                                                .withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Indikator Furina Mengetik
        if (_isGenerating)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Sang Diva sedang merangkai naskah jawaban...',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: AppColors.accent,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

        // Quick Suggestions
        Container(
          height: 38,
          margin: const EdgeInsets.only(bottom: 6),
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              _buildQuickReply('💰 Cek Saldo Saya', 'Berapa saldo VibeWallet saya sekarang?'),
              _buildQuickReply('🚀 Rekomendasi VPS', 'Rekomendasikan paket VPS terbaik untuk server saya.'),
              _buildQuickReply('🤖 Sewa Bot WA', 'Bagaimana cara sewa Bot WhatsApp di VibeTech?'),
              _buildQuickReply('🎫 Ajukan Tiket', 'Bagaimana cara membuka tiket bantuan helpdesk?'),
            ],
          ),
        ),

        // Input Field
        Container(
          padding: EdgeInsets.fromLTRB(
            14,
            8,
            14,
            MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: _cardColor,
            border: Border(
              top: BorderSide(
                color: widget.isDarkMode
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: GoogleFonts.poppins(
                    color: _textPrimary,
                    fontSize: 13.5,
                  ),
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: 'Ketik pesan untuk Sang Diva Furina...',
                    hintStyle: GoogleFonts.poppins(
                      color: _textSecondary,
                      fontSize: 12.5,
                    ),
                    filled: true,
                    fillColor: _bgColor,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              BounceTap(
                onTap: _isGenerating ? () {} : () => _sendMessage(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickReply(String label, String promptText) {
    return BounceTap(
      onTap: _isGenerating ? () {} : () => _sendMessage(promptText),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.28),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: AppColors.accent,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
