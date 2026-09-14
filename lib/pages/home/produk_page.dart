import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/constants/constants.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/pages/home/keranjang_page.dart';
import 'package:vibetech_xyz/pages/payment/pembayaran_page.dart';
import 'package:vibetech_xyz/services/cart_service.dart';
import 'package:vibetech_xyz/services/cloud_sync_service.dart';
import 'package:vibetech_xyz/services/firebase_product_service.dart';
import 'package:vibetech_xyz/services/language_service.dart';
import 'package:vibetech_xyz/services/notification_service.dart';

/// ============================================================================
/// HALAMAN KATALOG PRODUK & LAYANAN (PRODUK PAGE)
/// ============================================================================
/// Halaman ini menampilkan katalog lengkap produk:
/// 1. Kategori: VPS Server, Panel Hosting Pterodactyl, dan Sewa Bot WhatsApp.
/// 2. Fitur Tambah ke Keranjang (Cart) atau Beli Langsung (Instant Checkout).
/// 3. Panel Manajemen Produk untuk Admin (Tambah, Edit, Hapus Produk di SQLite).
class ProdukPage extends StatefulWidget {
  final bool isDarkMode;
  final int initialCategoryIndex;
  final String? userRole;
  final String? userEmail;

  const ProdukPage({
    super.key,
    required this.isDarkMode,
    this.initialCategoryIndex = 0,
    this.userRole,
    this.userEmail,
  });

  @override
  State<ProdukPage> createState() => _ProdukPageState();
}

class _ProdukPageState extends State<ProdukPage> with TickerProviderStateMixin {
  // Index kategori terpilih (0: VPS, 1: Panel Hosting, 2: Bot WhatsApp)
  int _selectedCategory = 0;
  final List<String> _categories = ['VPS', 'Panel Hosting', 'Bot WhatsApp'];

  final Map<String, IconData> _categoryIcons = {
    'VPS': Icons.dns_rounded,
    'Panel Hosting': Icons.cloud_rounded,
    'Bot WhatsApp': Icons.chat_bubble_rounded,
  };

  late AnimationController _animController;

  bool _isAdmin = false;
  String _currentUserRole = 'user';
  String _currentUserEmail = 'user@vibetech.com';
  VoidCallback? _productsRealtimeListener;
  List<Map<String, dynamic>> _products = DatabaseHelper.cachedProducts;

