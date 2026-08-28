import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/github_auth_service.dart';
import 'package:vibetech_xyz/services/language_service.dart';

/// Model data representasi akun GitHub terintegrasi Firebase
class GithubAccountUser {
  final String name;
  final String username;
  final String email;
  final String? password;
  final String? avatarUrl;
  final String? bio;
  final String? accessToken;
  final String? firebaseUid;
  final Color avatarColor;
  final String authProvider;

  const GithubAccountUser({
    required this.name,
    required this.username,
    required this.email,
    this.password,
    this.avatarUrl,
    this.bio,
    this.accessToken,
    this.firebaseUid,
    required this.avatarColor,
    this.authProvider = 'GitHub',
  });
}

/// Menampilkan Dialog Modal "Pilih & Hubungkan Akun GitHub"
Future<GithubAccountUser?> showGithubCredentialPrompt(
  BuildContext context, {
  required bool isDarkMode,
  bool isRegisterMode = false,
}) async {
  return await showModalBottomSheet<GithubAccountUser>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => GithubAccountPickerModal(
      isDarkMode: isDarkMode,
      isRegisterMode: isRegisterMode,
    ),
  );
}

/// Modal Pemilihan & Pendaftaran Akun GitHub Cepat (100% In-App & Firebase Guaranteed)
class GithubAccountPickerModal extends StatefulWidget {
  final bool isDarkMode;
  final bool isRegisterMode;

  const GithubAccountPickerModal({
    super.key,
    required this.isDarkMode,
    required this.isRegisterMode,
  });

  @override
  State<GithubAccountPickerModal> createState() =>
      _GithubAccountPickerModalState();
}

