import 'package:flutter/foundation.dart';

/// ============================================================================
/// LAYANAN MANAJEMEN KERANJANG BELANJA (CART SERVICE) - VIBETECH XYZ
/// ============================================================================
/// Layanan global berbasis [ValueNotifier] yang mengelola keranjang belanja:
/// 1. Menyimpan daftar item yang ditambahkan dari katalog produk.
/// 2. Menghitung total harga belanja secara reaktif (auto-update di seluruh UI).
/// 3. Menggabungkan item sejenis (deduplication) dan mengupdate kuantitas.
/// 4. Menghapus item atau mengosongkan keranjang saat transaksi berhasil.
class CartService {
  /// Notifier daftar item keranjang belanja aktif
  static final ValueNotifier<List<Map<String, dynamic>>> notifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  /// Mengambil daftar item keranjang saat ini
  static List<Map<String, dynamic>> get items => notifier.value;

  /// Menghitung akumulasi total harga belanja (Rupiah)
  static int get totalPrice {
    int total = 0;
    for (var item in notifier.value) {
      final price = (item['price'] as num?)?.toInt() ?? 0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
      total += price * quantity;
    }
    return total;
  }

  /// Menambahkan item produk ke dalam keranjang
  /// Jika item dengan nama yang sama sudah ada, kuantitas akan diakumulasikan
  static void addItem(Map<String, dynamic> item, {String? name}) {
    final List<Map<String, dynamic>> currentItems =
        List<Map<String, dynamic>>.from(notifier.value);

    final String itemName = (name ??
            item['name'] ??
            item['nama'] ??
            item['title'] ??
            item['productName'] ??
            item['nama_produk'] ??
            'Layanan VibeTech')
        .toString();

    final int itemPrice = (item['price'] as num?)?.toInt() ??
        (item['harga'] as num?)?.toInt() ??
        0;
    final int itemQty = (item['quantity'] as num?)?.toInt() ?? 1;

    final existingIndex = currentItems.indexWhere(
        (e) => (e['name'] ?? e['title'] ?? e['nama'])?.toString() == itemName);

    if (existingIndex != -1) {
      final existingItem =
          Map<String, dynamic>.from(currentItems[existingIndex]);
      final currentQty = (existingItem['quantity'] as num?)?.toInt() ?? 1;

      existingItem['quantity'] = currentQty + itemQty;
      existingItem['name'] = itemName;
      existingItem['title'] = itemName;
      existingItem['nama'] = itemName;
      currentItems[existingIndex] = existingItem;
    } else {
      currentItems.add({
        'id': item['id'] ?? DateTime.now().millisecondsSinceEpoch,
        'name': itemName,
        'title': itemName,
        'nama': itemName,
        'specs': item['specs'] ?? item['deskripsi'] ?? 'Standard Package',
        'price': itemPrice,
        'quantity': itemQty,
        'duration': item['duration'] ?? 1,
        'type': item['type'] ?? 'VPS',
      });
    }

    // Memicu update reaktif ke seluruh widget listener
    notifier.value = currentItems;
  }

  /// Mengubah kuantitas item pada indeks tertentu
  static void updateQuantity(int index, int newQuantity) {
    if (index >= 0 && index < notifier.value.length) {
      if (newQuantity <= 0) {
        removeItem(index);
      } else {
        final currentItems = List<Map<String, dynamic>>.from(notifier.value);
        final updatedItem = Map<String, dynamic>.from(currentItems[index]);
        updatedItem['quantity'] = newQuantity;
        currentItems[index] = updatedItem;

        notifier.value = currentItems;
      }
    }
  }

  /// Menghapus satu item dari keranjang berdasarkan indeks
  static void removeItem(int index) {
    if (index >= 0 && index < notifier.value.length) {
      final currentItems = List<Map<String, dynamic>>.from(notifier.value);
      currentItems.removeAt(index);
      notifier.value = currentItems;
    }
  }

  /// Mengosongkan seluruh isi keranjang belanja
  static void clear() {
    notifier.value = [];
  }
}
