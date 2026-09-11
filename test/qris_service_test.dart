import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vibetech_xyz/services/qris_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QrisService Tests', () {
    test('calculateCrc16 generates exact standard EMVCo checksum', () {
      const testPayload =
          '00020101021226610014COM.GO-JEK.WWW01189360091433708546530210G3708546530303UMI51440014ID.CO.QRIS.WWW0215ID10243582650630303UMI5204566153033605405250005802ID5923Raziek Store, Toko Wibu6013JAKARTA BARAT61051164062070703A016304';
      final crc = QrisService.calculateCrc16(testPayload);
      expect(crc, 'FB93');
    });

    test('createLocalDynamicQris injects dynamic tag 01 and tag 54 nominal', () {
      final dynamicQris = QrisService.createLocalDynamicQris(nominal: 25000);
      expect(dynamicQris.contains('010212'), isTrue);
      expect(dynamicQris.contains('540525000'), isTrue);
      expect(dynamicQris.endsWith('FB93'), isTrue);
    });

    test('QrisDynamicResult correctly parses successful Nexray API JSON', () {
      final jsonSample = {
        'status': true,
        'author': '@nexray - ElrayyXml',
        'result': {
          'nominal': 25000,
          'qris_url': 'https://api.nexray.eu.cc/tmp/e1bfd945071a.png',
          'qris_string':
              '00020101021226610014COM.GO-JEK.WWW01189360091433708546530210G3708546530303UMI51440014ID.CO.QRIS.WWW0215ID10243582650630303UMI5204566153033605405250005802ID5923Raziek Store, Toko Wibu6013JAKARTA BARAT61051164062070703A016304FB93',
          'merchant_name': 'Raziek Store, Toko Wibu',
          'merchant_city': 'JAKARTA BARAT',
          'country_code': 'ID',
          'currency': 'IDR'
        }
      };

      final result = QrisDynamicResult.fromJson(jsonSample, 25000);
      expect(result.success, isTrue);
      expect(result.nominal, 25000);
      expect(result.merchantName, 'Raziek Store, Toko Wibu');
      expect(result.qrisUrl, contains('nexray.eu.cc'));
      expect(result.qrisString, contains('540525000'));
      expect(result.isFallback, isFalse);
    });

    test('generateDynamicQris with mock client returns parsed result', () async {
      final mockClient = MockClient((request) async {
        final body = jsonEncode({
          'status': true,
          'result': {
            'nominal': 50000,
            'qris_url': 'https://api.nexray.eu.cc/tmp/mock.png',
            'qris_string': 'MOCK_QRIS_STRING_50000',
            'merchant_name': 'Raziek Store, Toko Wibu',
            'merchant_city': 'JAKARTA BARAT',
          }
        });
        return http.Response(body, 200, headers: {'content-type': 'application/json'});
      });

      final result = await QrisService.generateDynamicQris(
        nominal: 50000,
        client: mockClient,
      );

      expect(result.success, isTrue);
      expect(result.nominal, 50000);
      expect(result.qrisString, 'MOCK_QRIS_STRING_50000');
    });
  });
}
