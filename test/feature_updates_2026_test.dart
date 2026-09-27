import 'package:flutter_test/flutter_test.dart';
import 'package:vibetech_xyz/models/support_ticket_model.dart';
import 'package:vibetech_xyz/services/firebase_ticket_service.dart';
import 'package:vibetech_xyz/services/server_provisioning_service.dart';

void main() {
  group('Fitur Baru VibeTech XYZ 2026 Tests', () {
    test('1. SupportTicket Model Serialization & Status Helpers', () {
      final now = DateTime.now().toIso8601String();
      final ticket = SupportTicket(
        id: 1,
        ticketNo: 'TKT-2026-999',
        userName: 'Raziek Raditya',
        userEmail: 'user@vibetech.com',
        category: 'Teknis Server',
        priority: 'Kritis / Urgent',
        subject: 'Kendala Port SSH VPS',
        message: 'Port 22 tidak merespons setelah reboot.',
        status: 'Open',
        createdAt: now,
        response: 'Teknisi sedang menganalisis log hypervisor.',
      );

      final map = ticket.toMap();
      expect(map['ticket_no'], 'TKT-2026-999');
      expect(map['category'], 'Teknis Server');
      expect(map['priority'], 'Kritis / Urgent');
      expect(map['status'], 'Open');

      final json = ticket.toJson();
      expect(json['ticket_no'], 'TKT-2026-999');
      expect(json['response'], 'Teknisi sedang menganalisis log hypervisor.');

      final restored = SupportTicket.fromMap(map);
      expect(restored.ticketNo, 'TKT-2026-999');
      expect(restored.isOpen, isTrue);
      expect(restored.isInProgress, isFalse);
      expect(restored.isResolved, isFalse);

      final inProgress = restored.copyWith(status: 'In Progress');
      expect(inProgress.isOpen, isFalse);
      expect(inProgress.isInProgress, isTrue);

      final resolved = restored.copyWith(status: 'Resolved');
      expect(resolved.isOpen, isFalse);
      expect(resolved.isResolved, isTrue);
    });

    test('2. FirebaseTicketService RTDB URI & Singleton Verification', () async {
      expect(FirebaseTicketService.instance, isNotNull);
      final uri = await FirebaseTicketService.buildTicketRtdbUri('TKT-100.json');
      expect(uri.toString(), contains('support_tickets/TKT-100.json'));
      expect(uri.scheme, 'https');
      expect(uri.host, 'vibetech-xyz-default-rtdb.asia-southeast1.firebasedatabase.app');
    });

    test('3. ServerProvisioningService Singleton & Instance Verification', () {
      expect(ServerProvisioningService.instance, isNotNull);
    });
  });
}