class _GithubAccountPickerModalState extends State<GithubAccountPickerModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final List<GithubAccountUser> _accounts = [];
  bool _isLoading = true;
  bool _isFetchingApi = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _selectedUsername;
  String? _fetchedAvatarUrl;
  String? _fetchedBio;

  @override
  void initState() {
    super.initState();
    _loadExistingGithubAccounts();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Memuat akun-akun GitHub yang pernah terdaftar di database lokal SQLite
  Future<void> _loadExistingGithubAccounts() async {
    final List<GithubAccountUser> loaded = [];

    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'users',
        where:
            "authProvider = 'GitHub' OR email LIKE '%@github.com%' OR avatarUrl LIKE '%github%'",
      );

      for (final row in rows) {
        final email = row['email']?.toString() ?? '';
        final username = row['username']?.toString() ??
            (email.contains('@') ? email.split('@').first : 'github_user');
        final name = row['nama']?.toString() ?? username;
        final avatar = row['avatarUrl']?.toString() ??
            'https://avatars.githubusercontent.com/$username';
        final password = row['password']?.toString() ?? 'github_oauth_pass123';
        final uid = row['uid']?.toString();

        if (!loaded
            .any((a) => a.username.toLowerCase() == username.toLowerCase())) {
          loaded.add(
            GithubAccountUser(
              name: name,
              username: username,
              email: email.isNotEmpty ? email : '$username@github.com',
              password: password,
              avatarUrl: avatar,
              firebaseUid: uid,
              avatarColor: const Color(0xFF24292F),
              authProvider: 'GitHub',
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

  void _chooseAccount(GithubAccountUser account) async {
    HapticFeedback.selectionClick();
    if (mounted) {
      setState(() => _selectedUsername = account.username);
    }
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      Navigator.of(context).pop(account);
    }
  }

  /// Mengambil data profil publik langsung dari API resmi GitHub saat pengguna mengetik username
  Future<void> _fetchGithubInfo(String username) async {
    final cleanUser = username.trim();
    if (cleanUser.isEmpty) return;

    if (mounted) {
      setState(() {
        _isFetchingApi = true;
        _fetchedAvatarUrl = 'https://avatars.githubusercontent.com/$cleanUser';
        if (_emailController.text.isEmpty) {
          _emailController.text = '$cleanUser@github.com';
        }
      });
    }

    try {
      final res = await http
          .get(Uri.parse('https://api.github.com/users/$cleanUser'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            if (data['avatar_url'] != null &&
                data['avatar_url'].toString().isNotEmpty) {
              _fetchedAvatarUrl = data['avatar_url'];
            }
            if (data['name'] != null && _nameController.text.isEmpty) {
              _nameController.text = data['name'];
            }
            if (data['email'] != null && _emailController.text.isEmpty) {
              _emailController.text = data['email'];
            }
            if (data['bio'] != null) {
              _fetchedBio = data['bio'];
            }
          });
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isFetchingApi = false);
  }

  Future<void> _handleNativeOAuthSignIn() async {
    HapticFeedback.mediumImpact();
    if (mounted) setState(() => _isSubmitting = true);
    try {
      final user = await GithubAuthService.signInWithOAuthWebView(
        context,
        isDarkMode: widget.isDarkMode,
        isRegisterMode: widget.isRegisterMode,
      );
      if (user != null && mounted) {
        Navigator.of(context).pop(user);
        return;
      }
    } catch (e) {
      debugPrint('[GithubAccountPickerModal] OAuth signIn error: $e');
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  void _submitNewAccount() {
    if (_formKey.currentState?.validate() ?? false) {
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _isSubmitting = true);

      final username = _usernameController.text.trim();
      String name = _nameController.text.trim();
      if (name.isEmpty) name = username;

      String email = _emailController.text.trim();
      if (!email.contains('@')) {
        email = '$username@github.com';
      }

      String password = _passwordController.text.trim();
      if (password.isEmpty) {
        password = 'github_oauth_pass123';
      }

      final account = GithubAccountUser(
        name: name,
        username: username,
        email: email,
        password: password,
        avatarUrl: _fetchedAvatarUrl ??
            'https://avatars.githubusercontent.com/$username',
        bio: _fetchedBio,
        firebaseUid: null,
        avatarColor: const Color(0xFF24292F),
        authProvider: 'GitHub',
      );

      Navigator.of(context).pop(account);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final Color sheetBg =
        isDark ? const Color(0xFF0D1117) : const Color(0xFFFFFFFF);
    final Color primaryText = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color secondaryText =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);
    final Color dividerColor =
        isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final Color cardBg =
        isDark ? const Color(0xFF161B22) : const Color(0xFFF6F8FA);
    final Color fieldBorder =
        isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Header Akun GitHub
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF24292F),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.code_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LanguageService.text(
                              widget.isRegisterMode
                                  ? 'Daftar Akun dengan GitHub'
                                  : 'Masuk dengan Akun GitHub',
                              widget.isRegisterMode
                                  ? 'Register with GitHub'
                                  : 'Sign In with GitHub',
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                          Text(
                            LanguageService.text(
                              'Otomatis terhubung ke Firebase Authentication',
                              'Automatically synced to Firebase Authentication',
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: secondaryText, size: 22),
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: dividerColor),

              // Konten Form & Daftar Akun
              Flexible(
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF8250DF),
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Tombol Masuk / Daftar via Akun GitHub Resmi (Selalu Muncul di Paling Atas)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 18),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF24292F),
                                    Color(0xFF1B1F23)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF8250DF),
                                  width: 1.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8250DF)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isSubmitting
                                      ? null
                                      : _handleNativeOAuthSignIn,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 15),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.code_rounded,
                                              color: Colors.white, size: 22),
                                        ),
                                        const SizedBox(width: 12),
                                        Flexible(
                                          child: Text(
                                            LanguageService.text(
                                              'Daftar / Masuk dengan GitHub Resmi (1-Klik)',
                                              'Register / Sign In with Official GitHub (1-Click)',
                                            ),
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            color: Colors.white70,
                                            size: 14),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // 2. Jika ada akun yang pernah terdaftar sebelumnya (1-Tap Selection)
                            if (_accounts.isNotEmpty) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 4, bottom: 8),
                                child: Text(
                                  LanguageService.text(
                                    'PILIH AKUN TERSEDIA (1-TAP)',
                                    'SELECT AVAILABLE ACCOUNT (1-TAP)',
                                  ),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                    color: const Color(0xFF8250DF),
                                  ),
                                ),
                              ),
                              ..._accounts.map((acc) => _buildAccountTile(
                                    acc,
                                    isDark: isDark,
                                    cardBg: cardBg,
                                    primaryText: primaryText,
                                    secondaryText: secondaryText,
                                  )),
                              const SizedBox(height: 14),
                            ],

                            Row(
                              children: [
                                Expanded(child: Divider(color: dividerColor)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(
                                    LanguageService.text(
                                        'ATAU DAFTAR DENGAN USERNAME',
                                        'OR REGISTER WITH USERNAME'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: secondaryText,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: dividerColor)),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // 2. Form Hubungkan / Daftarkan Akun GitHub Baru
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: fieldBorder),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // Live Preview Avatar
                                        Container(
                                          padding: const EdgeInsets.all(2.5),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF8250DF),
                                              width: 2,
                                            ),
                                          ),
                                          child: CircleAvatar(
                                            radius: 22,
                                            backgroundImage:
                                                _fetchedAvatarUrl != null
                                                    ? NetworkImage(
                                                        _fetchedAvatarUrl!)
                                                    : null,
                                            backgroundColor:
                                                const Color(0xFF24292F),
                                            child: _fetchedAvatarUrl == null
                                                ? const Icon(Icons.person,
                                                    color: Colors.white70,
                                                    size: 22)
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                LanguageService.text(
                                                  widget.isRegisterMode
                                                      ? 'Daftar Akun Baru'
                                                      : 'Hubungkan Akun Baru',
                                                  widget.isRegisterMode
                                                      ? 'Register New Account'
                                                      : 'Connect New Account',
                                                ),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryText,
                                                ),
                                              ),
                                              Text(
                                                _fetchedBio != null &&
                                                        _fetchedBio!.isNotEmpty
                                                    ? _fetchedBio!
                                                    : LanguageService.text(
                                                        'Masukkan username GitHub Anda',
                                                        'Enter your GitHub username',
                                                      ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: secondaryText,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Input Username GitHub
                                    TextFormField(
                                      controller: _usernameController,
                                      style: GoogleFonts.poppins(
                                          color: primaryText, fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: LanguageService.text(
                                          'Username GitHub',
                                          'GitHub Username',
                                        ),
                                        hintText: 'misal: RazikSz',
                                        hintStyle: GoogleFonts.poppins(
                                            color: secondaryText.withValues(
                                                alpha: 0.5),
                                            fontSize: 12),
                                        labelStyle: GoogleFonts.poppins(
                                            color: secondaryText,
                                            fontSize: 12.5),
                                        prefixIcon: const Icon(
                                            Icons.alternate_email_rounded,
                                            size: 18,
                                            color: Color(0xFF8250DF)),
                                        suffixIcon: _isFetchingApi
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Color(0xFF8250DF),
                                                  ),
                                                ),
                                              )
                                            : null,
                                        filled: true,
                                        fillColor: isDark
                                            ? const Color(0xFF0D1117)
                                            : Colors.white,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide:
                                              BorderSide(color: fieldBorder),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF8250DF),
                                              width: 1.5),
                                        ),
                                      ),
                                      onChanged: (val) {
                                        if (val.trim().length >= 2) {
                                          _fetchGithubInfo(val);
                                        }
                                      },
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return LanguageService.text(
                                            'Username GitHub wajib diisi',
                                            'GitHub username is required',
                                          );
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // Input Email
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      style: GoogleFonts.poppins(
                                          color: primaryText, fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: LanguageService.text(
                                          'Alamat Email',
                                          'Email Address',
                                        ),
                                        hintText: 'nama@gmail.com',
                                        hintStyle: GoogleFonts.poppins(
                                            color: secondaryText.withValues(
                                                alpha: 0.5),
                                            fontSize: 12),
                                        labelStyle: GoogleFonts.poppins(
                                            color: secondaryText,
                                            fontSize: 12.5),
                                        prefixIcon: const Icon(
                                            Icons.mail_outline_rounded,
                                            size: 18,
                                            color: Color(0xFF2EA44F)),
                                        filled: true,
                                        fillColor: isDark
                                            ? const Color(0xFF0D1117)
                                            : Colors.white,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide:
                                              BorderSide(color: fieldBorder),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF2EA44F),
                                              width: 1.5),
                                        ),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return LanguageService.text(
                                            'Email wajib diisi',
                                            'Email is required',
                                          );
                                        }
                                        if (!val.contains('@')) {
                                          return LanguageService.text(
                                            'Format email tidak valid',
                                            'Invalid email format',
                                          );
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // Input Password
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      style: GoogleFonts.poppins(
                                          color: primaryText, fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: LanguageService.text(
                                          'Password Akun GitHub',
                                          'GitHub Account Password',
                                        ),
                                        hintText: 'Minimal 6 karakter',
                                        hintStyle: GoogleFonts.poppins(
                                            color: secondaryText.withValues(
                                                alpha: 0.5),
                                            fontSize: 12),
                                        labelStyle: GoogleFonts.poppins(
                                            color: secondaryText,
                                            fontSize: 12.5),
                                        prefixIcon: const Icon(
                                            Icons.lock_outline_rounded,
                                            size: 18,
                                            color: Color(0xFFF0883E)),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            size: 18,
                                            color: secondaryText,
                                          ),
                                          onPressed: () {
                                            if (mounted) {
                                              setState(() => _obscurePassword =
                                                  !_obscurePassword);
                                            }
                                          },
                                        ),
                                        filled: true,
                                        fillColor: isDark
                                            ? const Color(0xFF0D1117)
                                            : Colors.white,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide:
                                              BorderSide(color: fieldBorder),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFF0883E),
                                              width: 1.5),
                                        ),
                                      ),
                                      validator: (val) {
                                        if (val != null &&
                                            val.isNotEmpty &&
                                            val.length < 6) {
                                          return LanguageService.text(
                                            'Password minimal 6 karakter',
                                            'Password must be at least 6 characters',
                                          );
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 18),

                                    // Tombol Submit Utama
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF238636),
                                              Color(0xFF2EA44F)
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF238636)
                                                  .withValues(alpha: 0.35),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: _isSubmitting
                                              ? null
                                              : _submitNewAccount,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: _isSubmitting
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2.5,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                        Icons
                                                            .cloud_done_rounded,
                                                        color: Colors.white,
                                                        size: 18),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      LanguageService.text(
                                                        widget.isRegisterMode
                                                            ? 'Daftar & Hubungkan ke Firebase'
                                                            : 'Masuk & Sinkronkan Akun',
                                                        widget.isRegisterMode
                                                            ? 'Register & Sync to Firebase'
                                                            : 'Sign In & Sync Account',
                                                      ),
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13.5,
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
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountTile(
    GithubAccountUser acc, {
    required bool isDark,
    required Color cardBg,
    required Color primaryText,
    required Color secondaryText,
  }) {
    final isSelected = _selectedUsername == acc.username;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF8250DF).withValues(alpha: 0.15)
            : cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF8250DF)
              : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _chooseAccount(acc),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Avatar GitHub
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: acc.avatarUrl != null && acc.avatarUrl!.isNotEmpty
                      ? Image.network(
                          acc.avatarUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildAvatarFallback(acc),
                        )
                      : _buildAvatarFallback(acc),
                ),
                const SizedBox(width: 14),

                // Info Akun
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              acc.name,
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF24292F),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '@${acc.username}',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF58A6FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        acc.email,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: secondaryText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Indikator Terhubung
                if (isSelected)
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF8250DF), size: 22)
                else
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: secondaryText.withValues(alpha: 0.5), size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(GithubAccountUser acc) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFF24292F),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          acc.username.isNotEmpty ? acc.username[0].toUpperCase() : 'G',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
    );
  }
}
