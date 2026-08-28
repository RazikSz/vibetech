import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/language_service.dart';

/// Model data representasi akun Google
class GoogleAccountUser {
  final String name;
  final String email;
  final String? avatarUrl;
  final Color avatarColor;

  const GoogleAccountUser({
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.avatarColor,
  });
}

/// Menampilkan Google Account Picker Bottom Sheet
Future<GoogleAccountUser?> showGoogleAccountPicker(
  BuildContext context, {
  required bool isDarkMode,
  bool isRegisterMode = false,
}) async {
  return await showModalBottomSheet<GoogleAccountUser>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => GoogleAccountPickerModal(
      isDarkMode: isDarkMode,
      isRegisterMode: isRegisterMode,
    ),
  );
}

class GoogleAccountPickerModal extends StatefulWidget {
  final bool isDarkMode;
  final bool isRegisterMode;

  const GoogleAccountPickerModal({
    super.key,
    required this.isDarkMode,
    required this.isRegisterMode,
  });

  @override
  State<GoogleAccountPickerModal> createState() =>
      _GoogleAccountPickerModalState();
}

class _GoogleAccountPickerModalState extends State<GoogleAccountPickerModal> {
  final List<GoogleAccountUser> _accounts = [];
  bool _isLoading = true;
  String? _selectedEmail;

  final List<Color> _avatarColors = const [
    Color(0xFF4285F4), // Google Blue
    Color(0xFF34A853), // Google Green
    Color(0xFFEA4335), // Google Red
    Color(0xFFFBBC05), // Google Yellow
    Color(0xFF8E24AA), // Purple
    Color(0xFF00ACC1), // Cyan
    Color(0xFFFF7043), // Deep Orange
  ];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final List<GoogleAccountUser> loaded = [];

