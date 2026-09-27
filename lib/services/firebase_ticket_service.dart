import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vibetech_xyz/database/db_helper.dart';
import 'package:vibetech_xyz/models/support_ticket_model.dart';
import 'package:vibetech_xyz/services/firebase_auth_token_service.dart';

/// ============================================================================
/// FIREBASE TICKET SERVICE - VIBETECH XYZ (HELPDESK CUSTOMER SUPPORT)
/// ============================================================================
/// Layanan cloud database ganda untuk menyimpan, mengupdate, dan menyinkronkan
/// tiket bantuan (Support Ticket) pengguna secara real-time ke:
/// 1. Firebase Realtime Database (/support_tickets)
/// 2. SQLite Database Lokal (tabel support_tickets)
class FirebaseTicketService {
  static final FirebaseTicketService instance = FirebaseTicketService._init();
  FirebaseTicketService._init();

  static const String rtdbBaseUrl =
      'https://vibetech-xyz-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String collectionName = 'support_tickets';

  /// Notifier reaktif agar antarmuka UI Live Chat / Helpdesk otomatis reload saat ada tiket baru
  final ValueNotifier<int> ticketsUpdateNotifier = ValueNotifier<int>(0);

  /// Helper untuk membangun URI RTDB terautentikasi (mencegah 401 Permission Denied)
  static Future<Uri> buildTicketRtdbUri([String? docKey]) async {
    final token = await FirebaseAuthTokenService.instance.getIdToken();
    final authParam = (token != null && token.isNotEmpty) ? '?auth=$token' : '';
    if (docKey != null && docKey.isNotEmpty) {
      final clean = docKey.endsWith('.json') ? docKey : '$docKey.json';
      return Uri.parse('$rtdbBaseUrl/$collectionName/$clean$authParam');
    }
    return Uri.parse('$rtdbBaseUrl/$collectionName.json$authParam');
  }

  /// Membuat dan menyimpan tiket bantuan baru ke SQLite Lokal & Firebase Realtime Database
  Future<SupportTicket> createTicket({
    required String userName,
    required String userEmail,
    required String category,
    required String subject,
    required String message,
    String priority = 'Normal',
  }) async {
    final now = DateTime.now();
    final ticketNo = 'TKT-${now.millisecondsSinceEpoch.toString().substring(5)}';

    final ticket = SupportTicket(
      ticketNo: ticketNo,
      userName: userName.trim().isEmpty ? 'Pelanggan VibeTech' : userName.trim(),
      userEmail: userEmail.trim().toLowerCase(),
      category: category,
      priority: priority,
      subject: subject.trim(),
      message: message.trim(),
      status: 'Open',
      createdAt: now.toIso8601String(),
      response: 'Tiket telah diterima sistem dan sedang dalam antrean peninjauan oleh tim teknis VibeTech XYZ.',
      updatedAt: now.toIso8601String(),
    );

    // 1. Simpan ke SQLite Lokal (Instan 0ms)
    try {
      await DatabaseHelper.instance.createSupportTicket(ticket.toMap());
    } catch (e) {
      debugPrint('[FirebaseTicketService] Error simpan SQLite: $e');
    }

    // 2. Simpan ke Firebase Realtime Database via HTTP REST API
    try {
      final uri = await buildTicketRtdbUri('$ticketNo.json');
      final res = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(ticket.toJson()),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        debugPrint('[FirebaseTicketService] ✅ Tiket $ticketNo berhasil disimpan ke Firebase RTDB!');
      } else {
        debugPrint('[FirebaseTicketService] Gagal simpan ke Firebase (Status: ${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      debugPrint('[FirebaseTicketService] Exception simpan ke Firebase: $e');
    }

    ticketsUpdateNotifier.value++;
    return ticket;
  }

  /// Mengambil daftar tiket milik pengguna dari SQLite lokal & memicu background sync dari Firebase RTDB
  Future<List<SupportTicket>> getTicketsByUser(String userEmail) async {
    final cleanEmail = userEmail.trim().toLowerCase();
    final List<SupportTicket> result = [];

    // Baca data lokal SQLite
    try {
      final rows = await DatabaseHelper.instance.getSupportTickets(userEmail: cleanEmail);
      result.addAll(rows.map((r) => SupportTicket.fromMap(r)));
    } catch (e) {
      debugPrint('[FirebaseTicketService] Error read local tickets: $e');
    }

    // Background sync dari Firebase RTDB
    syncTicketsFromFirebase(userEmail: cleanEmail).catchError((e) {
      debugPrint('[FirebaseTicketService] Background sync error: $e');
      return 0;
    });

    return result;
  }

  /// Mengambil semua tiket (untuk akun Admin)
  Future<List<SupportTicket>> getAllTickets() async {
    final List<SupportTicket> result = [];
    try {
      final rows = await DatabaseHelper.instance.getSupportTickets();
      result.addAll(rows.map((r) => SupportTicket.fromMap(r)));
    } catch (e) {
      debugPrint('[FirebaseTicketService] Error read all tickets: $e');
    }
    return result;
  }

  /// Sinkronisasi penuh tiket dari Firebase Realtime Database ke SQLite lokal
  Future<int> syncTicketsFromFirebase({String? userEmail}) async {
    try {
      final uri = await buildTicketRtdbUri();
      final res = await http.get(uri).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        final dynamic decoded = jsonDecode(res.body);
        if (decoded is Map) {
          int count = 0;
          final cleanUserEmail = userEmail?.trim().toLowerCase();

          for (final entry in decoded.entries) {
            final val = entry.value;
            if (val is Map) {
              final mapData = Map<String, dynamic>.from(val);
              final tktEmail = (mapData['user_email'] ?? '').toString().toLowerCase();

              if (cleanUserEmail == null || tktEmail == cleanUserEmail) {
                final ticket = SupportTicket.fromMap(mapData);
                // Update / Insert ke SQLite
                await DatabaseHelper.instance.createSupportTicket(ticket.toMap());
                count++;
              }
            }
          }

          if (count > 0) {
            ticketsUpdateNotifier.value++;
            debugPrint('[FirebaseTicketService] 🔄 Berhasil menyinkronkan $count tiket dari Firebase RTDB');
          }
          return count;
        }
      }
    } catch (e) {
      debugPrint('[FirebaseTicketService] Gagal sync dari Firebase: $e');
    }
    return 0;
  }

  /// Memperbarui status tiket (misal: 'In Progress', 'Resolved') di SQLite & Firebase RTDB
  Future<bool> updateTicketStatus(
    String ticketNo,
    String newStatus, {
    String? adminResponse,
  }) async {
    final nowIso = DateTime.now().toIso8601String();

    // 1. Update SQLite Lokal
    try {
      await DatabaseHelper.instance.updateSupportTicketStatusByTicketNo(
        ticketNo,
        newStatus,
        response: adminResponse,
      );
    } catch (e) {
      debugPrint('[FirebaseTicketService] Error update SQLite status: $e');
    }

    // 2. Update Firebase Realtime Database via PATCH
    try {
      final uri = await buildTicketRtdbUri('$ticketNo.json');
      final patchData = {
        'status': newStatus,
        'updated_at': nowIso,
        if (adminResponse != null && adminResponse.isNotEmpty)
          'response': adminResponse,
      };

      await http.patch(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(patchData),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[FirebaseTicketService] Error PATCH Firebase: $e');
    }

    ticketsUpdateNotifier.value++;
    return true;
  }
}
