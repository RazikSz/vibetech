import 'package:flutter_test/flutter_test.dart';
import 'package:vibetech_xyz/models/transaction_model.dart';

void main() {
  group('TransactionModel Firebase Serialization Tests', () {
    test('TransactionModel converts to and from Firestore map properly', () {
      final transaction = TransactionModel(
        id: 101,
        invoiceNo: 'INV-VT-998877',
        userEmail: 'user@vibetech.xyz',
        namaProduk: 'Cloud VPS KVM 4GB',
        jumlah: 2,
        totalHarga: 150000.0,
        tanggal: '2026-08-26 12:00',
        status: 'Selesai',
        paymentMethod: 'VibeWallet',
        notes: 'VPS KVM 4GB x2',
      );

      final firestoreData = transaction.toFirestore();
      expect(firestoreData['invoice_no'], 'INV-VT-998877');
      expect(firestoreData['user_email'], 'user@vibetech.xyz');
      expect(firestoreData['total_harga'], 150000.0);
      expect(firestoreData['status'], 'Selesai');

      final reconstructed =
          TransactionModel.fromFirestore(firestoreData, 'INV-VT-998877');
      expect(reconstructed.invoiceNo, 'INV-VT-998877');
      expect(reconstructed.userEmail, 'user@vibetech.xyz');
      expect(reconstructed.namaProduk, 'Cloud VPS KVM 4GB');
      expect(reconstructed.totalHarga, 150000.0);
      expect(reconstructed.isPaid, true);
    });
  });
}
