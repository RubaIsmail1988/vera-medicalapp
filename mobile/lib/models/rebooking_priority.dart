class RebookingPriority {
  final bool active;
  final DateTime expiresAt;

  const RebookingPriority({required this.active, required this.expiresAt});

  factory RebookingPriority.fromJson(Map<String, dynamic> json) {
    return RebookingPriority(
      active: json['active'] == true,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}
