import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// Model hasil generasi QRIS Dinamis dari Nexray API
class QrisDynamicResult {
  final bool success;
  final int nominal;
  final String qrisUrl;
  final String qrisString;
  final String merchantName;
  final String merchantCity;
  final String? errorMessage;
  final bool isFallback;

  const QrisDynamicResult({
    required this.success,
    required this.nominal,
    required this.qrisUrl,
    required this.qrisString,
    required this.merchantName,
    required this.merchantCity,
    this.errorMessage,
    this.isFallback = false,
  });

  factory QrisDynamicResult.fromJson(Map<String, dynamic> json, int requestedNominal) {
    final status = json['status'] == true;
    final result = json['result'] as Map<String, dynamic>?;

    if (status && result != null) {
      return QrisDynamicResult(
        success: true,
        nominal: (result['nominal'] as num?)?.toInt() ?? requestedNominal,
        qrisUrl: result['qris_url']?.toString() ?? '',
        qrisString: result['qris_string']?.toString() ?? '',
        merchantName: result['merchant_name']?.toString() ?? 'Raziek Store, Toko Wibu',
        merchantCity: result['merchant_city']?.toString() ?? 'JAKARTA BARAT',
        isFallback: false,
      );
    } else {
      return QrisDynamicResult(
        success: false,
        nominal: requestedNominal,
        qrisUrl: '',
        qrisString: '',
        merchantName: 'Raziek Store, Toko Wibu',
        merchantCity: 'JAKARTA BARAT',
        errorMessage: json['error']?.toString() ?? 'Gagal membuat QRIS dinamis',
        isFallback: false,
      );
    }
  }

  factory QrisDynamicResult.fallback({
    required int nominal,
    required String qrisString,
    String? reason,
  }) {
    return QrisDynamicResult(
      success: true,
      nominal: nominal,
      qrisUrl: '',
      qrisString: qrisString,
      merchantName: 'Raziek Store, Toko Wibu',
      merchantCity: 'JAKARTA BARAT',
      errorMessage: reason,
      isFallback: true,
    );
  }
}

/// Service untuk menangani pembayaran QRIS Dinamis (Nexray API & EMVCo Local Engine)
class QrisService {
  static const String apiUrl = 'https://api.nexray.eu.cc/payment/qris';
  static const String defaultAssetPath = 'assets/images/qris.jpg';

  // Base payload static QRIS Raziek Store
  static const String defaultBaseQris =
      '00020101021126610014COM.GO-JEK.WWW01189360091433708546530210G3708546530303UMI51440014ID.CO.QRIS.WWW0215ID10243582650630303UMI5204566153033605802ID5923Raziek Store, Toko Wibu6013JAKARTA BARAT61051164062070703A016304';

  /// Menghasilkan QRIS Dinamis sesuai nominal produk
  /// Menggunakan Nexray API (POST form-data nominal & file)
  /// Dilengkapi fallback lokal jika koneksi ke API mengalami kendala
  static Future<QrisDynamicResult> generateDynamicQris({
    required int nominal,
    String assetPath = defaultAssetPath,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse(apiUrl);
      final request = http.MultipartRequest('POST', uri);
      request.fields['nominal'] = nominal.toString();
      request.fields['url'] = '';

      // Muat gambar asset qris.jpg
      try {
        final byteData = await rootBundle.load(assetPath);
        final bytes = byteData.buffer.asUint8List();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'qris.jpg',
          ),
        );
      } catch (assetErr) {
        debugPrint('[QrisService] Gagal memuat asset image: $assetErr. Menggunakan url kosong.');
      }

      final streamedResponse =
          await httpClient.send(request).timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == true && data['result'] != null) {
          return QrisDynamicResult.fromJson(data, nominal);
        }
      }

      debugPrint(
          '[QrisService] Nexray API response bukan sukses: ${response.statusCode} - ${response.body}. Mengaktifkan local generator.');
    } catch (e) {
      debugPrint('[QrisService] Nexray API Error ($e). Mengaktifkan local generator.');
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    // Fallback otomatis menggunakan engine QRIS EMVCo internal
    final localDynamicString = createLocalDynamicQris(nominal: nominal);
    return QrisDynamicResult.fallback(
      nominal: nominal,
      qrisString: localDynamicString,
      reason: 'Generated via Local Dynamic Engine',
    );
  }

  /// Membangun string QRIS dinamis EMVCo standar nasional (Tag 54 + CRC-16)
  static String createLocalDynamicQris({
    required int nominal,
    String baseQris = defaultBaseQris,
  }) {
    // 1. Ubah Tag 01 dari '11' (Static) menjadi '12' (Dynamic)
    String qris = baseQris;
    if (qris.contains('010211')) {
      qris = qris.replaceFirst('010211', '010212');
    }

    // 2. Potong CRC lama di bagian akhir jika ada
    if (qris.contains('6304')) {
      qris = qris.substring(0, qris.indexOf('6304'));
    }

    // 3. Tambahkan Tag 54 (Transaction Amount) sebelum Tag 58 (Country Code '5802ID')
    final nominalStr = nominal.toString();
    final nominalLenStr = nominalStr.length.toString().padLeft(2, '0');
    final tag54 = '54$nominalLenStr$nominalStr';

    if (qris.contains('5802ID')) {
      final parts = qris.split('5802ID');
      qris = '${parts[0]}$tag54' '5802ID${parts.sublist(1).join('5802ID')}';
    } else {
      qris = '$qris$tag54';
    }

    // 4. Hitung Checksum CRC16 CCITT-FALSE untuk string + '6304'
    final toCheck = '${qris}6304';
    final crc = calculateCrc16(toCheck);
    return '$toCheck$crc';
  }

  /// Menghitung CRC16 CCITT (0xFFFF, 0x1021) standar EMVCo QRIS
  static String calculateCrc16(String str) {
    int crc = 0xFFFF;
    for (int i = 0; i < str.length; i++) {
      crc ^= (str.codeUnitAt(i) << 8);
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
