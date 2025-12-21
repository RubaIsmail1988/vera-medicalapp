class Governorate {
  final int id;
  final String name;

  const Governorate({required this.id, required this.name});

  factory Governorate.fromJson(Map<String, dynamic> json) {
    return Governorate(
      id: json['id'] as int,
      name: (json['name'] ?? '').toString(),
    );
  }
}
