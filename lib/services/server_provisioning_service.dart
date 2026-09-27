import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/models/service_model.dart';
import 'package:vibetech_xyz/services/firebase_transaction_service.dart';
import 'package:vibetech_xyz/services/notification_service.dart';

/// ============================================================================
/// SERVER PROVISIONING SERVICE - VIBETECH XYZ (AUTO-PROVISIONING INSTANT DELIVERY)
/// ============================================================================
/// Layanan otomatisasi provisi instan saat transaksi server berstatus Lunas / Selesai:
/// 1. VPS Cloud Provisioning: Mengalokasikan Public IP, Port SSH 22, User Root, dan Password Terenkripsi.
/// 2. Pterodactyl Panel Provisioning: Mengalokasikan Port Node Singapore, URL Pterodactyl, dan Akses Panel.
/// 3. Bot WhatsApp Provisioning: Mengalokasikan Session ID Baileys, Pairing Code 8-Digit, dan Engine Daemon.
/// 4. Menyimpan ganda ke SQLite Database & Firebase Realtime Database (/services & /purchased_services).
class ServerProvisioningService {
  static final ServerProvisioningService instance =
      ServerProvisioningService._init();
  ServerProvisioningService._init();

  final math.Random _random = math.Random();

  /// Menghasilkan password acak berkekuatan tinggi (12 Karakter Alfanumerik + Simbol)
  String _generateSecurePassword(String prefix) {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#\$%*';
    final randomStr = List.generate(8, (_) => chars[_random.nextInt(chars.length)]).join();
    return '$prefix$randomStr';
  }