    // 1. Muat akun Gmail yang tersimpan di SQLite jika ada
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'users',
        where: 'email LIKE ? OR uid LIKE ?',
        whereArgs: ['%@gmail.com%', 'goog_%'],
      );

      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        final email = row['email']?.toString() ?? '';
        final name = row['nama']?.toString() ??
            row['username']?.toString() ??
            'Pengguna Google';

        if (email.isNotEmpty && !loaded.any((a) => a.email == email)) {
          loaded.add(
            GoogleAccountUser(
              name: name,
              email: email,
              avatarUrl: row['avatarUrl']?.toString(),
              avatarColor: _avatarColors[i % _avatarColors.length],
            ),
          );
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _accounts.clear();
        _accounts.addAll(loaded);
        _isLoading = false;
      });
    }
  }

  void _chooseAccount(GoogleAccountUser account) async {
    HapticFeedback.selectionClick();
    setState(() => _selectedEmail = account.email);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      Navigator.of(context).pop(account);
    }
  }

  Future<void> _showAddNewAccountDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<GoogleAccountUser>(
      context: context,
      builder: (dialogCtx) {
        final isDark = widget.isDarkMode;
        final bg = isDark ? const Color(0xFF14192B) : Colors.white;
        final textPri = isDark ? Colors.white : const Color(0xFF1E293B);
        final textSec =
            isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final fieldBg = isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF1F5F9);

        return AlertDialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark
                  ? const Color(0xFF7C4DFF).withValues(alpha: 0.3)
                  : Colors.black12,
            ),
          ),
          title: Row(
            children: [
              _buildGoogleLogoBadge(size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  LanguageService.text(
                    'Gunakan Akun Google Lain',
                    'Use Another Google Account',
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPri,
                  ),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    LanguageService.text(
                      'Masukkan informasi akun Google yang ingin Anda gunakan:',
                      'Enter the Google account details you wish to use:',
                    ),
                    style: GoogleFonts.poppins(fontSize: 12.5, color: textSec),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    style: GoogleFonts.poppins(color: textPri, fontSize: 13.5),
                    decoration: InputDecoration(
                      labelText:
                          LanguageService.text('Nama Lengkap', 'Full Name'),
                      labelStyle:
                          GoogleFonts.poppins(color: textSec, fontSize: 13),
                      prefixIcon: const Icon(Icons.person_outline_rounded,
                          size: 19, color: Color(0xFF4285F4)),
                      filled: true,
                      fillColor: fieldBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return LanguageService.text(
                            'Nama wajib diisi', 'Name is required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.poppins(color: textPri, fontSize: 13.5),
                    decoration: InputDecoration(
                      labelText: LanguageService.text(
                          'Alamat Email Google (@gmail.com)',
                          'Google Email Address (@gmail.com)'),
                      hintText: 'namaanda@gmail.com',
                      hintStyle: GoogleFonts.poppins(
                          color: textSec.withValues(alpha: 0.6), fontSize: 12),
                      labelStyle:
                          GoogleFonts.poppins(color: textSec, fontSize: 13),
                      prefixIcon: const Icon(Icons.mail_outline_rounded,
                          size: 19, color: Color(0xFFEA4335)),
                      filled: true,
                      fillColor: fieldBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return LanguageService.text(
                            'Email wajib diisi', 'Email is required');
                      }
                      if (!val.contains('@') || !val.contains('.')) {
                        return LanguageService.text(
                            'Format email tidak valid', 'Invalid email format');
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                LanguageService.text('Batal', 'Cancel'),
                style: GoogleFonts.poppins(
                    color: textSec, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final String name = nameCtrl.text.trim();
                  String email = emailCtrl.text.trim();
                  if (!email.contains('@')) {
                    email = '$email@gmail.com';
                  }

                  final newAcc = GoogleAccountUser(
                    name: name,
                    email: email,
                    avatarColor: _avatarColors[
                        math.Random().nextInt(_avatarColors.length)],
                  );
                  Navigator.pop(dialogCtx, newAcc);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              child: Text(
                LanguageService.text('Gunakan Akun', 'Use Account'),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Widget _buildGoogleLogoBadge({double size = 28}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'G',
          style: GoogleFonts.poppins(
            color: const Color(0xFF4285F4),
            fontSize: size * 0.65,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final Color sheetBg =
        isDark ? const Color(0xFF0F1426) : const Color(0xFFFFFFFF);
    final Color primaryText = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color secondaryText =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color cardBg =
        isDark ? const Color(0xFF161C33) : const Color(0xFFF8FAFC);
    final Color borderColor = isDark
        ? const Color(0xFF7C4DFF).withValues(alpha: 0.22)
        : const Color(0xFFE2E8F0);

    return Container(
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark
              ? const Color(0xFF00E5FF).withValues(alpha: 0.25)
              : const Color(0xFF7C4DFF).withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0xFF7C4DFF).withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 2. Google Header & Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildGoogleLogoBadge(size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LanguageService.text(
                            'Pilih Akun Google',
                            'Choose a Google Account',
                          ),
                          style: GoogleFonts.poppins(
                            color: primaryText,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          LanguageService.text(
                            widget.isRegisterMode
                                ? 'untuk mendaftar ke VibeTech XYZ'
                                : 'untuk melanjutkan ke VibeTech XYZ',
                            widget.isRegisterMode
                                ? 'to register to VibeTech XYZ'
                                : 'to continue to VibeTech XYZ',
                          ),
                          style: GoogleFonts.poppins(
                            color: secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: secondaryText, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Divider(color: borderColor, height: 1),
              const SizedBox(height: 14),

              // 3. List of Google Accounts
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else if (_accounts.isEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.account_circle_outlined,
                        color: secondaryText,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        LanguageService.text(
                          'Belum ada akun Google terdaftar',
                          'No Google accounts registered yet',
                        ),
                        style: GoogleFonts.poppins(
                          color: primaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        LanguageService.text(
                          'Tekan tombol di bawah untuk menambahkan akun Google Anda',
                          'Tap the button below to add your Google account',
                        ),
                        style: GoogleFonts.poppins(
                          color: secondaryText,
                          fontSize: 11.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final acc = _accounts[idx];
                      final isSelected = _selectedEmail == acc.email;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _chooseAccount(acc),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4285F4)
                                      .withValues(alpha: 0.15)
                                  : cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF4285F4)
                                    : borderColor,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Avatar circle with initial or icon
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: acc.avatarColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: acc.avatarColor
                                            .withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      acc.name.isNotEmpty
                                          ? acc.name[0].toUpperCase()
                                          : 'G',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Account Name & Email
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        acc.name,
                                        style: GoogleFonts.poppins(
                                          color: primaryText,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        acc.email,
                                        style: GoogleFonts.poppins(
                                          color: secondaryText,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Check or Arrow icon
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF4285F4),
                                    size: 22,
                                  )
                                else
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: secondaryText.withValues(alpha: 0.5),
                                    size: 14,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 12),

              // 4. Button "+ Gunakan akun lain"
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showAddNewAccountDialog,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: borderColor,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_add_alt_1_rounded,
                            color: isDark
                                ? const Color(0xFF00E5FF)
                                : const Color(0xFF7C4DFF),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            LanguageService.text(
                              'Gunakan akun Google lain',
                              'Use another Google account',
                            ),
                            style: GoogleFonts.poppins(
                              color: isDark
                                  ? const Color(0xFF00E5FF)
                                  : const Color(0xFF7C4DFF),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.add_rounded,
                          color: isDark
                              ? const Color(0xFF00E5FF)
                              : const Color(0xFF7C4DFF),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 5. Privacy & Google disclaimer footer
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  LanguageService.text(
                    'Untuk melanjutkan, Google akan membagikan nama, alamat email, dan foto profil Anda ke VibeTech XYZ. Lihat Kebijakan Privasi.',
                    'To continue, Google will share your name, email address, and profile photo with VibeTech XYZ. See Privacy Policy.',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: secondaryText.withValues(alpha: 0.8),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
