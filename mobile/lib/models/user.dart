class User {
  final int id;
  final String email;
  final String username;
  final String role;
  final bool isActive;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.role,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      role: json['role'],
      isActive: json['is_active'],
    );
  }
}
