import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/referral_tier_model.dart';
import '../../services/referral_service.dart';
import '../../services/theme_service.dart';

/// ============================================================================
/// HALAMAN PROGRAM REFERRAL & LEVEL KEMITRAAN (RESELLER TIER DASHBOARD)
/// ============================================================================
/// Menampilkan:
/// 1. Tingkatan Member Kemitraan (Standard, Silver, Gold, Platinum).
/// 2. Progres kenaikan tier berdasarkan total belanja dan jumlah referral.
/// 3. Kode referral unik akun pengguna + fitur Salin & Bagikan ke WhatsApp.
/// 4. Input klaim kode referral teman (jika belum terhubung).
/// 5. Riwayat penerimaan komisi saldo otomatis.
class ReferralProgramPage extends StatefulWidget {
  final String userEmail;
  final String username;
  final bool isDarkMode;

  const ReferralProgramPage({
    super.key,
    required this.userEmail,
    required this.username,
    required this.isDarkMode,
  });

  @override
  State<ReferralProgramPage> createState() => _ReferralProgramPageState();
}

class _ReferralProgramPageState extends State<ReferralProgramPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _claimReferralController = TextEditingController();
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  bool _isLoading = true;
  bool _isClaiming = false;
  Map<String, dynamic> _stats = {};
  List<ReferralHistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadReferralData();
  }

  @override
  void dispose() {
    _animController.dispose();
    _claimReferralController.dispose();
    super.dispose();
  }

  Future<void> _loadReferralData() async {
    setState(() => _isLoading = true);

    // Ambil kode referral & statistik
    await ReferralService.instance.getOrCreateReferralCode(
      userEmail: widget.userEmail,
      username: widget.username,
    );

    final stats = await ReferralService.instance.getUserTierStats(widget.userEmail);
    final history = await ReferralService.instance.getReferralHistory(widget.userEmail);

    if (mounted) {
      setState(() {
        _stats = stats;
        _history = history;
        _isLoading = false;
      });
      _animController.forward(from: 0.0);
    }
  }

  Future<void> _claimReferralCode() async {
    final code = _claimReferralController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan kode referral terlebih dahulu!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isClaiming = true);
    final success = await ReferralService.instance.bindReferrer(
      userEmail: widget.userEmail,
      referralCode: code,
    );

    if (!mounted) return;
    setState(() => _isClaiming = false);

    if (success) {
      _claimReferralController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selamat! Kode referral $code berhasil dihubungkan! 🎉'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      _loadReferralData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menghubungkan. Kode tidak valid atau milik sendiri.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin ke clipboard! 📋'),
        backgroundColor: const Color(0xFF7C4DFF),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareToWhatsApp(String code) async {
    final text = 'Halo! Gunakan kode referral saya *$code* di aplikasi *VibeTech XYZ* untuk sewa Cloud VPS, Bot WA, dan Panel Hosting tercepat dengan harga terbaik! 🚀 Unduh sekarang: https://vibetech.xyz/ref/$code';
    final url = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    final fallbackUrl = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(text)}');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      _copyToClipboard(text, 'Tautan Promosi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDarkMode;
    final bgCol = isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextCol = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final ResellerTierInfo currentTier =
        _stats['currentTier'] as ResellerTierInfo? ?? ResellerTierHelper.standardTier;
    final ResellerTierInfo? nextTier = _stats['nextTier'] as ResellerTierInfo?;
    final double progress = (_stats['nextTierProgress'] as num?)?.toDouble() ?? 0.0;
    final double remaining = (_stats['remainingSpendingForNextTier'] as num?)?.toDouble() ?? 0.0;
    final String myCode = _stats['referralCode']?.toString() ?? 'VT-${widget.username.toUpperCase()}';
    final String referredBy = _stats['referredBy']?.toString() ?? '';
    final int referralCount = (_stats['referralCount'] as num?)?.toInt() ?? 0;
    final double totalComm = (_stats['totalCommissionEarned'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: bgCol,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textCol, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Program Referral & Kemitraan',
          style: GoogleFonts.plusJakartaSans(
            color: textCol,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textCol),
            onPressed: _loadReferralData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C4DFF)),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                color: const Color(0xFF7C4DFF),
                onRefresh: _loadReferralData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  children: [
                    // 1. BANNER TIER KEMITRAAN (HERO GRADIENT)
                    _buildTierHeroCard(
                      currentTier: currentTier,
                      nextTier: nextTier,
                      progress: progress,
                      remaining: remaining,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 18),

                    // 2. KARTU KODE REFERRAL SAYA
                    _buildMyReferralCodeCard(
                      code: myCode,
                      isDark: isDark,
                      cardBg: cardBg,
                      textCol: textCol,
                      subTextCol: subTextCol,
                    ),

                    const SizedBox(height: 18),

                    // 3. STATISTIK METRIK KEMITRAAN
                    _buildStatsRow(
                      referralCount: referralCount,
                      totalComm: totalComm,
                      discountPercent: currentTier.discountPercentText,
                      isDark: isDark,
                      cardBg: cardBg,
                    ),

                    const SizedBox(height: 18),

                    // 4. KLAIM KODE REFERRAL TEMAN (JIKA BELUM DIKAITKAN)
                    _buildClaimReferralSection(
                      referredBy: referredBy,
                      isDark: isDark,
                      cardBg: cardBg,
                      textCol: textCol,
                      subTextCol: subTextCol,
                    ),

                    const SizedBox(height: 24),

                    // 5. TABEL TINGKATAN KEMITRAAN & KEUNTUNGAN
                    _buildTierComparisonSection(
                      currentTier: currentTier,
                      isDark: isDark,
                      cardBg: cardBg,
                      textCol: textCol,
                      subTextCol: subTextCol,
                    ),

                    const SizedBox(height: 24),

                    // 6. RIWAYAT KOMISI MASUK
                    _buildCommissionHistorySection(
                      history: _history,
                      isDark: isDark,
                      cardBg: cardBg,
                      textCol: textCol,
                      subTextCol: subTextCol,
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildTierHeroCard({
    required ResellerTierInfo currentTier,
    required ResellerTierInfo? nextTier,
    required double progress,
    required double remaining,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            currentTier.primaryColor,
            currentTier.secondaryColor,
            const Color(0xFF0F172A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: currentTier.primaryColor.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(currentTier.icon, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      currentTier.badgeText,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Komisi ${currentTier.commissionPercentText}',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            currentTier.title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentTier.description,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Progres bar ke tier berikutnya
          if (nextTier != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Menuju ${nextTier.title}',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Belanja ${_currencyFormatter.format(remaining)} lagi untuk buka diskon ${nextTier.discountPercentText} & komisi ${nextTier.commissionPercentText}!',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Colors.cyanAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Anda berada di kasta tertinggi kemitraan VIP! 👑',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMyReferralCodeCard({
    required String code,
    required bool isDark,
    required Color cardBg,
    required Color textCol,
    required Color subTextCol,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share_rounded, color: Color(0xFF7C4DFF), size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kode Referral Anda',
                    style: GoogleFonts.plusJakartaSans(
                      color: textCol,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Bagikan kode ini untuk klaim komisi saldo seumur hidup',
                    style: GoogleFonts.plusJakartaSans(color: subTextCol, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  code,
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF7C4DFF),
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: 2,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Salin Kode',
                      icon: const Icon(Icons.copy_rounded, color: Color(0xFF7C4DFF), size: 20),
                      onPressed: () => _copyToClipboard(code, 'Kode Referral'),
                    ),
                    IconButton(
                      tooltip: 'Bagikan ke WhatsApp',
                      icon: const Icon(Icons.send_rounded, color: Color(0xFF22C55E), size: 20),
                      onPressed: () => _shareToWhatsApp(code),
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

  Widget _buildStatsRow({
    required int referralCount,
    required double totalComm,
    required String discountPercent,
    required bool isDark,
    required Color cardBg,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Teman Join',
            value: '$referralCount User',
            icon: Icons.group_rounded,
            color: const Color(0xFF3B82F6),
            isDark: isDark,
            cardBg: cardBg,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'Total Komisi',
            value: _currencyFormatter.format(totalComm),
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
            cardBg: cardBg,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'Diskon Member',
            value: discountPercent,
            icon: Icons.discount_rounded,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            cardBg: cardBg,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color cardBg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimReferralSection({
    required String referredBy,
    required bool isDark,
    required Color cardBg,
    required Color textCol,
    required Color subTextCol,
  }) {
    final bool hasReferredBy = referredBy.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard_rounded, color: Color(0xFFEC4899), size: 20),
              const SizedBox(width: 8),
              Text(
                'Punya Kode Referral Teman?',
                style: GoogleFonts.plusJakartaSans(
                  color: textCol,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasReferredBy) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Terhubung dengan Pengundang: $referredBy',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Hubungkan akun dengan pengundang Anda untuk mendukung mitra VibeTech.',
              style: GoogleFonts.plusJakartaSans(color: subTextCol, fontSize: 11),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _claimReferralController,
                    style: GoogleFonts.plusJakartaSans(color: textCol, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Contoh: VT-RAZIK',
                      hintStyle: GoogleFonts.plusJakartaSans(color: subTextCol, fontSize: 12),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isClaiming ? null : _claimReferralCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isClaiming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Klaim',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTierComparisonSection({
    required ResellerTierInfo currentTier,
    required bool isDark,
    required Color cardBg,
    required Color textCol,
    required Color subTextCol,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech_rounded, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 8),
              Text(
                'Perbandingan Keuntungan Tier',
                style: GoogleFonts.plusJakartaSans(
                  color: textCol,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...ResellerTierHelper.allTiers.map((t) {
            final isCurrent = t.level == currentTier.level;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCurrent
                    ? const Color(0xFF7C4DFF).withValues(alpha: 0.08)
                    : (isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent
                      ? const Color(0xFF7C4DFF)
                      : (isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0)),
                  width: isCurrent ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(t.icon, color: t.primaryColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              t.title,
                              style: GoogleFonts.plusJakartaSans(
                                color: textCol,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C4DFF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'AKTIF',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Min Belanja ${_currencyFormatter.format(t.minSpending)} • ${t.minReferrals} Referral',
                          style: GoogleFonts.plusJakartaSans(color: subTextCol, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Komisi ${t.commissionPercentText}',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Diskon ${t.discountPercentText}',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFF59E0B),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCommissionHistorySection({
    required List<ReferralHistoryItem> history,
    required bool isDark,
    required Color cardBg,
    required Color textCol,
    required Color subTextCol,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_edu_rounded, color: Color(0xFF38BDF8), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Riwayat Komisi Masuk',
                    style: GoogleFonts.plusJakartaSans(
                      color: textCol,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Text(
                '${history.length} Transaksi',
                style: GoogleFonts.plusJakartaSans(color: subTextCol, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (history.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, color: subTextCol.withValues(alpha: 0.5), size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'Belum ada komisi referral.',
                    style: GoogleFonts.plusJakartaSans(
                      color: subTextCol,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ajak teman Anda bergabung untuk mulai menghasilkan saldo!',
                    style: GoogleFonts.plusJakartaSans(
                      color: subTextCol.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...history.map((item) {
              final formattedAmount = _currencyFormatter.format(item.commissionAmount);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF10B981), size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dari: ${item.buyerEmail.split('@').first}',
                            style: GoogleFonts.plusJakartaSans(
                              color: textCol,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Invoice: #${item.invoiceNo}',
                            style: GoogleFonts.plusJakartaSans(color: subTextCol, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+$formattedAmount',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF10B981),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          item.createdAt.length >= 10 ? item.createdAt.substring(0, 10) : item.createdAt,
                          style: GoogleFonts.plusJakartaSans(color: subTextCol, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
