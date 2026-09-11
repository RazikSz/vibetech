import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibetech_xyz/constants/constants.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/language_service.dart';
import 'package:vibetech_xyz/services/notification_service.dart';

/// ============================================================================
/// HALAMAN PUSAT NOTIFIKASI & KOTAK MASUK EMAIL (NOTIFICATION CENTER PAGE)
/// ============================================================================
/// Mengelola seluruh pemberitahuan in-app & email masuk berbasis Database SQLite:
/// 1. Tab Notifikasi: Semua, Belum Dibaca, Peringatan & Tagihan.
/// 2. Tab Kotak Masuk Email (Inbox): Menampilkan riwayat email resmi VibeTech.
/// 3. Tersimpan permanen di SQLite Database sehingga riwayat tidak hilang saat logout/restart.
class NotifikasiPage extends StatefulWidget {
  final bool isDarkMode;

  const NotifikasiPage({
    super.key,
    this.isDarkMode = true,
  });

  @override
  State<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends State<NotifikasiPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _activeEmail = 'user@vibetech.com';

  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _emailInbox = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initAndLoadFromDB();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initAndLoadFromDB() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _activeEmail = prefs.getString('email') ?? 'user@vibetech.com';

      await _loadDataFromDB();
    } catch (e) {
      debugPrint('Error initializing NotifikasiPage: $e');
    }
  }

  Future<void> _loadDataFromDB() async {
    try {
      final dbList = await DatabaseHelper.instance.getNotificationsByUser(_activeEmail);

      final List<Map<String, dynamic>> loadedNotifs = [];
      final List<Map<String, dynamic>> loadedEmails = [];

      for (var row in dbList) {
        final id = row['id'];
        final title = row['title']?.toString() ?? 'Pemberitahuan';
        final message = row['message']?.toString() ?? '';
        final category = row['category']?.toString() ?? 'Sistem';
        final orderId = row['order_id']?.toString();
        final amount = row['amount']?.toString();
        final dateTime = row['date_time']?.toString() ?? 'Baru saja';
        final isRead = (row['is_read'] as num?)?.toInt() == 1;
        final type = row['type']?.toString().toLowerCase() ?? 'info';
        final sender = row['sender']?.toString() ?? 'no-reply@vibetech.xyz';
        final senderName = row['sender_name']?.toString() ?? 'VibeTech Mailer';

        Color color = AppColors.primary;
        IconData icon = Icons.notifications_rounded;

        if (type == 'expiry' || category.toLowerCase().contains('peringatan')) {
          color = AppColors.warning;
          icon = Icons.timer_rounded;
        } else if (type == 'payment' ||
            category.toLowerCase().contains('pembayaran') ||
            category.toLowerCase().contains('invoice') ||
            category.toLowerCase().contains('top up')) {
          color = AppColors.success;
          icon = Icons.check_circle_rounded;
        } else if (type == 'promo' || category.toLowerCase().contains('promo')) {
          color = AppColors.accent;
          icon = Icons.local_offer_rounded;
        } else if (type == 'security' ||
            category.toLowerCase().contains('keamanan')) {
          color = const Color(0xFF00E5FF);
          icon = Icons.shield_rounded;
        } else if (type == 'email') {
          color = AppColors.primary;
          icon = Icons.mark_email_read_rounded;
        }

        final itemMap = {
          'dbId': id,
          'id': 'NOTIF-$id',
          'type': type,
          'title': title,
          'message': message,
          'time': dateTime,
          'service': category,
          'category': category,
          'icon': icon,
          'color': color,
          'isRead': isRead,
          'orderId': orderId,
          'amount': amount,
          'sender': sender,
          'senderName': senderName,
          'body': message,
          'date': dateTime,
        };

        loadedNotifs.add(itemMap);

        if (type == 'email' || type == 'promo' || category.contains('Invoice') || category.contains('Top Up')) {
          loadedEmails.add(itemMap);
        }
      }

      if (mounted) {
        setState(() {
          _notifications = loadedNotifs;
          _emailInbox = loadedEmails;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications from DB: $e');
    }
  }

  int get _unreadNotifCount =>
      _notifications.where((n) => n['isRead'] == false).length;

  int get _unreadEmailCount =>
      _emailInbox.where((e) => e['isRead'] == false).length;

  Future<void> _markAsRead(Map<String, dynamic> notif) async {
    final dbId = notif['dbId'];
    setState(() => notif['isRead'] = true);

    if (dbId != null && dbId is int) {
      try {
        await DatabaseHelper.instance.markNotificationAsRead(dbId);
      } catch (e) {
        debugPrint('Error marking notif as read in DB: $e');
      }
    }
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      for (var n in _notifications) {
        n['isRead'] = true;
      }
      for (var e in _emailInbox) {
        e['isRead'] = true;
      }
    });

    try {
      await DatabaseHelper.instance.markAllNotificationsAsRead(_activeEmail);
    } catch (e) {
      debugPrint('Error marking all as read in DB: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LanguageService.text(
                'Semua notifikasi & email telah ditandai dibaca di Database',
                'All notifications & emails marked as read in Database'),
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBgColor = isDark ? AppColors.darkCard : Colors.white;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text(
          LanguageService.text(
              'Pusat Notifikasi & Email', 'Notifications & Mail Center'),
          style: GoogleFonts.poppins(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Tandai semua dibaca',
            icon: const Icon(Icons.done_all_rounded, color: AppColors.primary),
            onPressed: _markAllAsRead,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: textSecondary,
          labelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12),
          isScrollable: true,
          tabs: [
            Tab(
              child: Row(
                children: [
                  const Text('Semua'),
                  if (_unreadNotifCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildBadge('$_unreadNotifCount', AppColors.primary),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Text('Belum Dibaca'),
                  if (_unreadNotifCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildBadge('$_unreadNotifCount', AppColors.warning),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Peringatan & Tagihan'),
            Tab(
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, size: 16),
                  const SizedBox(width: 6),
                  const Text('Kotak Masuk Email'),
                  if (_unreadEmailCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildBadge('$_unreadEmailCount', AppColors.accent),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Semua
                _buildNotificationList(
                    _notifications, cardBgColor, textPrimary, textSecondary),
                // Tab 2: Belum Dibaca
                _buildNotificationList(
                    _notifications
                        .where((n) => n['isRead'] == false)
                        .toList(),
                    cardBgColor,
                    textPrimary,
                    textSecondary),
                // Tab 3: Peringatan & Tagihan
                _buildNotificationList(
                    _notifications
                        .where((n) =>
                            n['type'] == 'expiry' ||
                            n['type'] == 'payment' ||
                            (n['service'] ?? '').toString().contains('Tagihan') ||
                            (n['service'] ?? '').toString().contains('Invoice'))
                        .toList(),
                    cardBgColor,
                    textPrimary,
                    textSecondary),
                // Tab 4: Kotak Masuk Email
                _buildEmailInboxList(
                    _emailInbox, cardBgColor, textPrimary, textSecondary),
              ],
            ),
    );
  }

  Widget _buildBadge(String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // --- NOTIFICATION LIST BUILDER ---
  Widget _buildNotificationList(
    List<Map<String, dynamic>> notifications,
    Color cardBgColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_rounded,
                size: 70, color: textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text(
              LanguageService.text('Tidak ada notifikasi di kategori ini',
                  'No notifications in this category'),
              style: GoogleFonts.poppins(color: textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDataFromDB,
      color: AppColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notif = notifications[index];
          final isRead = notif['isRead'] as bool;
          final color = notif['color'] as Color;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: !isRead
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: widget.isDarkMode ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                _markAsRead(notif);
                _showNotificationDetail(notif);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(notif['icon'] as IconData,
                          color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  notif['service'] as String,
                                  style: GoogleFonts.poppins(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                notif['time'] as String,
                                style: GoogleFonts.poppins(
                                  color: textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notif['title'] as String,
                            style: GoogleFonts.poppins(
                              color: textPrimary,
                              fontWeight:
                                  isRead ? FontWeight.w600 : FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notif['message'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isRead) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- EMAIL INBOX LIST BUILDER ---
  Widget _buildEmailInboxList(
    List<Map<String, dynamic>> emails,
    Color cardBgColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (emails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_email_unread_outlined,
                size: 70, color: textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text(
              LanguageService.text(
                  'Belum ada email yang masuk', 'No incoming emails yet'),
              style: GoogleFonts.poppins(color: textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDataFromDB,
      color: AppColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        itemCount: emails.length,
        itemBuilder: (context, index) {
          final email = emails[index];
          final isRead = email['isRead'] as bool;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: !isRead
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: widget.isDarkMode ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                _markAsRead(email);
                NotificationService.showEmailNotificationModal(
                  context,
                  toEmail: _activeEmail,
                  subject: email['title'] ?? email['subject'] ?? '',
                  message: email['message'] ?? email['body'] ?? '',
                  category: email['category'] ?? 'Sistem',
                  orderId: email['orderId'],
                  amount: email['amount'],
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.email_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                email['senderName'] ?? 'VibeTech Mailer',
                                style: GoogleFonts.poppins(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                email['time'] ?? email['date'] ?? '',
                                style: GoogleFonts.poppins(
                                  color: textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email['title'] ?? email['subject'] ?? '',
                            style: GoogleFonts.poppins(
                              color: textPrimary,
                              fontWeight:
                                  isRead ? FontWeight.w600 : FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email['message'] ?? email['body'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isRead) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- DETAIL MODAL NOTIFIKASI ---
  void _showNotificationDetail(Map<String, dynamic> notif) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = widget.isDarkMode;
        final cardBgColor = isDark ? AppColors.darkCard : Colors.white;
        final textPrimary =
            isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        final textSecondary =
            isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          (notif['color'] as Color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(notif['icon'] as IconData,
                        color: notif['color'] as Color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notif['service'] as String,
                          style: GoogleFonts.poppins(
                            color: notif['color'] as Color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          notif['time'] as String,
                          style: GoogleFonts.poppins(
                            color: textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                notif['title'] as String,
                style: GoogleFonts.poppins(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                notif['message'] as String,
                style: GoogleFonts.poppins(
                  color: textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Tutup',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
