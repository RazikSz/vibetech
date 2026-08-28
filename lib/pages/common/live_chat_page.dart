import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibetech_xyz/constants/constants.dart';
import 'package:vibetech_xyz/services/ai_chat_service.dart';

/// ============================================================================
/// HALAMAN LIVE CHAT AI FURINA (VIBETECH THEATRICAL ASSISTANT)
/// ============================================================================
/// Fitur Halaman:
/// 1. Asisten AI Diva Furina bertema panggung teater mewah & elegan.
/// 2. Integrasi ke Backend Express API & Intelligent Fallback ke Google Gemini AI.
/// 3. Riwayat percakapan sesi dinamis dengan dukungan reset sesi.
/// 4. Quick suggestions, copy text, feedback haptik, dan UI bebas overflow di segala resolusi.
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
          'Katakan saja, dan saksikan pertunjukan jawaban spektakuler dariku!',
      'isUser': false,
      'time': timeStr,
    });
  }

  @override
  void dispose() {
    _particleController.dispose();
    _pulseController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
                // Furina Avatar Badge
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
                // Avatar with Theatrical Glow
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
                              'Furina AI',
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
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.greenAccent,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'VibeTech Diva • by ${AiChatService.director}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                color: _textSecondary,
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
          const SizedBox(width: 4),
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
          Column(
            children: [
              // Banner Teater Stage
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: child,
                        );
                      },
                      child: Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
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
                                  padding:
                                      const EdgeInsets.only(left: 6, bottom: 4),
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
                                          ? AppColors.primary
                                              .withValues(alpha: 0.25)
                                          : Colors.black
                                              .withValues(alpha: 0.05),
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
                                        color: isUser
                                            ? Colors.white
                                            : _textPrimary,
                                        fontSize: 13.5,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Wrap(
                                        alignment: WrapAlignment.end,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 6,
                                        children: [
                                          if (!isUser) ...[
                                            InkWell(
                                              onTap: () =>
                                                  _copyToClipboard(text),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 2),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.copy_rounded,
                                                        size: 11,
                                                        color: _textSecondary),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      'Salin',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 10,
                                                        color: _textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                          Text(
                                            time,
                                            style: GoogleFonts.poppins(
                                              color: isUser
                                                  ? Colors.white70
                                                  : _textSecondary,
                                              fontSize: 10,
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

              // Typing Indicator (Overflow Safe)
              if (_isGenerating)
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16, bottom: 8, right: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.85,
                      ),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Furina sedang merangkai monolog... ✨',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.poppins(
                                color: AppColors.accent,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Quick Suggestion Repertoire
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    _buildQuickReply('💻 Kalkulator Python',
                        'Buatkan saya kalkulator sederhana di Python'),
                    _buildQuickReply('💰 Sisa Saldo',
                        'Berapa sisa saldo VibeWallet saya saat ini?'),
                    _buildQuickReply('👑 Rekomendasi VPS',
                        'Beri aku rekomendasi paket VPS terbaik di VibeTech!'),
                    _buildQuickReply('⚡ Panel Pterodactyl',
                        'Jelaskan tentang spesifikasi dan keunggulan Panel Hosting Pterodactyl.'),
                    _buildQuickReply('🤖 Sewa Bot WA',
                        'Bagaimana cara sewa Bot WhatsApp dan apa saja fiturnya?'),
                    _buildQuickReply('📱 WhatsApp Raziek',
                        'Berapa nomor WhatsApp resmi Sutradara Raziek?'),
                    _buildQuickReply('🎟️ Kupon Diskon',
                        'Apakah ada kode kupon diskon promo untuk belanja?'),
                    _buildQuickReply('💳 Pembayaran',
                        'Metode pembayaran apa saja yang didukung di VibeTech XYZ?'),
                  ],
                ),
              ),

              // Input Bar
              Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom + 4
                      : 16,
                ),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    )
                  ],
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
          ),
        ],
      ),
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
