/// ============================================================================
/// MODEL TIKET BANTUAN (SUPPORT TICKET MODEL) - VIBETECH XYZ
/// ============================================================================
/// Model terstruktur untuk sistem Helpdesk & Customer Support VibeTech XYZ:
/// - Kategori: Billing, Teknis Server, Request Fitur Bot WA, Gangguan Jaringan.
/// - Status: Open (Kuning), In Progress (Biru), Resolved (Hijau).
/// - Tersimpan ganda di SQLite Lokal & Firebase Realtime Database (/support_tickets).
class SupportTicket {
  final int? id;
  final String ticketNo;
  final String userName;
  final String userEmail;
  final String category;
  final String priority;
  final String subject;
  final String message;
  final String status;
  final String createdAt;
  final String? response;
  final String? updatedAt;

  const SupportTicket({
    this.id,
    required this.ticketNo,
    required this.userName,
    required this.userEmail,
    required this.category,
    this.priority = 'Normal',
    required this.subject,
    required this.message,
    this.status = 'Open',
    required this.createdAt,
    this.response,
    this.updatedAt,
  });

  /// Konversi dari Map SQLite
  factory SupportTicket.fromMap(Map<String, dynamic> map) {
    return SupportTicket(
      id: (map['id'] as num?)?.toInt() ?? int.tryParse(map['id']?.toString() ?? ''),
      ticketNo: (map['ticket_no'] ?? '').toString(),
      userName: (map['user_name'] ?? '').toString(),
      userEmail: (map['user_email'] ?? '').toString(),
      category: (map['category'] ?? 'Billing').toString(),
      priority: (map['priority'] ?? 'Normal').toString(),
      subject: (map['subject'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      status: (map['status'] ?? 'Open').toString(),
      createdAt: (map['created_at'] ?? DateTime.now().toIso8601String()).toString(),
      response: map['response']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }

  /// Konversi ke Map untuk SQLite
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'ticket_no': ticketNo,
      'user_name': userName,
      'user_email': userEmail,
      'category': category,
      'priority': priority,
      'subject': subject,
      'message': message,
      'status': status,
      'created_at': createdAt,
      'response': response,
      'updated_at': updatedAt,
    };
  }

  /// Konversi ke Map JSON untuk Firebase Realtime Database
  Map<String, dynamic> toJson() {
    return {
      'ticket_no': ticketNo,
      'user_name': userName,
      'user_email': userEmail,
      'category': category,
      'priority': priority,
      'subject': subject,
      'message': message,
      'status': status,
      'created_at': createdAt,
      'response': response,
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  /// Duplikasi objek dengan perubahan tertentu
  SupportTicket copyWith({
    int? id,
    String? ticketNo,
    String? userName,
    String? userEmail,
    String? category,
    String? priority,
    String? subject,
    String? message,
    String? status,
    String? createdAt,
    String? response,
    String? updatedAt,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      ticketNo: ticketNo ?? this.ticketNo,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      subject: subject ?? this.subject,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      response: response ?? this.response,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Status badge color helper
  bool get isOpen => status.toLowerCase() == 'open';
  bool get isInProgress =>
      status.toLowerCase() == 'in progress' ||
      status.toLowerCase() == 'diproses' ||
      status.toLowerCase() == 'in_progress';
  bool get isResolved =>
      status.toLowerCase() == 'resolved' ||
      status.toLowerCase() == 'selesai' ||
      status.toLowerCase() == 'closed';
}
