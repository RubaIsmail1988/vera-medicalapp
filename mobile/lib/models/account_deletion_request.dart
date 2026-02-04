class AccountDeletionRequest {
  final int id;
  final int userId;
  final String userEmail;
  final String userRole;
  final String? reason;
  final String status; // pending / approved / rejected
  final String? adminNote;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String userName;

  AccountDeletionRequest({
    required this.id,
    required this.userId,
    required this.userName, // NEW
    required this.userEmail,
    required this.userRole,
    required this.reason,
    required this.status,
    required this.adminNote,
    required this.createdAt,
    required this.processedAt,
  });

  factory AccountDeletionRequest.fromJson(Map<String, dynamic> json) {
    return AccountDeletionRequest(
      id: json['id'] as int,
      userId: json['user'] as int,
      userName: json['user_name']?.toString() ?? '', // NEW
      userEmail: json['user_email']?.toString() ?? '',
      userRole: json['user_role']?.toString() ?? '',
      reason: json['reason']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      adminNote: json['admin_note']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
      processedAt:
          json['processed_at'] != null
              ? DateTime.parse(json['processed_at'] as String)
              : null,
    );
  }
}
