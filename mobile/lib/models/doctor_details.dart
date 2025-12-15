class DoctorDetailsRequest {
  int userId;
  String specialty;
  int experienceYears;
  String? notes;

  DoctorDetailsRequest({
    required this.userId,
    required this.specialty,
    required this.experienceYears,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    "user": userId,
    "specialty": specialty,
    "experience_years": experienceYears,
    "notes": notes,
  };
}
