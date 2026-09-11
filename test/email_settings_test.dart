import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vibetech_xyz/database/db_helper.dart';

void main() {
  setUpAll(() {
    // Initialize FFI for running sqflite in tests on desktop/VM
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper Comprehensive Persistence Tests', () {
    test('saveEmailSettings and getEmailSettings persist data properly', () async {
      final result = await DatabaseHelper.instance.saveEmailSettings(
        smtpUser: 'custom.user@gmail.com',
        smtpPass: 'abcd efgh ijkl mnop',
        smtpHost: 'smtp.gmail.com',
        smtpPort: 465,
        userEmail: 'admin@vibetech.com',
        syncToCloud: false,
      );

      expect(result, greaterThan(0));

      final settings = await DatabaseHelper.instance.getEmailSettings(
        userEmail: 'admin@vibetech.com',
      );

      expect(settings, isNotNull);
      expect(settings!['smtp_user'], 'custom.user@gmail.com');
      expect(settings['smtp_pass'], 'abcdefghijklmnop'); // spasi dibersihkan
      expect(settings['smtp_host'], 'smtp.gmail.com');
      expect(settings['smtp_port'], 465);
      expect(settings['updated_at'], isNotNull);
    });

    test('getEmailSettings fallbacks to latest global setting if user is null', () async {
      await DatabaseHelper.instance.saveEmailSettings(
        smtpUser: 'vibetech.official.xyz@gmail.com',
        smtpPass: 'fuhs qpvu fskx jmsw',
        smtpHost: 'smtp.gmail.com',
        smtpPort: 465,
        syncToCloud: false,
      );

      final settings = await DatabaseHelper.instance.getEmailSettings();
      expect(settings, isNotNull);
      expect(settings!['smtp_user'], 'vibetech.official.xyz@gmail.com');
      expect(settings['smtp_port'], 465);
    });

    test('Transaction operations persist all fields properly in SQLite', () async {
      final txId = await DatabaseHelper.instance.createTransaction({
        'user_email': 'testuser@vibetech.com',
        'nama_produk': 'VPS Pro Singapore',
        'jumlah': 2,
        'total_harga': 190000.0,
        'tanggal': '2026-08-26 09:00',
        'status': 'Selesai',
        'payment_method': 'QRIS',
        'invoice_no': 'INV-TEST-2026',
        'notes': 'VPS Pro x2',
      });

      expect(txId, greaterThan(0));

      final txList = await DatabaseHelper.instance.getTransactionsByUser('testuser@vibetech.com');
      expect(txList.any((tx) => tx['invoice_no'] == 'INV-TEST-2026'), isTrue);

      final created = txList.firstWhere((tx) => tx['invoice_no'] == 'INV-TEST-2026');
      expect(created['total_harga'], 190000.0);
      expect(created['payment_method'], 'QRIS');
      expect(created['status'], 'Selesai');
    });

    test('Login History operations persist records in SQLite', () async {
      await DatabaseHelper.instance.insertLoginHistory({
        'user_email': 'login_test@vibetech.com',
        'waktu': DateTime.now().toIso8601String(),
        'provider': 'Google',
        'status': 'Berhasil',
      });

      final history = await DatabaseHelper.instance.getLoginHistory(userEmail: 'login_test@vibetech.com');
      expect(history.isNotEmpty, isTrue);
      expect(history.first['provider'], 'Google');
      expect(history.first['status'], 'Berhasil');
    });

    test('Inbox Notifications and Support Tickets persist in SQLite', () async {
      // 1. Notifikasi
      final notifId = await DatabaseHelper.instance.insertNotification({
        'user_email': 'notif_test@vibetech.com',
        'title': 'Tagihan Terbayar',
        'message': 'Pembayaran invoice #INV-9999 sukses.',
        'category': 'Invoice & Pembelian',
        'order_id': '#INV-9999',
        'amount': 'Rp 50.000',
        'date_time': 'Hari ini, 09:15 WIB',
        'is_read': 0,
        'type': 'payment',
        'sender': 'billing@vibetech.xyz',
        'sender_name': 'VibeTech Billing',
      });

      expect(notifId, greaterThan(0));

      final notifs = await DatabaseHelper.instance.getNotificationsByUser('notif_test@vibetech.com');
      expect(notifs.isNotEmpty, isTrue);
      expect(notifs.first['order_id'], '#INV-9999');

      await DatabaseHelper.instance.markNotificationAsRead(notifId);
      final updatedNotifs = await DatabaseHelper.instance.getNotificationsByUser('notif_test@vibetech.com');
      expect(updatedNotifs.first['is_read'], 1);

      // 2. Tiket Support
      final ticketId = await DatabaseHelper.instance.createSupportTicket({
        'ticket_no': '#TKT-778899',
        'user_name': 'Test User',
        'user_email': 'notif_test@vibetech.com',
        'subject': 'Tanya Konfigurasi DNS VPS',
        'message': 'Bagaimana cara setting custom nameserver?',
        'status': 'Open',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(ticketId, greaterThan(0));

      final tickets = await DatabaseHelper.instance.getSupportTickets(userEmail: 'notif_test@vibetech.com');
      expect(tickets.isNotEmpty, isTrue);
      expect(tickets.first['ticket_no'], '#TKT-778899');
      expect(tickets.first['subject'], 'Tanya Konfigurasi DNS VPS');
    });

    test('getTotalOrdersCount starts from 0 and increments with product purchases', () async {
      final freshUserEmail = 'fresh_user_${DateTime.now().microsecondsSinceEpoch}@vibetech.com';

      // 1. Awalnya harus 0
      final initialCount = await DatabaseHelper.instance.getTotalOrdersCount(
        freshUserEmail,
        isAdmin: false,
        onlyProductPurchases: true,
      );
      expect(initialCount, 0);

      // 2. Transaksi Top Up tidak dihitung sebagai pesanan produk jika onlyProductPurchases: true
      await DatabaseHelper.instance.createTransaction({
        'user_email': freshUserEmail,
        'nama_produk': 'Top Up Saldo VibeWallet (QRIS)',
        'jumlah': 1,
        'total_harga': 50000.0,
        'tanggal': '2026-08-26 09:30',
        'status': 'Selesai',
        'payment_method': 'QRIS',
        'invoice_no': 'INV-TOPUP-001',
      });

      final afterTopUpCount = await DatabaseHelper.instance.getTotalOrdersCount(
        freshUserEmail,
        isAdmin: false,
        onlyProductPurchases: true,
      );
      expect(afterTopUpCount, 0);

      // 3. Pembelian produk VPS / Panel Hosting / Bot WA
      await DatabaseHelper.instance.createTransaction({
        'user_email': freshUserEmail,
        'nama_produk': 'VPS Starter',
        'jumlah': 1,
        'total_harga': 50000.0,
        'tanggal': '2026-08-26 09:35',
        'status': 'Selesai',
        'payment_method': 'VibeWallet',
        'invoice_no': 'INV-VPS-001',
      });

      final afterProductCount = await DatabaseHelper.instance.getTotalOrdersCount(
        freshUserEmail,
        isAdmin: false,
        onlyProductPurchases: true,
      );
      expect(afterProductCount, 1);
    });

    test('User balance persists in SQLite and is deducted upon product purchase', () async {
      final balanceUserEmail = 'balance_test_${DateTime.now().microsecondsSinceEpoch}@vibetech.com';

      // 1. Inisialisasi saldo user awal di SQLite
      await DatabaseHelper.instance.updateUserBalance(balanceUserEmail, 100000.0);
      final balance1 = await DatabaseHelper.instance.getUserBalance(balanceUserEmail);
      expect(balance1, 100000.0);

      // 2. Tambah saldo (Top Up)
      final balanceAfterTopUp = await DatabaseHelper.instance.addSaldo(balanceUserEmail, 50000.0);
      expect(balanceAfterTopUp, 150000.0);

      final verifyDbAfterTopUp = await DatabaseHelper.instance.getUserBalance(balanceUserEmail);
      expect(verifyDbAfterTopUp, 150000.0);

      // 3. Potong saldo untuk pembelian produk (misal beli VPS seharga Rp 50.000)
      final deductSuccess = await DatabaseHelper.instance.deductSaldo(balanceUserEmail, 50000.0);
      expect(deductSuccess, isTrue);

      final balanceAfterPurchase = await DatabaseHelper.instance.getUserBalance(balanceUserEmail);
      expect(balanceAfterPurchase, 100000.0);

      // 4. Coba potong saldo melebihi sisa (harus gagal / return false)
      final overDeduct = await DatabaseHelper.instance.deductSaldo(balanceUserEmail, 200000.0);
      expect(overDeduct, isFalse);
      final balanceUnchanged = await DatabaseHelper.instance.getUserBalance(balanceUserEmail);
      expect(balanceUnchanged, 100000.0);
    });

    test('Pending and completed transactions merge seamlessly into a single order record', () async {
      final orderUserEmail = 'merge_order_${DateTime.now().microsecondsSinceEpoch}@vibetech.com';
      final invoiceNo = 'INV-MERGE-${DateTime.now().microsecondsSinceEpoch}';

      // 1. Pesanan dibuat awal dengan status Pending
      final id1 = await DatabaseHelper.instance.createTransaction({
        'user_email': orderUserEmail,
        'nama_produk': 'Panel Hosting 2GB',
        'jumlah': 1,
        'total_harga': 45000.0,
        'tanggal': '2026-08-26 10:00',
        'status': 'Pending',
        'payment_method': 'QRIS',
        'invoice_no': invoiceNo,
        'notes': 'Panel Hosting x1',
      });

      expect(id1, greaterThan(0));

      final initialList = await DatabaseHelper.instance.getTransactionsByUser(orderUserEmail);
      expect(initialList.length, 1);
      expect(initialList.first['status'], 'Pending');

      // 2. Saat pembayaran selesai, diupdate / recreate dengan invoice yang sama
      final id2 = await DatabaseHelper.instance.createTransaction({
        'user_email': orderUserEmail,
        'nama_produk': 'Panel Hosting 2GB',
        'jumlah': 1,
        'total_harga': 45000.0,
        'tanggal': '2026-08-26 10:05',
        'status': 'Selesai',
        'payment_method': 'QRIS',
        'invoice_no': invoiceNo,
        'notes': 'Panel Hosting x1',
      });

      expect(id2, id1); // Harus mengupdate ID yang sama, bukan membuat duplikat terpisah

      // 3. Pastikan di database tetap hanya ada 1 transaksi gabungan yang statusnya sekarang Selesai
      final finalList = await DatabaseHelper.instance.getTransactionsByUser(orderUserEmail);
      expect(finalList.length, 1);
      expect(finalList.first['status'], 'Selesai');
      expect(finalList.first['invoice_no'], invoiceNo);
    });

    test('cleanupDuplicateTransactions removes existing duplicate pending when selesai exists (e.g. INV-7711334)', () async {
      final dupUserEmail = 'dup_user_${DateTime.now().microsecondsSinceEpoch}@vibetech.com';
      const duplicateInvoice = 'INV-7711334';

      final db = await DatabaseHelper.instance.database;

      // 1. Masukkan manual 2 baris terpisah (seperti kasus lama): 1 Pending dan 1 Selesai
      await db.insert('transactions', {
        'user_email': dupUserEmail,
        'nama_produk': 'VPS 5GB',
        'jumlah': 1,
        'total_harga': 45000.0,
        'tanggal': '2026-08-26 09:29',
        'status': 'Pending',
        'payment_method': 'Saldo VibeWallet',
        'invoice_no': duplicateInvoice,
      });

      await db.insert('transactions', {
        'user_email': dupUserEmail,
        'nama_produk': 'VPS 5GB',
        'jumlah': 1,
        'total_harga': 45000.0,
        'tanggal': '2026-08-26 09:29',
        'status': 'Selesai',
        'payment_method': 'Saldo VibeWallet',
        'invoice_no': duplicateInvoice,
      });

      // 2. Query transaksi - harus otomatis membersihkan duplikasi dan menyisakan HANYA yang Selesai
      final orders = await DatabaseHelper.instance.getTransactionsByUser(dupUserEmail);
      expect(orders.length, 1);
      expect(orders.first['invoice_no'], duplicateInvoice);
      expect(orders.first['status'], 'Selesai');
    });

    test('Product discounts persist in SQLite and can be updated individually or in bulk', () async {
      // 1. Tambah produk baru dengan diskon awal 15%
      final productId = await DatabaseHelper.instance.createProduct({
        'nama': 'VPS Test Discount',
        'kategori': 'VPS_TEST',
        'harga': 100000.0,
        'stok': 10,
        'deskripsi': 'Test description',
        'diskon': 15.0,
      });

      expect(productId, isPositive);

      // 2. Verifikasi diskon tersimpan di database
      final products = await DatabaseHelper.instance.getAllProducts();
      final createdProduct = products.firstWhere((p) => p['id'] == productId);
      expect((createdProduct['diskon'] as num).toDouble(), 15.0);

      // 3. Ubah diskon produk secara individual menjadi 30%
      await DatabaseHelper.instance.updateProductDiscount(productId, 30.0);
      final updatedProducts = await DatabaseHelper.instance.getAllProducts();
      final updatedProduct = updatedProducts.firstWhere((p) => p['id'] == productId);
      expect((updatedProduct['diskon'] as num).toDouble(), 30.0);

      // 4. Terapkan diskon massal 50% untuk kategori 'VPS_TEST'
      await DatabaseHelper.instance.applyCategoryDiscount('VPS_TEST', 50.0);
      final bulkProducts = await DatabaseHelper.instance.getAllProducts();
      final bulkVPS = bulkProducts.where((p) => (p['kategori'] as String).contains('VPS_TEST')).toList();
      for (final p in bulkVPS) {
        expect((p['diskon'] as num).toDouble(), 50.0);
      }

      // 5. Reset diskon kembali ke normal (0%)
      await DatabaseHelper.instance.updateProductDiscount(productId, 0.0);
      final resetProducts = await DatabaseHelper.instance.getAllProducts();
      final resetProduct = resetProducts.firstWhere((p) => p['id'] == productId);
      expect((resetProduct['diskon'] as num).toDouble(), 0.0);
    });
  });
}
