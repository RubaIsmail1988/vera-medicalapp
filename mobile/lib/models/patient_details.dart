class PatientDetailsRequest {
  int userId;
  String dateOfBirth; // YYYY-MM-DD
  double? height;
  double? weight;
  double? bmi;

  // الحقول الجديدة
  String? gender;
  String? bloodType;
  String? chronicDisease;

  String? healthNotes;

  PatientDetailsRequest({
    required this.userId,
    required this.dateOfBirth,
    this.height,
    this.weight,
    this.bmi,
    this.gender,
    this.bloodType,
    this.chronicDisease,
    this.healthNotes,
  });

  Map<String, dynamic> toJson() => {
    "user_id": userId, // مهم: مطابق للـ serializer
    "date_of_birth": dateOfBirth,
    "height": height,
    "weight": weight,
    "bmi": bmi,
    "gender": gender,
    "blood_type": bloodType,
    "chronic_disease": chronicDisease,
    "health_notes": healthNotes,
  };
}
