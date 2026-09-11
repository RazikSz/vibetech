import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/services/firebase_realtime_listener_service.dart';
import 'package:vibetech_xyz/services/firebase_transaction_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('Firebase Realtime Database Two-Way Sync & Permanent Edit Tests', () {
    test('1. Transaction created from Direct Payment is saved to Firebase RTDB permanently', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final invoiceNo = 'INV-GP-DIRECT-$ts';
      const userEmail = 'directbuyer@vibetech.com';

      final txData = {
        'user_email': userEmail,
        'nama_produk': 'Cloud VPS NVMe 8GB',
        'jumlah': 1,
        'total_harga': 75000.0,
        'tanggal': '2026-09-11 12:00',
        'status': 'Pending',
        'payment_method': 'Midtrans (GoPay)',
        'invoice_no': invoiceNo,
        'notes': 'Direct Payment GoPay',
      };

      // Simpan melalui DatabaseHelper
      final localId = await DatabaseHelper.instance.createTransaction(txData);
      expect(localId, isPositive);

      // Simpan langsung ke Firebase RTDB
      final docId = await FirebaseTransactionService.instance.saveTransactionToFirebase({
        ...txData,
        'id': localId,
      });
      expect(docId, isNotNull);

      // Verifikasi di Firebase Realtime Database
      final cleanKey = invoiceNo.replaceAll(RegExp(r'[/\\#?\[\]\.\$]'), '_');
      final txUri = await FirebaseTransactionService.buildTxRtdbUri('$cleanKey.json');
      final res = await http.get(txUri);
      expect(res.statusCode, 200);
      expect(res.body, isNot('null'));

      final dynamic data = jsonDecode(res.body);
      expect(data['invoice_no'], invoiceNo);
      expect(data['user_email'], userEmail);
      expect(data['total_harga'], 75000.0);
      expect(data['status'], 'Pending');

      // Bersihkan
      await http.delete(txUri);
    });

    test('2. Updating transaction in SQLite automatically updates Firebase RTDB permanently', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final invoiceNo = 'INV-VA-DIRECT-$ts';
      const userEmail = 'vabuyer@vibetech.com';

      final initialData = {
        'user_email': userEmail,
        'nama_produk': 'Bot WhatsApp Premium',
        'jumlah': 1,
        'total_harga': 35000.0,
        'tanggal': '2026-09-11 12:10',
        'status': 'Pending',
        'payment_method': 'Midtrans (BCA Virtual Account)',
        'invoice_no': invoiceNo,
        'notes': 'Menunggu transfer VA',
      };

      final localId = await DatabaseHelper.instance.createTransaction(initialData);

      // Update transaksi menjadi Selesai (seperti saat direct payment sukses)
      final updatedData = {
        ...initialData,
        'status': 'Selesai',
        'notes': 'Pembayaran berhasil dikonfirmasi',
      };

      await DatabaseHelper.instance.updateTransaction(localId, updatedData);

      // Verifikasi bahwa update tersimpan di Firebase RTDB
      final cleanKey = invoiceNo.replaceAll(RegExp(r'[/\\#?\[\]\.\$]'), '_');
      final txUri = await FirebaseTransactionService.buildTxRtdbUri('$cleanKey.json');
      final res = await http.get(txUri);
      expect(res.statusCode, 200);

      final dynamic cloudData = jsonDecode(res.body);
      expect(cloudData['status'], 'Selesai');
      expect(cloudData['notes'], 'Pembayaran berhasil dikonfirmasi');

      // Bersihkan
      await http.delete(txUri);
    });

    test('3. Editing transaction in Firebase RTDB updates SQLite permanently', () async {
      final db = await DatabaseHelper.instance.database;
      const inv = 'INV-RTDB-EDIT-001';

      await db.delete('transactions', where: 'invoice_no = ?', whereArgs: [inv]);
      await db.insert('transactions', {
        'invoice_no': inv,
        'user_email': 'member@vibetech.com',
        'nama_produk': 'Panel Hosting Pterodactyl',
        'jumlah': 1,
        'total_harga': 50000.0,
        'status': 'Pending',
        'tanggal': '2026-09-11 12:15',
      });

      // Simulasi admin mengubah status di Firebase RTDB Console menjadi 'Selesai'
      await FirebaseRealtimeListenerService.instance.processEventForTesting(
        nodeName: 'transactions',
        eventType: 'put',
        path: '/INV_RTDB_EDIT_001/status',
        data: 'Selesai',
      );

      final updatedLocal = await DatabaseHelper.instance.getTransactionByInvoice(inv);
      expect(updatedLocal, isNotNull);
      expect(updatedLocal!['status'], 'Selesai');
    });
  });
}
