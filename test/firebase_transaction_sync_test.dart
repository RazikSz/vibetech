import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vibetech_xyz/services/firebase_transaction_service.dart';

void main() {
  group('Firebase Transaction & Top Up Realtime Sync Tests', () {
    test('Top Up transaction is automatically saved and synced to Firebase RTDB', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final invoiceNo = 'INV-TOPUP-TEST-$ts';
      const userEmail = 'user@vibetech.com';

      final topupData = {
        'user_email': userEmail,
        'nama_produk': 'Top Up Saldo VibeWallet (QRIS)',
        'jumlah': 1,
        'total_harga': 100000.0,
        'tanggal': '2026-08-26 14:30',
        'status': 'Selesai',
        'payment_method': 'QRIS Instan',
        'invoice_no': invoiceNo,
        'notes': 'Top Up Saldo VibeWallet sebesar Rp 100.000 via QRIS Instan',
      };

      // 1. Simpan via FirebaseTransactionService
      final docId = await FirebaseTransactionService.instance.saveTransactionToFirebase(topupData);
      expect(docId, isNotNull);

      // 2. Verifikasi langsung di endpoint Firebase RTDB
      final cleanKey = invoiceNo.replaceAll(RegExp(r'[/\\#?\[\]\.\$]'), '_');
      final txUri = await FirebaseTransactionService.buildTxRtdbUri('$cleanKey.json');
      final res = await http.get(txUri);

      expect(res.statusCode, 200);
      expect(res.body, isNot('null'));

      final dynamic data = jsonDecode(res.body);
      expect(data['invoice_no'], invoiceNo);
      expect(data['user_email'], userEmail);
      expect(data['nama_produk'], contains('Top Up Saldo'));
      expect(data['total_harga'], 100000.0);
      expect(data['status'], 'Selesai');

      // 3. Bersihkan data pengujian
      await http.delete(txUri);
    });

    test('Product purchase transaction updates from Pending to Selesai in Firebase RTDB', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final invoiceNo = 'INV-VPS-TEST-$ts';
      const userEmail = 'user@vibetech.com';

      final pendingData = {
        'user_email': userEmail,
        'nama_produk': 'Cloud VPS Ultra Fast (4 Core / 8 GB)',
        'jumlah': 1,
        'total_harga': 150000.0,
        'tanggal': '2026-08-26 14:35',
        'status': 'Pending',
        'payment_method': 'VibeWallet',
        'invoice_no': invoiceNo,
        'notes': 'Pembelian VPS',
      };

      await FirebaseTransactionService.instance.saveTransactionToFirebase(pendingData);

      final cleanKey = invoiceNo.replaceAll(RegExp(r'[/\\#?\[\]\.\$]'), '_');
      final txUri = await FirebaseTransactionService.buildTxRtdbUri('$cleanKey.json');

      // Update status ke Selesai
      await FirebaseTransactionService.instance.updateTransactionInFirebase(
        invoiceNo: invoiceNo,
        updatedData: {'status': 'Selesai'},
      );

      final res = await http.get(txUri);
      expect(res.statusCode, 200);
      expect(res.body, isNot('null'));

      final dynamic updatedData = jsonDecode(res.body);
      expect(updatedData['status'], 'Selesai');

      // Bersihkan data pengujian
      await http.delete(txUri);
    });
  });
}
