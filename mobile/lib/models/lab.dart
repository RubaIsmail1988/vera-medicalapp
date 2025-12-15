class Lab {
  final int? id;
  final String name;
  final int governorate;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? specialty;
  final String? contactInfo;

  Lab({
    this.id,
    required this.name,
    required this.governorate,
    this.address,
    this.latitude,
    this.longitude,
    this.specialty,
    this.contactInfo,
  });

  factory Lab.fromJson(Map<String, dynamic> json) {
    return Lab(
      id: json['id'] as int?,
      name: json['name']?.toString() ?? '',
      governorate:
          json['governorate'] is int
              ? json['governorate']
              : int.tryParse(json['governorate'].toString()) ?? 0,
      address: json['address']?.toString(),
      latitude:
          json['latitude'] != null
              ? double.tryParse(json['latitude'].toString())
              : null,
      longitude:
          json['longitude'] != null
              ? double.tryParse(json['longitude'].toString())
              : null,
      specialty: json['specialty']?.toString(),
      contactInfo: json['contact_info']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "governorate": governorate,
      "address": address,
      "latitude": latitude,
      "longitude": longitude,
      "specialty": specialty,
      "contact_info": contactInfo,
    };
  }
}
