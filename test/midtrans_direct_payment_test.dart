import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vibetech_xyz/services/midtrans_direct_payment_service.dart';

void main() {
  group('MidtransDirectPaymentService Channel Mapping Tests', () {
    test('Correctly maps payment channel names', () {
      expect(MidtransDirectPaymentService.mapPaymentChannel('gopay'), 'gopay');
      expect(MidtransDirectPaymentService.mapPaymentChannel('GoPay'), 'gopay');
      expect(MidtransDirectPaymentService.mapPaymentChannel('shopeepay'), 'shopeepay');
      expect(MidtransDirectPaymentService.mapPaymentChannel('ShopeePay'), 'shopeepay');
      expect(MidtransDirectPaymentService.mapPaymentChannel('dana'), 'dana');
      expect(MidtransDirectPaymentService.mapPaymentChannel('DANA'), 'dana');
      expect(MidtransDirectPaymentService.mapPaymentChannel('ovo'), 'ovo');
      expect(MidtransDirectPaymentService.mapPaymentChannel('bca_va'), 'bca_va');
      expect(MidtransDirectPaymentService.mapPaymentChannel('BCA Virtual Account'), 'bca_va');
      expect(MidtransDirectPaymentService.mapPaymentChannel('transfer'), 'bca_va');
      expect(MidtransDirectPaymentService.mapPaymentChannel('Transfer Bank'), 'bca_va');
      expect(MidtransDirectPaymentService.mapPaymentChannel('bri_va'), 'bri_va');
      expect(MidtransDirectPaymentService.mapPaymentChannel('bni_va'), 'bni_va');
      expect(MidtransDirectPaymentService.mapPaymentChannel('mandiri_va'), 'echannel');
      expect(MidtransDirectPaymentService.mapPaymentChannel('echannel'), 'echannel');
    });
  });

  group('MidtransDirectPaymentService Charge & Result Parsing Tests', () {
    test('Parses direct GoPay charge with deeplink_url from backend response', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/charge')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'token': 'mock-snap-token-123',
              'redirect_url': 'https://app.sandbox.midtrans.com/snap/v4/redirection/mock-token',
              'deeplink_url': 'gojek://gopay/merchanttransfer?t=mock-deeplink-token',
              'qr_code_url': 'https://api.sandbox.midtrans.com/v2/gopay/mock-id/qr-code',
              'bank': 'gopay',
              'expiry_time': '2026-09-11 13:30:00',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final result = await MidtransDirectPaymentService.createDirectPayment(
        orderId: 'INV-TEST-001',
        grossAmount: 75000,
        paymentMethod: 'gopay',
        customerEmail: 'buyer@vibetech.xyz',
        client: mockClient,
      );

      expect(result.success, isTrue);
      expect(result.orderId, 'INV-TEST-001');
      expect(result.grossAmount, 75000);
      expect(result.paymentMethod, 'gopay');
      expect(result.token, 'mock-snap-token-123');
      expect(result.deeplinkUrl, contains('gojek://gopay/merchanttransfer'));
      expect(result.qrCodeUrl, isNotNull);
    });

    test('Parses Virtual Account charge with va_number from backend response', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/charge')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'token': 'mock-va-token-456',
              'redirect_url': 'https://app.sandbox.midtrans.com/snap/v4/redirection/mock-va',
              'va_number': '4656712345678901',
              'bank': 'bca_va',
              'expiry_time': '2026-09-12 12:00:00',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final result = await MidtransDirectPaymentService.createDirectPayment(
        orderId: 'INV-VA-002',
        grossAmount: 150000,
        paymentMethod: 'bca_va',
        customerEmail: 'bca.user@vibetech.xyz',
        client: mockClient,
      );

      expect(result.success, isTrue);
      expect(result.orderId, 'INV-VA-002');
      expect(result.grossAmount, 150000);
      expect(result.vaNumber, '4656712345678901');
      expect(result.bank, 'bca_va');
    });

    test('Falls back to direct Midtrans Snap & Snap Pay API when local backend is down', () async {
      final mockClient = MockClient((request) async {
        final urlStr = request.url.toString();
        // Backend lokal offline / timeout
        if (request.url.port == 3000 || urlStr.contains('10.0.2.2')) {
          throw Exception('Connection refused');
        }

        // Midtrans Snap Token Generation
        if (urlStr.contains('/snap/v1/transactions') && !urlStr.contains('/pay')) {
          return http.Response(
            jsonEncode({
              'token': 'snap-direct-token-789',
              'redirect_url': 'https://app.sandbox.midtrans.com/snap/v4/redirection/snap-direct',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        // Midtrans Snap /pay Endpoint
        if (urlStr.contains('/snap/v1/transactions/snap-direct-token-789/pay')) {
          return http.Response(
            jsonEncode({
              'status_code': '201',
              'payment_type': 'gopay',
              'deeplink_url': 'https://simulator.sandbox.midtrans.com/v2/deeplink/detail?tref=MOCK123',
              'qr_code_url': 'https://api.sandbox.midtrans.com/v2/gopay/mock/qr-code',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final result = await MidtransDirectPaymentService.createDirectPayment(
        orderId: 'INV-FALLBACK-003',
        grossAmount: 25000,
        paymentMethod: 'gopay',
        customerEmail: 'fallback@vibetech.xyz',
        client: mockClient,
      );

      expect(result.success, isTrue);
      expect(result.token, 'snap-direct-token-789');
      expect(result.deeplinkUrl, contains('simulator.sandbox.midtrans.com'));
      expect(result.qrCodeUrl, isNotNull);
    });

    test('Verifies payment status correctly from Midtrans Status API', () async {
      final mockClientSettled = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status_code': '200',
            'transaction_status': 'settlement',
            'fraud_status': 'accept',
            'order_id': 'INV-PAID-001',
          }),
          200,
        );
      });

      final isPaid = await MidtransDirectPaymentService.verifyPaymentStatus(
        'INV-PAID-001',
        client: mockClientSettled,
      );
      expect(isPaid, isTrue);

      final mockClientPending = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status_code': '201',
            'transaction_status': 'pending',
            'order_id': 'INV-PENDING-001',
          }),
          200,
        );
      });

      final isPending = await MidtransDirectPaymentService.verifyPaymentStatus(
        'INV-PENDING-001',
        client: mockClientPending,
      );
      expect(isPending, isFalse);
    });

    test('Auto-recovers when Midtrans returns 400 Bad Request (duplicate order_id)', () async {
      int snapAttempts = 0;
      final mockClient = MockClient((request) async {
        final urlStr = request.url.toString();

        // Local backend offline
        if (request.url.port == 3000 || urlStr.contains('10.0.2.2')) {
          throw Exception('Backend offline');
        }

        // Snap token generation endpoint
        if (urlStr.contains('/snap/v1/transactions') && !urlStr.contains('/pay')) {
          snapAttempts++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final txDetails = body['transaction_details'] as Map<String, dynamic>;
          final orderId = txDetails['order_id']?.toString() ?? '';

          // Attempt 1 fails with 400 duplicate order_id (error screenshot case)
          if (snapAttempts == 1) {
            return http.Response(
              jsonEncode({
                'error_messages': ['transaction_details.order_id has already been taken']
              }),
              400,
              headers: {'content-type': 'application/json'},
            );
          }

          // Attempt 2 (auto-recovered with suffix) succeeds!
          expect(orderId, startsWith('INV-DUP-001-'));
          return http.Response(
            jsonEncode({
              'token': 'snap-recovered-token-999',
              'redirect_url': 'https://app.sandbox.midtrans.com/snap/v4/redirection/snap-recovered',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        // Snap /pay endpoint
        if (urlStr.contains('/snap/v1/transactions/snap-recovered-token-999/pay')) {
          return http.Response(
            jsonEncode({
              'status_code': '201',
              'payment_type': 'gopay',
              'deeplink_url': 'gojek://gopay/merchanttransfer?t=recovered-123',
              'qr_code_url': 'https://api.sandbox.midtrans.com/v2/gopay/recovered/qr-code',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final result = await MidtransDirectPaymentService.createDirectPayment(
        orderId: 'INV-DUP-001',
        grossAmount: 160000,
        paymentMethod: 'gopay',
        customerEmail: 'invalid-email-string', // test email sanitization fallback
        client: mockClient,
      );

      expect(result.success, isTrue);
      expect(result.orderId, startsWith('INV-DUP-001-'));
      expect(result.token, 'snap-recovered-token-999');
      expect(result.deeplinkUrl, contains('gojek://gopay'));
      expect(snapAttempts, 2);
    });
  });
}