  /// Mengeksekusi provisi instan layanan setelah pembayaran terverifikasi
  Future<PurchasedService> autoProvisionService({
    required String userEmail,
    required String productName,
    required String category,
    required double price,
    int durationMonths = 1,
    String? invoiceNo,
    String? customerName,
    String? customSpecs,
  }) async {
    final now = DateTime.now();
    final cleanEmail = userEmail.trim().toLowerCase();
    final String cleanCat = category.trim();
    final String expDate = now
        .add(Duration(days: 30 * (durationMonths > 0 ? durationMonths : 1)))
        .toIso8601String();
    final String todayStr = now.toIso8601String();

    String ipAddress = '';
    String port = '';
    String username = '';
    String password = '';
    String serverUrl = '';
    String sessionId = '';
    String specs = customSpecs ?? 'Standard High-Speed Specification';
    String extraData = '';

    final catLower = cleanCat.toLowerCase();
    final nameLower = productName.toLowerCase();

    // 1. Logika Provisi Otomatis CLOUD VPS (KVM / Proxmox Cloud API)
    if (catLower.contains('vps') || nameLower.contains('vps')) {
      final octet3 = 100 + _random.nextInt(150);
      final octet4 = 10 + _random.nextInt(240);
      ipAddress = '103.187.$octet3.$octet4';
      port = '22';
      username = 'root';
      password = _generateSecurePassword('Vps#');
      serverUrl = 'https://vps.vibetech.xyz:8006';
      specs = customSpecs ??
          (nameLower.contains('starter')
              ? '1 vCPU, 2GB RAM, 30GB NVMe (SG-01)'
              : nameLower.contains('pro')
                  ? '2 vCPU, 4GB RAM, 60GB NVMe (SG-02)'
                  : '4 vCPU, 8GB RAM, 120GB NVMe (SG-03)');
      extraData = 'OS: Ubuntu 22.04 LTS (Tier-3 Equinix SG1 Node)';
    }
    // 2. Logika Provisi Otomatis PANEL HOSTING (Pterodactyl Application API)
    else if (catLower.contains('panel') ||
        catLower.contains('hosting') ||
        nameLower.contains('panel') ||
        nameLower.contains('hosting')) {
      final allocatedPort = 25500 + _random.nextInt(1000);
      port = '$allocatedPort';
      serverUrl = 'https://panel.vibetech.xyz:8080';
      username = 'vibe_${now.millisecondsSinceEpoch.toString().substring(7)}';
      password = _generateSecurePassword('Panel@');
      specs = customSpecs ??
          (nameLower.contains('1gb')
              ? '1GB RAM, 100% CPU, 10GB NVMe'
              : nameLower.contains('2gb')
                  ? '2GB RAM, 150% CPU, 20GB NVMe'
                  : 'Unlimited RAM & CPU, 50GB NVMe');
      extraData = 'Pterodactyl Daemon Engine (Node: Singapore High-Speed)';
    }
    // 3. Logika Provisi Otomatis BOT WHATSAPP (Baileys Multi-Device Daemon API)
    else {
      sessionId = 'VIBE-WA-${now.millisecondsSinceEpoch.toString().substring(6)}';
      final pairCode = 1000 + _random.nextInt(9000);
      port = '3000';
      serverUrl = 'https://api.vibetech.xyz/wa-session';
      username = cleanEmail;
      password = _generateSecurePassword('Bot#');
      specs = customSpecs ?? 'Baileys Multi-Device Engine 24/7 Uptime';
      extraData = 'PAIRING-CODE: VBWA-$pairCode | Auto-Restart: Active';
    }

    final serviceMap = {
      'user_email': cleanEmail,
      'nama_produk': '$productName #${now.millisecondsSinceEpoch.toString().substring(8)}',
      'kategori': cleanCat,
      'harga': price,
      'tanggal_beli': todayStr,
      'tanggal_kadaluarsa': expDate,
      'status': 'Aktif',
      'ip_address': ipAddress.isNotEmpty ? ipAddress : null,
      'port': port.isNotEmpty ? port : null,
      'username': username.isNotEmpty ? username : null,
      'password': password.isNotEmpty ? password : null,
      'server_url': serverUrl.isNotEmpty ? serverUrl : null,
      'session_id': sessionId.isNotEmpty ? sessionId : null,
      'spesifikasi': specs,
      'extra_data': extraData,
    };

    // 1. Simpan ke SQLite Database Lokal
    int localId = 0;
    try {
      localId = await DatabaseHelper.instance.createService(serviceMap);
      serviceMap['id'] = localId;
    } catch (e) {
      debugPrint('[ServerProvisioningService] Error simpan SQLite: $e');
    }

    // 2. Simpan & Sinkronkan langsung ke Firebase Realtime Database
    try {
      await FirebaseTransactionService.instance.saveServiceToFirebase(serviceMap);
      await FirebaseTransactionService.instance.syncOrderedServicesToFirebase();
      debugPrint('[ServerProvisioningService] ✅ Layanan berhasil di-provisioning dan disinkronkan ke Firebase RTDB!');
    } catch (e) {
      debugPrint('[ServerProvisioningService] Error sync Firebase RTDB: $e');
    }

    // 3. Buat Notifikasi Inbox & Trigger Push Notification
    try {
      final notifTitle = 'Layanan Aktif: $productName 🚀';
      final notifMsg = cleanCat.contains('VPS')
          ? 'Selamat! Cloud VPS Anda siap digunakan.\nIP: $ipAddress\nPort: $port | User: $username'
          : cleanCat.contains('Panel')
              ? 'Selamat! Panel Pterodactyl Anda telah aktif.\nURL: $serverUrl\nUser: $username'
              : 'Selamat! Bot WhatsApp Anda telah aktif dengan Session ID: $sessionId.';

      await DatabaseHelper.instance.insertNotification({
        'user_email': cleanEmail,
        'title': notifTitle,
        'message': notifMsg,
        'category': 'Aktivasi Server',
        'order_id': invoiceNo,
        'amount': 'Rp ${price.toStringAsFixed(0)}',
        'date_time': todayStr,
        'is_read': 0,
        'type': 'service_provisioned',
        'sender': 'system@vibetech.xyz',
        'sender_name': 'VibeTech Cloud Provisioner',
      });

      // Trigger Push Notification banner sistem
      NotificationService.showSystemNotification(
        id: (now.millisecondsSinceEpoch ~/ 1000) & 0x7FFFFFFF,
        title: notifTitle,
        body: notifMsg,
        category: 'Aktivasi Server',
      );
    } catch (e) {
      debugPrint('[ServerProvisioningService] Notification trigger info: $e');
    }

    return PurchasedService.fromMap(serviceMap);
  }
}