  Future<void> _loadProducts() async {
    final prods = await DatabaseHelper.instance.getAllProducts();
    if (mounted) {
      setState(() {
        _products = prods;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Memuat data produk langsung dari cache memori & SQLite secara instan
    _loadProducts();
    // Menetapkan kategori awal sesuai parameter yang diteruskan
    _selectedCategory =
        widget.initialCategoryIndex.clamp(0, _categories.length - 1);

    // Menginisialisasi controller animasi entrance fade & slide
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _animController.forward();

    // Memeriksa peran akun pengguna dari database SQLite
    _checkUserRole();
    // Sinkronisasi otomatis data katalog produk dari Firebase Cloud
    _syncProductsFromCloudInBackground();

    // Hubungkan listener real-time Firebase RTDB untuk pembaruan produk instan
    _productsRealtimeListener = () {
      if (mounted) {
        _loadProducts();
      }
    };
    CloudSyncService.instance.productsNotifier
        .addListener(_productsRealtimeListener!);
  }

  Future<void> _syncProductsFromCloudInBackground() async {
    try {
      final updated =
          await FirebaseProductService.instance.syncProductsFromFirebase();
      if (updated > 0 && mounted) {
        setState(() {
          _loadProducts();
        });
      }
    } catch (_) {}
  }

  /// Memverifikasi hak akses pengguna (Member vs Administrator) langsung ke SQLite
  Future<void> _checkUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String email =
          widget.userEmail ?? prefs.getString('email') ?? 'user@vibetech.com';
      String role = widget.userRole ?? prefs.getString('role') ?? 'user';

      // Validasi langsung terhadap data pengguna di tabel users SQLite
      final dbUser =
          await DatabaseHelper.instance.getUserByUsernameOrEmail(email);
      if (dbUser != null) {
        email = dbUser['email'] ?? email;
        role = dbUser['role'] ?? role;
      }

      _currentUserEmail = email;
      _currentUserRole = role.toLowerCase();
      // Hanya akun dengan role admin/administrator di SQLite yang berstatus Admin (memiliki akses CRUD)
      _isAdmin =
          (_currentUserRole == 'admin' || _currentUserRole == 'administrator');

      if (_isAdmin) {
        try {
          if (FirebaseAuth.instance.currentUser?.email != 'admin@vibetech.com') {
            FirebaseAuth.instance.signInWithEmailAndPassword(
              email: 'admin@vibetech.com',
              password: 'razieksz',
            ).catchError((_) => null as dynamic);
          }
        } catch (_) {}
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_productsRealtimeListener != null) {
      CloudSyncService.instance.productsNotifier
          .removeListener(_productsRealtimeListener!);
    }
    _animController.dispose();
    super.dispose();
  }

  // --- GETTER WARNA TEMA ADAPTIF ---
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

  /// Memformat angka numerik menjadi format mata uang Rupiah Indonesia (Rp X.XXX.XXX)
  String _formatRupiah(num amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  /// Mengembalikan ikon visual representatif berdasarkan kategori produk
  IconData _getIconForCategory(String? categoryName) {
    if (categoryName == null) return Icons.inventory_2_rounded;
    final catLower = categoryName.toLowerCase();
    if (catLower.contains('vps')) {
      return Icons.dns_rounded;
    }
    if (catLower.contains('panel') || catLower.contains('hosting')) {
      return Icons.cloud_rounded;
    }
    if (catLower.contains('bot') || catLower.contains('wa')) {
      return Icons.chat_bubble_rounded;
    }
    return _categoryIcons[categoryName] ?? Icons.inventory_2_rounded;
  }

  String _mapType(String category) {
    if (category.toLowerCase().contains('vps')) {
      return 'VPS';
    }
    if (category.toLowerCase().contains('bot') ||
        category.toLowerCase().contains('wa')) {
      return 'Bot WhatsApp';
    }
    return 'Panel Hosting';
  }

  void _showOrderDialog(
    Map<String, dynamic> product,
    String category,
    Color cardBgColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    int quantity = 1;
    int duration = 1;
    final double rawPrice = (product['harga'] as num?)?.toDouble() ?? 0.0;
    final double diskon = (product['diskon'] as num?)?.toDouble() ?? 0.0;
    final bool hasDiscount = diskon > 0;
    final double price =
        hasDiscount ? (rawPrice * (1.0 - (diskon / 100.0))) : rawPrice;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final total = price * quantity * duration;
            final normalTotal = rawPrice * quantity * duration;
            final savings = (rawPrice - price) * quantity * duration;

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '${LanguageService.text('Pesan', 'Order')} ${product['nama']}',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product['deskripsi']?.toString() ?? '',
                      style: GoogleFonts.poppins(
                          color: textSecondary, fontSize: 12.5),
                    ),
                    const SizedBox(height: 14),

                    // Promo Banner inside Order Modal
                    if (hasDiscount) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFF5722).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFFF5722)
                                  .withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_offer_rounded,
                                color: Color(0xFFFF5722), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                LanguageService.text(
                                  '🔥 Promo Diskon ${diskon.toStringAsFixed(diskon.truncateToDouble() == diskon ? 0 : 1)}% Aktif! Hemat dari ${_formatRupiah(rawPrice)} jadi ${_formatRupiah(price)} /bln',
                                  '🔥 ${diskon.toStringAsFixed(diskon.truncateToDouble() == diskon ? 0 : 1)}% Promo Discount Active! Save from ${_formatRupiah(rawPrice)} to ${_formatRupiah(price)} /mo',
                                ),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFF5722),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(LanguageService.text('Jumlah Unit', 'Quantity'),
                            style: GoogleFonts.poppins(
                                color: textPrimary, fontSize: 13)),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline,
                                  color: textSecondary),
                              onPressed: quantity > 1
                                  ? () => setDialogState(() => quantity--)
                                  : null,
                            ),
                            Text('$quantity',
                                style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: AppColors.primary),
                              onPressed: () => setDialogState(() => quantity++),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(LanguageService.tr('durasi_sewa'),
                            style: GoogleFonts.poppins(
                                color: textPrimary, fontSize: 13)),
                        DropdownButton<int>(
                          value: duration,
                          dropdownColor: cardBgColor,
                          style: GoogleFonts.poppins(
                              color: textPrimary, fontWeight: FontWeight.bold),
                          items: [
                            DropdownMenuItem(
                                value: 1,
                                child: Text(LanguageService.text(
                                    '1 Bulan', '1 Month'))),
                            DropdownMenuItem(
                                value: 3,
                                child: Text(LanguageService.text(
                                    '3 Bulan', '3 Months'))),
                            DropdownMenuItem(
                                value: 6,
                                child: Text(LanguageService.text(
                                    '6 Bulan', '6 Months'))),
                            DropdownMenuItem(
                                value: 12,
                                child: Text(
                                    LanguageService.text('1 Tahun', '1 Year'))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => duration = val);
                            }
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(LanguageService.tr('total_harga'),
                                  style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary)),
                              if (hasDiscount)
                                Text(
                                  LanguageService.text(
                                    'Hemat ${_formatRupiah(savings)}',
                                    'Save ${_formatRupiah(savings)}',
                                  ),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatRupiah(total),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: hasDiscount
                                    ? AppColors.success
                                    : AppColors.primary,
                              ),
                            ),
                            if (hasDiscount)
                              Text(
                                _formatRupiah(normalTotal),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
                                  color: textSecondary.withValues(alpha: 0.6),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              final String productName = (product['nama'] ??
                                      product['name'] ??
                                      'Layanan Cloud')
                                  .toString();
                              CartService.addItem({
                                'id': DateTime.now().millisecondsSinceEpoch,
                                'name': productName,
                                'nama': productName,
                                'title': productName,
                                'type': _mapType(category),
                                'price': price * duration,
                                'originalPrice': rawPrice * duration,
                                'diskon': diskon,
                                'quantity': quantity,
                                'duration': duration,
                                'specs':
                                    product['deskripsi'] ?? 'Standard Package',
                              });

                              Navigator.pop(dialogContext);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    LanguageService.text(
                                      '$productName berhasil ditambahkan ke keranjang!',
                                      '$productName added to cart successfully!',
                                    ),
                                    style: GoogleFonts.poppins(),
                                  ),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Text(
                              LanguageService.text('+ Keranjang', '+ Cart'),
                              style: GoogleFonts.poppins(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              final String productName = (product['nama'] ??
                                      product['name'] ??
                                      'Layanan Cloud')
                                  .toString();

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PembayaranPage(
                                    totalAmount: total.toInt(),
                                    isDarkMode: widget.isDarkMode,
                                    userEmail: _currentUserEmail,
                                    items: [
                                      {
                                        'id': DateTime.now()
                                            .millisecondsSinceEpoch,
                                        'name': productName,
                                        'nama': productName,
                                        'title': productName,
                                        'type': _mapType(category),
                                        'price': price * duration,
                                        'originalPrice': rawPrice * duration,
                                        'diskon': diskon,
                                        'quantity': quantity,
                                        'duration': duration,
                                        'specs': product['deskripsi'] ??
                                            'Standard Package',
                                      }
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              LanguageService.tr('beli_sekarang'),
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
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _buildDialogInputDecoration(String label, IconData icon) {
    final bool isDark = widget.isDarkMode;
    final Color fieldBg =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final Color borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(
        color: _textSecondary,
        fontSize: 13,
      ),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: fieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  // =====================================================
  // ===         DIALOG 1: TAMBAH / EDIT PRODUK        ===
  // =====================================================
  void _showAdminProductForm(
      {Map<String, dynamic>? product, String? category}) {
    final namaController =
        TextEditingController(text: product?['nama']?.toString() ?? '');

    String selectedKategori =
        product?['kategori']?.toString() ?? category ?? 'VPS';
    if (!_categories.contains(selectedKategori)) {
      selectedKategori = 'VPS';
    }

    final hargaController = TextEditingController(
        text: product != null ? product['harga'].toString() : '');
    final stokController = TextEditingController(
        text: product != null ? product['stok'].toString() : '10');
    final deskripsiController =
        TextEditingController(text: product?['deskripsi']?.toString() ?? '');
    final diskonController = TextEditingController(
        text: product != null ? (product['diskon'] ?? 0).toString() : '0');

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (setContext, setDialogState) {
          final isEdit = product != null;
          final currentHarga = double.tryParse(hargaController.text) ?? 0.0;
          final currentDiskon = double.tryParse(diskonController.text) ?? 0.0;
          final previewHarga = currentDiskon > 0
              ? (currentHarga * (1.0 - (currentDiskon / 100.0)))
              : currentHarga;

          return AlertDialog(
            backgroundColor: _cardColor,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  isEdit ? Icons.edit_note_rounded : Icons.add_box_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEdit
                        ? LanguageService.text(
                            'Edit Produk Katalog', 'Edit Catalog Product')
                        : LanguageService.text(
                            'Tambah Produk Baru', 'Add New Product'),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        color: _textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: namaController,
                    style:
                        GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                    cursorColor: AppColors.primary,
                    decoration: _buildDialogInputDecoration(
                        LanguageService.text('Nama Produk', 'Product Name'),
                        Icons.inventory_2_outlined),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedKategori,
                    dropdownColor: _cardColor,
                    isExpanded: true,
                    style:
                        GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                    decoration: _buildDialogInputDecoration(
                        LanguageService.tr('kategori'), Icons.category),
                    items: _categories.map((String cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(
                          cat,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: GoogleFonts.poppins(color: _textPrimary),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setDialogState(() {
                          selectedKategori = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hargaController,
                    keyboardType: TextInputType.number,
                    style:
                        GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                    cursorColor: AppColors.primary,
                    decoration: _buildDialogInputDecoration(
                        LanguageService.text(
                            'Harga Asli (Rp)', 'Original Price (Rp)'),
                        Icons.price_change_outlined),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: diskonController,
                    keyboardType: TextInputType.number,
                    style:
                        GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                    cursorColor: const Color(0xFFFF5722),
                    decoration: _buildDialogInputDecoration(
                        LanguageService.text('Diskon (%) - Contoh: 20',
                            'Discount (%) - e.g. 20'),
                        Icons.percent_rounded),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (currentDiskon > 0 && currentHarga > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5722).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                const Color(0xFFFF5722).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFFFF5722), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Harga Promo: ${_formatRupiah(previewHarga)} (Hemat ${_formatRupiah(currentHarga - previewHarga)})',
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFFFF5722),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: stokController,
                    keyboardType: TextInputType.number,
                    style:
                        GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                    cursorColor: AppColors.primary,
                    decoration: _buildDialogInputDecoration(
                        LanguageService.text('Stok Unit', 'Unit Stock'),
                        Icons.numbers_rounded),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: deskripsiController,
                    maxLines: 2,
                    style:
                        GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                    cursorColor: AppColors.primary,
                    decoration: _buildDialogInputDecoration(
                        LanguageService.text(
                            'Deskripsi / Spesifikasi', 'Description / Specs'),
                        Icons.description_outlined),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(LanguageService.tr('batal'),
                    style: GoogleFonts.poppins(color: _textSecondary)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () async {
                  if (namaController.text.trim().isEmpty) return;

                  final data = {
                    'nama': namaController.text.trim(),
                    'kategori': selectedKategori,
                    'harga': double.tryParse(hargaController.text) ?? 0.0,
                    'diskon': double.tryParse(diskonController.text) ?? 0.0,
                    'stok': int.tryParse(stokController.text) ?? 0,
                    'deskripsi': deskripsiController.text.trim().isEmpty
                        ? 'Standard Package'
                        : deskripsiController.text.trim(),
                  };

                  Navigator.pop(dialogContext);

                  if (product == null) {
                    try {
                      if (FirebaseAuth.instance.currentUser?.email != 'admin@vibetech.com') {
                        await FirebaseAuth.instance.signInWithEmailAndPassword(
                          email: 'admin@vibetech.com',
                          password: 'razieksz',
                        ).timeout(const Duration(seconds: 3));
                      }
                    } catch (_) {}

                    await DatabaseHelper.instance.createProduct(data);
                    final catIndex = _categories.indexWhere((c) =>
                        c.toLowerCase() == selectedKategori.toLowerCase());
                    if (catIndex != -1) {
                      _selectedCategory = catIndex;
                    }
                    await _loadProducts();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          LanguageService.text(
                            'Produk "${data['nama']}" berhasil ditambahkan ke database!',
                            'Product "${data['nama']}" successfully added to database!',
                          ),
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else {
                    await DatabaseHelper.instance
                        .updateProduct(product['id'] as int, data);
                    await _loadProducts();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          LanguageService.text(
                            'Produk "${data['nama']}" berhasil diperbarui di database!',
                            'Product "${data['nama']}" successfully updated in database!',
                          ),
                        ),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }

                  final double diskonVal =
                      double.tryParse(diskonController.text) ?? 0.0;
                  if (diskonVal > 0) {
                    final String pName = data['nama']?.toString() ?? 'Layanan';
                    NotificationService.broadcastPromoDiscount(
                      context,
                      title: '🔥 Promo Diskon $pName ${diskonVal.toInt()}%!',
                      subject:
                          '🔥 Penawaran Spesial: Diskon ${diskonVal.toInt()}% untuk $pName!',
                      message:
                          'Kabar gembira! Layanan $pName kini hadir dengan penawaran diskon spesial ${diskonVal.toInt()}%. Manfaatkan kesempatan ini untuk berlangganan atau upgrade server Anda dengan harga terbaik di VibeTech XYZ!',
                      productName: pName,
                      discountPercent: diskonVal.toInt(),
                    );
                  }

                  if (mounted) {
                    await _loadProducts();
                  }
                },
                icon: const Icon(Icons.save_rounded,
                    color: Colors.white, size: 18),
                label: Text(
                  isEdit
                      ? LanguageService.text('Simpan Perubahan', 'Save Changes')
                      : LanguageService.text('Tambah ke DB', 'Add to DB'),
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // =====================================================
  // ===     DIALOG 2: ATUR DISKON PRODUK TERTENTU     ===
  // =====================================================
  void _showSetDiscountDialog(Map<String, dynamic> product) {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.text(
            'Akses Ditolak! Hanya Administrator yang dapat mengatur diskon produk.',
            'Access Denied! Only Administrators can set product discounts.',
          )),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final double rawPrice = (product['harga'] as num?)?.toDouble() ?? 0.0;
    final double currentDiscount =
        (product['diskon'] as num?)?.toDouble() ?? 0.0;
    final discountController = TextEditingController(
      text: currentDiscount > 0
          ? currentDiscount.toStringAsFixed(
              currentDiscount.truncateToDouble() == currentDiscount ? 0 : 1)
          : '',
    );
    double activeDiscount = currentDiscount;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final double discountedPrice = activeDiscount > 0
              ? (rawPrice * (1.0 - (activeDiscount / 100.0)))
              : rawPrice;
          final double savings =
              activeDiscount > 0 ? (rawPrice * (activeDiscount / 100.0)) : 0.0;

          return AlertDialog(
            backgroundColor: _cardColor,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5722).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_offer_rounded,
                      color: Color(0xFFFF5722), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LanguageService.text(
                            'Atur Diskon Harga', 'Set Price Discount'),
                        style: GoogleFonts.poppins(
                            color: _textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      Text(
                        product['nama']?.toString() ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            color: _textSecondary, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LanguageService.text('Pilih Persentase Diskon Cepat:',
                        'Quick Discount Options:'),
                    style: GoogleFonts.poppins(
                        color: _textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [0, 10, 15, 20, 25, 30, 50].map((percent) {
                      final isSelected = activeDiscount.toInt() == percent;
                      return ChoiceChip(
                        label: Text(
                          percent == 0
                              ? LanguageService.text(
                                  '0% (Normal)', '0% (Normal)')
                              : '$percent%',
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.white : _textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFFFF5722),
                        backgroundColor: _bgColor,
                        onSelected: (selected) {
                          setDialogState(() {
                            activeDiscount = percent.toDouble();
                            discountController.text =
                                percent > 0 ? '$percent' : '';
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: discountController,
                    keyboardType: TextInputType.number,
                    style:
                        GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                    cursorColor: const Color(0xFFFF5722),
                    decoration: _buildDialogInputDecoration(
                      LanguageService.text(
                          'Persentase Custom (%)', 'Custom Percentage (%)'),
                      Icons.percent_rounded,
                    ),
                    onChanged: (val) {
                      final p = double.tryParse(val) ?? 0.0;
                      setDialogState(() {
                        activeDiscount = p.clamp(0.0, 99.0);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Live Preview Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: activeDiscount > 0
                            ? const Color(0xFFFF5722).withValues(alpha: 0.4)
                            : _textSecondary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              LanguageService.text(
                                  'Harga Normal:', 'Regular Price:'),
                              style: GoogleFonts.poppins(
                                  color: _textSecondary, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _formatRupiah(rawPrice),
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: _textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (activeDiscount > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                LanguageService.text(
                                    'Potongan Diskon:', 'Discount Amount:'),
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFFFF5722),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '- ${_formatRupiah(savings)} (${activeDiscount.toStringAsFixed(activeDiscount.truncateToDouble() == activeDiscount ? 0 : 1)}%)',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFFF5722),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  LanguageService.text('Harga Setelah Diskon:',
                                      'Price After Discount:'),
                                  style: GoogleFonts.poppins(
                                      color: _textPrimary,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatRupiah(discountedPrice),
                                style: GoogleFonts.poppins(
                                  color: AppColors.success,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actionsOverflowButtonSpacing: 8,
            actionsAlignment: MainAxisAlignment.end,
            actions: [
              if (currentDiscount > 0)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error, size: 18),
                  label: Text(
                    LanguageService.text('Hapus Diskon', 'Remove Discount'),
                    style: GoogleFonts.poppins(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await DatabaseHelper.instance
                        .deleteProductDiscount(product['id'] as int);
                    await _loadProducts();
                    if (!mounted) return;
                    setState(() {});
                    final String pName =
                        product['nama']?.toString() ?? 'Produk';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          LanguageService.text(
                            'Diskon untuk "$pName" berhasil dihapus dari database & Firebase!',
                            'Discount for "$pName" removed from database & Firebase!',
                          ),
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  LanguageService.tr('batal'),
                  style: GoogleFonts.poppins(color: _textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () async {
                  final finalDiscount = activeDiscount.clamp(0.0, 99.0);
                  Navigator.pop(ctx);

                  await DatabaseHelper.instance.updateProductDiscount(
                    product['id'] as int,
                    finalDiscount,
                  );
                  await _loadProducts();

                  if (!mounted) return;
                  setState(() {});

                  final String pName = product['nama']?.toString() ?? 'Produk';
                  if (finalDiscount > 0) {
                    NotificationService.broadcastPromoDiscount(
                      context,
                      title:
                          '🔥 Promo Diskon $pName ${finalDiscount.toInt()}%!',
                      subject:
                          '🔥 Promo Spesial: Diskon ${finalDiscount.toInt()}% untuk $pName!',
                      message:
                          'Kabar gembira! Layanan $pName kini mendapatkan potongan harga spesial sebesar ${finalDiscount.toInt()}%. Manfaatkan kesempatan ini untuk berlangganan atau upgrade server Anda dengan harga terbaik di VibeTech XYZ!',
                      productName: pName,
                      discountPercent: finalDiscount.toInt(),
                    );
                  }

                  final msg = finalDiscount > 0
                      ? LanguageService.text(
                          'Diskon ${finalDiscount.toInt()}% untuk "$pName" berhasil disimpan ke database!',
                          '${finalDiscount.toInt()}% discount for "$pName" saved to database!',
                        )
                      : LanguageService.text(
                          'Diskon untuk "$pName" dinonaktifkan (kembali ke harga normal)!',
                          'Discount for "$pName" removed (back to normal price)!',
                        );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg, style: GoogleFonts.poppins()),
                      backgroundColor: finalDiscount > 0
                          ? AppColors.success
                          : AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                child: Text(
                  LanguageService.text('Simpan Diskon', 'Save Discount'),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // =====================================================
  // ===     DIALOG 3: PROMO DISKON MASSAL KATALOG     ===
  // =====================================================
  void _showGlobalPromoDialog() {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.text(
            'Akses Ditolak! Hanya Administrator yang dapat mengatur promo diskon massal.',
            'Access Denied! Only Administrators can set bulk discount promo.',
          )),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    String targetCategory = 'Semua';
    double promoDiscount = 20.0;
    final discountCtrl = TextEditingController(text: '20');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: _cardColor,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5722), Color(0xFFFF1744)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.campaign_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LanguageService.text(
                            'Promo Diskon Massal', 'Bulk Promo Discount'),
                        style: GoogleFonts.poppins(
                            color: _textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      Text(
                        LanguageService.text(
                            'Terapkan diskon ke seluruh katalog/kategori',
                            'Apply discount to all catalog/categories'),
                        style: GoogleFonts.poppins(
                            color: _textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LanguageService.text(
                        'Pilih Kategori Target:', 'Select Target Category:'),
                    style: GoogleFonts.poppins(
                        color: _textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: targetCategory,
                    dropdownColor: _cardColor,
                    isExpanded: true,
                    style:
                        GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                    decoration: _buildDialogInputDecoration(
                      LanguageService.tr('kategori'),
                      Icons.category_rounded,
                    ),
                    items: ['Semua', ..._categories].map((String cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(
                          cat == 'Semua'
                              ? LanguageService.text(
                                  'Semua Kategori (Katalog Penuh)',
                                  'All Categories (Full Catalog)')
                              : cat,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: GoogleFonts.poppins(color: _textPrimary),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => targetCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    LanguageService.text('Pilih Besaran Diskon (%):',
                        'Select Discount Percentage (%):'),
                    style: GoogleFonts.poppins(
                        color: _textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [0, 10, 15, 20, 25, 30, 50].map((percent) {
                      final isSelected = promoDiscount.toInt() == percent;
                      return ChoiceChip(
                        label: Text(
                          percent == 0
                              ? LanguageService.text('Reset (0%)', 'Reset (0%)')
                              : '$percent%',
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.white : _textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFFFF5722),
                        backgroundColor: _bgColor,
                        onSelected: (selected) {
                          setDialogState(() {
                            promoDiscount = percent.toDouble();
                            discountCtrl.text = '$percent';
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: discountCtrl,
                    keyboardType: TextInputType.number,
                    style:
                        GoogleFonts.poppins(color: _textPrimary, fontSize: 13),
                    cursorColor: const Color(0xFFFF5722),
                    decoration: _buildDialogInputDecoration(
                      LanguageService.text(
                          'Persentase Diskon (%)', 'Discount Percentage (%)'),
                      Icons.percent_rounded,
                    ),
                    onChanged: (val) {
                      final p = double.tryParse(val) ?? 0.0;
                      setDialogState(() {
                        promoDiscount = p.clamp(0.0, 99.0);
                      });
                    },
                  ),
                ],
              ),
            ),
            actionsOverflowButtonSpacing: 8,
            actionsAlignment: MainAxisAlignment.end,
            actions: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
                icon: const Icon(Icons.delete_sweep_rounded,
                    color: AppColors.error, size: 18),
                label: Text(
                  LanguageService.text('Hapus Diskon', 'Remove Discount'),
                  style: GoogleFonts.poppins(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await DatabaseHelper.instance
                      .removeCategoryDiscount(targetCategory);
                  if (!mounted) return;
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        LanguageService.text(
                          'Diskon untuk "$targetCategory" berhasil dihapus dari database & Firebase!',
                          'Discount for "$targetCategory" removed from database & Firebase!',
                        ),
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  LanguageService.tr('batal'),
                  style: GoogleFonts.poppins(color: _textSecondary),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                label: Text(
                  LanguageService.text(
                      'Terapkan Diskon Massal', 'Apply Bulk Discount'),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  final finalDiscount = promoDiscount.clamp(0.0, 99.0);
                  Navigator.pop(ctx);

                  await DatabaseHelper.instance.applyCategoryDiscount(
                    targetCategory,
                    finalDiscount,
                  );
                  await _loadProducts();

                  if (!mounted) return;
                  setState(() {});

                  if (finalDiscount > 0) {
                    NotificationService.broadcastPromoDiscount(
                      context,
                      title:
                          '🎉 Flash Sale Diskon ${finalDiscount.toInt()}%: $targetCategory!',
                      subject:
                          '🎉 Flash Sale Diskon Massal ${finalDiscount.toInt()}%: Kategori $targetCategory!',
                      message:
                          'Spesial untuk Anda, seluruh produk pada kategori $targetCategory kini mendapatkan potongan harga massal sebesar ${finalDiscount.toInt()}%. Buka aplikasi VibeTech XYZ sekarang dan nikmati hematnya!',
                      productName: targetCategory,
                      discountPercent: finalDiscount.toInt(),
                    );
                  }

                  final msg = finalDiscount > 0
                      ? LanguageService.text(
                          'Diskon massal ${finalDiscount.toInt()}% untuk "$targetCategory" berhasil diterapkan di database!',
                          'Bulk ${finalDiscount.toInt()}% discount for "$targetCategory" applied to database!',
                        )
                      : LanguageService.text(
                          'Diskon untuk "$targetCategory" berhasil di-reset ke harga normal!',
                          'Discount for "$targetCategory" reset to normal price!',
                        );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg, style: GoogleFonts.poppins()),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteProductDialog(int id, String productName) {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.text(
            'Akses Ditolak! Hanya Administrator yang dapat menghapus produk.',
            'Access Denied! Only Administrators can delete products.',
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
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                LanguageService.text(
                    'Hapus Produk Katalog?', 'Delete Catalog Product?'),
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          LanguageService.text(
            'Apakah Anda yakin ingin menghapus "$productName" dari katalog database VibeTech XYZ?',
            'Are you sure you want to delete "$productName" from VibeTech XYZ database catalog?',
          ),
          style: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
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
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper.instance.deleteProduct(id);
              await _loadProducts();
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    LanguageService.text(
                      'Produk "$productName" berhasil dihapus!',
                      'Product "$productName" successfully deleted!',
                    ),
                  ),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(LanguageService.tr('hapus'),
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminBanner(String currentCategory) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.16),
            AppColors.accent.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      LanguageService.text(
                          'Portal Kontrol Admin', 'Admin Control Portal'),
                      style: GoogleFonts.poppins(
                        color: _textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        LanguageService.text('MODE ADMIN', 'ADMIN MODE'),
                        style: GoogleFonts.poppins(
                          color: AppColors.cyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  LanguageService.text(
                    'Anda memiliki hak akses untuk menambah, mengubah, dan menghapus katalog di database.',
                    'You have permissions to create, edit, and delete catalog products in the database.',
                  ),
                  style: GoogleFonts.poppins(
                    color: _textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ElevatedButton.icon(
                onPressed: _showGlobalPromoDialog,
                icon: const Icon(Icons.local_offer_rounded,
                    size: 15, color: Colors.white),
                label: Text(LanguageService.text('Promo', 'Promo'),
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  visualDensity: VisualDensity.compact,
                  elevation: 0,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    _showAdminProductForm(category: currentCategory),
                icon: const Icon(Icons.add_rounded,
                    size: 16, color: Colors.white),
                label: Text(LanguageService.text('Tambah', 'Add'),
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  visualDensity: VisualDensity.compact,
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberBanner(String currentCategory) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? AppColors.darkCard.withValues(alpha: 0.8)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _textSecondary.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: widget.isDarkMode ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LanguageService.text('Katalog Layanan Resmi VibeTech XYZ',
                      'Official VibeTech XYZ Service Catalog'),
                  style: GoogleFonts.poppins(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  LanguageService.text(
                    'Pilih paket $currentCategory sesuai kebutuhan Anda. Diskon promo aktif otomatis terpotong saat pemesanan.',
                    'Select your $currentCategory package. Active promo discounts are automatically applied on order.',
                  ),
                  style: GoogleFonts.poppins(
                    color: _textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCategory = _categories[_selectedCategory];

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: _textPrimary),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                LanguageService.tr('katalog_produk'),
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    color: _textPrimary, fontWeight: FontWeight.bold),
              ),
            ),
            if (_isAdmin) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'ADMIN',
                  style: GoogleFonts.poppins(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.sync_rounded, color: AppColors.cyan, size: 22),
            tooltip: LanguageService.text(
                'Sinkronkan Diskon & Produk', 'Sync Discounts & Products'),
            onPressed: () async {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    LanguageService.text(
                        'Menyinkronkan diskon & produk dari Firebase...',
                        'Syncing discounts & products from Firebase...'),
                    style: GoogleFonts.poppins(),
                  ),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              await FirebaseProductService.instance.syncProductsFromFirebase();
              await _loadProducts();
              if (mounted) setState(() {});
            },
          ),
          if (_isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.local_offer_rounded,
                  color: Color(0xFFFF5722), size: 22),
              tooltip: LanguageService.text(
                  'Promo Diskon Massal', 'Bulk Promo Discount'),
              onPressed: _showGlobalPromoDialog,
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.cyan, size: 24),
              tooltip:
                  LanguageService.text('Tambah Produk Baru', 'Add New Product'),
              onPressed: () => _showAdminProductForm(category: currentCategory),
            ),
          ],
          Stack(
            alignment: Alignment.center,
            children: [
              BounceTap(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          KeranjangPage(isDarkMode: widget.isDarkMode)),
                ),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.shopping_bag_outlined,
                      color: AppColors.primary, size: 22),
                ),
              ),
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: CartService.notifier,
                builder: (_, items, ___) {
                  final count = items.fold<int>(
                      0,
                      (sum, e) =>
                          sum + ((e['quantity'] as num?)?.toInt() ?? 1));
                  if (count == 0) return const SizedBox();
                  return Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: AppColors.success, shape: BoxShape.circle),
                      child: Text('$count',
                          style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          if (widget.isDarkMode)
            const CyberParticlesLayer(count: 18),
          Builder(
            builder: (context) {
              final filteredProducts = _products.where((p) {
                final cat = p['kategori']?.toString().toLowerCase() ?? '';
                return cat.contains(currentCategory.toLowerCase());
              }).toList();

              return Column(
                children: [
                  // Category Filter Tab
                  SizedBox(
                    height: 65,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final isSelected = _selectedCategory == index;
                        return BounceTap(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedCategory = index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? AppColors.primary : _cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : _textSecondary.withValues(alpha: 0.1)),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              children: [
                                Icon(_categoryIcons[_categories[index]],
                                    color: isSelected
                                        ? Colors.white
                                        : _textSecondary,
                                    size: 18),
                                const SizedBox(width: 8),
                                Text(_categories[index],
                                    style: GoogleFonts.poppins(
                                        color: isSelected
                                            ? Colors.white
                                            : _textPrimary,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Banner Khusus Admin atau Member
                  if (_isAdmin)
                    _buildAdminBanner(currentCategory)
                  else
                    _buildMemberBanner(currentCategory),

                  // Product List
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: _cardColor,
                      onRefresh: () async {
                        await FirebaseProductService.instance
                            .syncProductsFromFirebase();
                        if (mounted) setState(() {});
                      },
                      child: filteredProducts.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics()),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.4,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.inventory_2_outlined,
                                            size: 60,
                                            color: _textSecondary.withValues(
                                                alpha: 0.3)),
                                        const SizedBox(height: 12),
                                        Text(
                                          LanguageService.text(
                                            'Belum ada produk di kategori $currentCategory.',
                                            'No products available in $currentCategory.',
                                          ),
                                          style: GoogleFonts.poppins(
                                              color: _textSecondary,
                                              fontSize: 13),
                                        ),
                                        if (_isAdmin) ...[
                                          const SizedBox(height: 16),
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _showAdminProductForm(
                                                    category: currentCategory),
                                            icon: const Icon(Icons.add,
                                                color: Colors.white, size: 18),
                                            label: Text(
                                              LanguageService.text(
                                                  'Tambah Produk $currentCategory',
                                                  'Add $currentCategory Product'),
                                              style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics()),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: _isAdmin
                                  ? filteredProducts.length + 1
                                  : filteredProducts.length,
                              itemBuilder: (context, index) {
                                if (index == filteredProducts.length &&
                                    _isAdmin) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        top: 10, bottom: 30),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: BounceTap(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          _showAdminProductForm(
                                              category: currentCategory);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 18, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.add_rounded,
                                                  color: Colors.white,
                                                  size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                LanguageService.text(
                                                    'Tambah Produk $currentCategory',
                                                    'Add $currentCategory Product'),
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final product = filteredProducts[index];
                                final productCategory =
                                    product['kategori']?.toString() ??
                                        currentCategory;
                                final iconData =
                                    _getIconForCategory(productCategory);
                                final double rawHarga =
                                    (product['harga'] as num?)?.toDouble() ??
                                        0.0;
                                final double diskon =
                                    (product['diskon'] as num?)?.toDouble() ??
                                        0.0;
                                final bool hasDiscount = diskon > 0;
                                final double hargaFinal = hasDiscount
                                    ? (rawHarga * (1.0 - (diskon / 100.0)))
                                    : rawHarga;
                                final int stok =
                                    (product['stok'] as num?)?.toInt() ?? 0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: _cardColor,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: hasDiscount
                                              ? const Color(0xFFFF5722)
                                                  .withValues(alpha: 0.45)
                                              : (_isAdmin
                                                  ? AppColors.primary
                                                      .withValues(alpha: 0.2)
                                                  : _textSecondary.withValues(
                                                      alpha: 0.08)),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: hasDiscount
                                                ? const Color(0xFFFF5722)
                                                    .withValues(alpha: 0.08)
                                                : Colors.black.withValues(
                                                    alpha: widget.isDarkMode
                                                        ? 0.2
                                                        : 0.03),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          )
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Top Row: Category icon, name, stock badge, discount badge, and price
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: hasDiscount
                                                      ? const Color(0xFFFF5722)
                                                          .withValues(
                                                              alpha: 0.14)
                                                      : AppColors.primary
                                                          .withValues(
                                                              alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: Icon(
                                                  iconData,
                                                  color: hasDiscount
                                                      ? const Color(0xFFFF5722)
                                                      : AppColors.primary,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            product['nama']
                                                                    ?.toString() ??
                                                                '',
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  _textPrimary,
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Wrap(
                                                          spacing: 6,
                                                          runSpacing: 4,
                                                          crossAxisAlignment:
                                                              WrapCrossAlignment
                                                                  .center,
                                                          children: [
                                                            if (hasDiscount)
                                                              Container(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        7,
                                                                    vertical:
                                                                        2.5),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  gradient:
                                                                      const LinearGradient(
                                                                    colors: [
                                                                      Color(
                                                                          0xFFFF5722),
                                                                      Color(
                                                                          0xFFFF1744)
                                                                    ],
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              7),
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                      color: const Color(
                                                                              0xFFFF5722)
                                                                          .withValues(
                                                                              alpha: 0.35),
                                                                      blurRadius:
                                                                          4,
                                                                      offset:
                                                                          const Offset(
                                                                              0,
                                                                              1.5),
                                                                    ),
                                                                  ],
                                                                ),
                                                                child: Text(
                                                                  'DISKON ${diskon.toStringAsFixed(diskon.truncateToDouble() == diskon ? 0 : 1)}%',
                                                                  style: GoogleFonts
                                                                      .poppins(
                                                                    color: Colors
                                                                        .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                    fontSize:
                                                                        9.5,
                                                                  ),
                                                                ),
                                                              ),
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          3),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: (stok > 0
                                                                        ? AppColors
                                                                            .success
                                                                        : AppColors
                                                                            .error)
                                                                    .withValues(
                                                                        alpha:
                                                                            0.15),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                              ),
                                                              child: Text(
                                                                LanguageService.text(
                                                                    'Stok: $stok',
                                                                    'Stock: $stok'),
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: stok >
                                                                          0
                                                                      ? AppColors
                                                                          .success
                                                                      : AppColors
                                                                          .error,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 10,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    if (hasDiscount)
                                                      Wrap(
                                                        spacing: 8,
                                                        crossAxisAlignment:
                                                            WrapCrossAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            _formatRupiah(
                                                                hargaFinal),
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: AppColors
                                                                  .success,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              fontSize: 15.5,
                                                            ),
                                                          ),
                                                          Text(
                                                            _formatRupiah(
                                                                rawHarga),
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: _textSecondary
                                                                  .withValues(
                                                                      alpha:
                                                                          0.6),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              fontSize: 11.5,
                                                              decoration:
                                                                  TextDecoration
                                                                      .lineThrough,
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    else
                                                      Text(
                                                        _formatRupiah(rawHarga),
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color:
                                                              AppColors.primary,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            product['deskripsi']?.toString() ??
                                                '',
                                            style: GoogleFonts.poppins(
                                              color: _textSecondary,
                                              fontSize: 12,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Divider(height: 1),
                                          const SizedBox(height: 10),

                                          // Bottom Row: Action buttons based on Role (No overflow guaranteed)
                                          Row(
                                            children: [
                                              if (_isAdmin) ...[
                                                // Admin Controls: Diskon, Edit & Delete
                                                Expanded(
                                                  child: Wrap(
                                                    spacing: 6,
                                                    runSpacing: 6,
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment
                                                            .center,
                                                    children: [
                                                      InkWell(
                                                        onTap: () {
                                                          HapticFeedback
                                                              .lightImpact();
                                                          _showSetDiscountDialog(
                                                              product);
                                                        },
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 9,
                                                                  vertical: 5),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: const Color(
                                                                    0xFFFF5722)
                                                                .withValues(
                                                                    alpha:
                                                                        0.12),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            border: Border.all(
                                                                color: const Color(
                                                                        0xFFFF5722)
                                                                    .withValues(
                                                                        alpha:
                                                                            0.35)),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              const Icon(
                                                                  Icons
                                                                      .percent_rounded,
                                                                  color: Color(
                                                                      0xFFFF5722),
                                                                  size: 13),
                                                              const SizedBox(
                                                                  width: 3),
                                                              Text(
                                                                LanguageService.text(
                                                                    'Diskon',
                                                                    'Discount'),
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: const Color(
                                                                      0xFFFF5722),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize:
                                                                      10.5,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      InkWell(
                                                        onTap: () {
                                                          HapticFeedback
                                                              .lightImpact();
                                                          _showAdminProductForm(
                                                            product: product,
                                                            category:
                                                                productCategory,
                                                          );
                                                        },
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 9,
                                                                  vertical: 5),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: AppColors
                                                                .cyan
                                                                .withValues(
                                                                    alpha:
                                                                        0.12),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            border: Border.all(
                                                                color: AppColors
                                                                    .cyan
                                                                    .withValues(
                                                                        alpha:
                                                                            0.3)),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              const Icon(
                                                                  Icons
                                                                      .edit_rounded,
                                                                  color:
                                                                      AppColors
                                                                          .cyan,
                                                                  size: 13),
                                                              const SizedBox(
                                                                  width: 3),
                                                              Text(
                                                                LanguageService
                                                                    .text(
                                                                        'Edit',
                                                                        'Edit'),
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color:
                                                                      AppColors
                                                                          .cyan,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize:
                                                                      10.5,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      InkWell(
                                                        onTap: () {
                                                          HapticFeedback
                                                              .lightImpact();
                                                          _showDeleteProductDialog(
                                                            product['id']
                                                                as int,
                                                            product['nama']
                                                                    ?.toString() ??
                                                                '',
                                                          );
                                                        },
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 9,
                                                                  vertical: 5),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: AppColors
                                                                .error
                                                                .withValues(
                                                                    alpha:
                                                                        0.12),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            border: Border.all(
                                                                color: AppColors
                                                                    .error
                                                                    .withValues(
                                                                        alpha:
                                                                            0.3)),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              const Icon(
                                                                  Icons
                                                                      .delete_outline_rounded,
                                                                  color:
                                                                      AppColors
                                                                          .error,
                                                                  size: 13),
                                                              const SizedBox(
                                                                  width: 3),
                                                              Text(
                                                                LanguageService
                                                                    .tr('hapus'),
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color:
                                                                      AppColors
                                                                          .error,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize:
                                                                      10.5,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ] else ...[
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                          Icons
                                                              .verified_user_outlined,
                                                          color:
                                                              AppColors.success,
                                                          size: 14),
                                                      const SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          hasDiscount
                                                              ? LanguageService.text(
                                                                  'Harga Spesial Promo',
                                                                  'Special Promo Price')
                                                              : LanguageService.text(
                                                                  'Garansi Aktif 24/7',
                                                                  '24/7 Active Warranty'),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: hasDiscount
                                                                ? const Color(
                                                                    0xFFFF5722)
                                                                : _textSecondary,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                hasDiscount
                                                                    ? FontWeight
                                                                        .bold
                                                                    : FontWeight
                                                                        .normal,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],

                                              const SizedBox(width: 8),

                                              // Pesan Button
                                              BounceTap(
                                                onTap: () {
                                                  HapticFeedback
                                                      .selectionClick();
                                                  _showOrderDialog(
                                                      product,
                                                      productCategory,
                                                      _cardColor,
                                                      _textPrimary,
                                                      _textSecondary);
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                          Icons
                                                              .shopping_bag_outlined,
                                                          color: Colors.white,
                                                          size: 14),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        LanguageService.text(
                                                            'Pesan', 'Order'),
                                                        style:
                                                            GoogleFonts.poppins(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                              },
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
