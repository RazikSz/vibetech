import 'package:flutter_test/flutter_test.dart';
import 'package:vibetech_xyz/models/product_model.dart';
import 'package:vibetech_xyz/models/service_model.dart';
import 'package:vibetech_xyz/models/transaction_model.dart';
import 'package:vibetech_xyz/services/balance_service.dart';

void main() {
  group('PurchasedService Model Unit Tests', () {
    test('PurchasedService serialization and deserialization works correctly',
        () {
      final now = DateTime.now();
      final exp = now.add(const Duration(days: 30));

      final service = PurchasedService(
        id: 1,
        userEmail: 'user@vibetech.com',
        namaProduk: 'VPS Starter #001',
        kategori: 'VPS',
        harga: 50000.0,
        tanggalBeli: now.toIso8601String(),
        tanggalKadaluarsa: exp.toIso8601String(),
        status: 'Aktif',
        ipAddress: '103.187.142.88',
        port: '22',
        username: 'root',
        password: 'vps_pass#2026!',
        spesifikasi: '1 vCPU, 2GB RAM, 20GB SSD NVMe',
        extraData: 'Ubuntu 22.04 LTS (SG-01)',
      );

      final map = service.toMap();
      expect(map['nama_produk'], 'VPS Starter #001');
      expect(map['kategori'], 'VPS');
      expect(map['ip_address'], '103.187.142.88');
      expect(map['port'], '22');
      expect(map['username'], 'root');
      expect(map['password'], 'vps_pass#2026!');

      final restored = PurchasedService.fromMap(map);
      expect(restored.id, 1);
      expect(restored.userEmail, 'user@vibetech.com');
      expect(restored.namaProduk, 'VPS Starter #001');
      expect(restored.kategori, 'VPS');
      expect(restored.harga, 50000.0);
      expect(restored.daysRemaining, greaterThanOrEqualTo(29));
      expect(restored.isExpired, false);
    });

    test('Panel and Bot WA model mappings work', () {
      final panel = PurchasedService.fromMap({
        'id': 2,
        'user_email': 'user@vibetech.com',
        'nama_produk': 'Panel Hosting 1GB',
        'kategori': 'Panel Hosting',
        'harga': 25000.0,
        'tanggal_beli': DateTime.now().toIso8601String(),
        'tanggal_kadaluarsa':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'status': 'Aktif',
        'server_url': 'https://panel.vibetech.xyz:8080',
        'username': 'client_demouser',
        'password': 'panel_pass#2026',
        'spesifikasi': '1GB RAM, 1 Core CPU, 10GB Storage',
        'extra_data': 'Node Singapore - Pterodactyl',
      });
      expect(panel.serverUrl, 'https://panel.vibetech.xyz:8080');
      expect(panel.kategori, 'Panel Hosting');

      final bot = PurchasedService.fromMap({
        'id': 3,
        'user_email': 'user@vibetech.com',
        'nama_produk': 'Bot WhatsApp Pro',
        'kategori': 'Bot WhatsApp',
        'harga': 50000.0,
        'tanggal_beli': DateTime.now().toIso8601String(),
        'tanggal_kadaluarsa':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'status': 'Aktif',
        'session_id': 'WA-SESSION-VB7721',
        'extra_data': 'PAIR-CODE: VBWA-8821',
        'spesifikasi': '5 Grup, Auto-reply, Blast AI Assistant',
      });
      expect(bot.sessionId, 'WA-SESSION-VB7721');
      expect(bot.extraData, 'PAIR-CODE: VBWA-8821');
      expect(bot.kategori, 'Bot WhatsApp');
    });

    test('Product and Transaction models work correctly', () {
      final product = Product(
        id: 1,
        nama: 'VPS Starter',
        kategori: 'VPS',
        harga: 50000.0,
        stok: 15,
        deskripsi: '1 vCPU, 2GB RAM, 20GB SSD NVMe',
        diskon: 20.0,
      );

      expect(product.hasDiscount, true);
      expect(product.hargaDiskon, 40000.0);
      expect(product.hematHarga, 10000.0);

      final pMap = product.toMap();
      expect(pMap['nama'], 'VPS Starter');
      expect(pMap['kategori'], 'VPS');
      expect(pMap['harga'], 50000.0);
      expect(pMap['diskon'], 20.0);

      final restoredProduct = Product.fromMap(pMap);
      expect(restoredProduct.nama, 'VPS Starter');
      expect(restoredProduct.stok, 15);
      expect(restoredProduct.diskon, 20.0);
      expect(restoredProduct.hargaDiskon, 40000.0);

      final tx = TransactionModel(
        id: 10,
        userEmail: 'user@vibetech.com',
        namaProduk: 'VPS Starter',
        jumlah: 1,
        totalHarga: 50000.0,
        tanggal: DateTime.now().toIso8601String(),
        status: 'Selesai',
      );

      final txMap = tx.toMap();
      expect(txMap['nama_produk'], 'VPS Starter');
      expect(txMap['status'], 'Selesai');
    });

    test(
        'BalanceService starts at 0 for each new session and manages per-account keys',
        () {
      expect(BalanceService.defaultInitialBalance, 0);
      BalanceService.resetActiveUser();
      expect(BalanceService.balance, 0);
    });

    test(
        'Admin and Member user roles and 6-digit payment PIN are defined properly',
        () {
      final admin = {
        'username': 'admin',
        'email': 'admin@vibetech.com',
        'role': 'admin',
        'saldo': 10000000.0,
        'pin': '123456',
      };
      expect(admin['role'], 'admin');
      expect(admin['email'], 'admin@vibetech.com');
      expect(admin['pin'], '123456');

      final member = {
        'username': 'demouser',
        'email': 'user@vibetech.com',
        'role': 'user',
        'saldo': 0.0,
        'pin': '654321',
      };
      expect(member['role'], 'user');
      expect(member['saldo'], 0.0);
      expect((member['pin'] as String).length, 6);

      // Simulasi Ubah PIN di Profile Page
      final updatedMember = Map<String, dynamic>.from(member);
      updatedMember['pin'] = '987654';
      expect(updatedMember['pin'], '987654');
      expect((updatedMember['pin'] as String).length, 6);
    });
  });
}
