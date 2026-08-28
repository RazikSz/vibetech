import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:vibetech_xyz/constants/constants.dart';
import 'package:vibetech_xyz/pages/payment/pembayaran_page.dart';
import 'package:vibetech_xyz/services/cart_service.dart';
import 'package:vibetech_xyz/services/language_service.dart';

/// ============================================================================
/// HALAMAN KERANJANG BELANJA (SHOPPING CART PAGE)
/// ============================================================================
/// Halaman ini mengelola daftar item belanja pengguna:
/// 1. Melihat seluruh item produk yang dimasukkan ke keranjang.
/// 2. Menambah / mengurangi kuantitas atau menghapus item dari keranjang.
/// 3. Menghitung total biaya belanja secara instan & reaktif.
/// 4. Tombol Checkout menuju halaman pembayaran (PembayaranPage).
class KeranjangPage extends StatefulWidget {
  final bool isDarkMode;

  const KeranjangPage({
    super.key,
    required this.isDarkMode,
  });

  @override
  State<KeranjangPage> createState() => _KeranjangPageState();
}

class _KeranjangPageState extends State<KeranjangPage>
    with SingleTickerProviderStateMixin {
  final List<AppParticle> _particles = [];
  final math.Random _random = math.Random();
  late AnimationController _particleController;

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

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
  }

  @override
  void dispose() {
    _particleController.dispose();
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
          LanguageService.tr('keranjang_belanja'),
          style: GoogleFonts.poppins(
              color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: CartService.notifier,
            builder: (_, items, ___) => BounceTap(
              onTap: items.isEmpty
                  ? () {}
                  : () {
                      HapticFeedback.mediumImpact();
                      _showClearCartDialog();
                    },
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: items.isEmpty
                      ? Colors.transparent
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_sweep_rounded,
                  color: items.isEmpty
                      ? _textSecondary.withValues(alpha: 0.5)
                      : AppColors.error,
                  size: 24,
                ),
              ),
            ),
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
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: CartService.notifier,
            builder: (context, cartItems, _) {
              if (cartItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 100,
                          color: _textSecondary.withValues(alpha: 0.3)),
                      const SizedBox(height: 20),
                      Text(LanguageService.tr('keranjang_kosong'),
                          style: GoogleFonts.poppins(
                              color: _textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(LanguageService.tr('belum_ada_produk'),
                          style: GoogleFonts.poppins(
                              color: _textSecondary, fontSize: 14)),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      itemCount: cartItems.length,
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 400 + (index * 100)),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: _buildCartItem(item, index),
                        );
                      },
                    ),
                  ),
                  _buildBottomCheckoutBar(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, int index) {
    final String name = (item['name'] ??
            item['title'] ??
            item['nama'] ??
            item['productName'] ??
            item['nama_produk'] ??
            'Layanan VibeTech')
        .toString();
    final String specs = item['specs']?.toString() ??
        item['deskripsi']?.toString() ??
        'Standard';
    final int price = (item['price'] as num?)?.toInt() ?? 0;
    final int quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final String type = item['type']?.toString() ?? 'VPS';

    IconData getIcon() {
      if (type.contains('VPS')) return Icons.dns_rounded;
      if (type.contains('Bot')) return Icons.chat_bubble_rounded;
      return Icons.cloud_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _textSecondary.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(getIcon(), color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                        fontSize: 15)),
                Text(specs,
                    style: GoogleFonts.poppins(
                        color: _textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text(_currencyFormatter.format(price),
                    style: GoogleFonts.poppins(
                        color: AppColors.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BounceTap(
                onTap: () {
                  HapticFeedback.lightImpact();
                  CartService.removeItem(index);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.error, size: 16),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  BounceTap(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (quantity > 1) {
                        CartService.updateQuantity(index, quantity - 1);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: _textSecondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Icon(Icons.remove_rounded,
                          color: _textPrimary, size: 18),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('$quantity',
                        style: GoogleFonts.poppins(
                            color: _textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                  BounceTap(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      CartService.updateQuantity(index, quantity + 1);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.add_rounded,
                          color: AppColors.primary, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCheckoutBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(LanguageService.tr('total_pembayaran'),
                    style: GoogleFonts.poppins(
                        color: _textSecondary, fontSize: 14)),
                Text(
                  _currencyFormatter.format(CartService.totalPrice),
                  style: GoogleFonts.poppins(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 20),
            BounceTap(
              onTap: () {
                HapticFeedback.heavyImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PembayaranPage(
                      totalAmount: CartService.totalPrice,
                      items: List<Map<String, dynamic>>.from(CartService.items),
                      isDarkMode: widget.isDarkMode,
                    ),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: Center(
                  child: Text(
                    LanguageService.tr('lanjut_pembayaran'),
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          LanguageService.text('Kosongkan Keranjang?', 'Clear Cart?'),
          style: GoogleFonts.poppins(
              color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          LanguageService.text(
            'Semua produk dalam keranjang akan dihapus.',
            'All items in your cart will be removed.',
          ),
          style: GoogleFonts.poppins(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LanguageService.tr('batal'),
                style: GoogleFonts.poppins(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              CartService.clear();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              LanguageService.text('Kosongkan', 'Clear'),
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
