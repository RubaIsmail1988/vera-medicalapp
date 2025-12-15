class RegisterRequest {
  String email;
  String username;
  String password;
  String phone;
  int governorate;
  String address;
  String role; // "patient" or "doctor"

  RegisterRequest({
    required this.email,
    required this.username,
    required this.password,
    required this.phone,
    required this.governorate,
    required this.address,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
    "email": email,
    "username": username,
    "password": password,
    "phone": phone,
    "governorate": governorate,
    "address": address,
    "role": role,
  };
}
