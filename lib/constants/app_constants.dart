/// General Application Constants for VibeTech XYZ
class AppConstants {
  // --- App Metadata ---
  static const String appName = 'VibeTech XYZ';
  static const String appTagline = 'Cloud Hosting & Server Infrastructure';
  static const String appVersion = '2.0.0';
  static const String appPackage = 'com.vibetech.xyz';

  // --- Default Credentials & Roles ---
  static const String defaultUserEmail = 'user@vibetech.com';
  static const String defaultAdminEmail = 'admin@vibetech.com';
  static const String defaultUsername = 'demouser';
  static const String defaultAdminUsername = 'admin';
  static const String roleUser = 'user';
  static const String roleAdmin = 'admin';
  static const String roleAdministrator = 'administrator';

  // --- Product & Service Categories ---
  static const String categoryVps = 'VPS';
  static const String categoryPanel = 'Panel Hosting';
  static const String categoryBotWa = 'Bot WhatsApp';
  static const String categoryDomain = 'Domain & DNS';
  static const String categoryStorage = 'Cloud Storage';

  static const List<String> allCategories = [
    'Semua',
    categoryVps,
    categoryPanel,
    categoryBotWa,
  ];

  // --- Payment Methods ---
  static const String paymentSaldo = 'Saldo VibeTech';
  static const String paymentQris = 'QRIS Instant';
  static const String paymentBca = 'BCA Virtual Account';
  static const String paymentMandiri = 'Mandiri Virtual Account';
  static const String paymentBri = 'BRI Virtual Account';
  static const String paymentGopay = 'GoPay E-Wallet';
  static const String paymentDana = 'DANA E-Wallet';

  // --- Transaction Statuses ---
  static const String statusSelesai = 'Selesai';
  static const String statusPending = 'Pending';
  static const String statusDiproses = 'Diproses';
  static const String statusDibatalkan = 'Dibatalkan';

  // --- Developer & Creator ---
  static const String developerName = 'Raziek';
  static const String developerRole = 'Lead Developer & Grand Director';

  // --- Support & Social URLs ---
  static const String officialWebsite = 'https://vibetech.xyz';
  static const String supportEmail = 'support@vibetech.xyz';
  static const String supportPhone = '+62 878-8587-3325';
  static const String whatsappNumber = '0878-8587-3325';
  static const String whatsappSupport = 'https://wa.me/6287885873325';
  static const String telegramChannel = 'https://t.me/vibetech_official';
  static const String githubRepo = 'https://github.com/vibetech-xyz';
}
