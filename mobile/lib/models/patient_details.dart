class PatientDetailsRequest {
  int userId;
  String dateOfBirth; // YYYY-MM-DD
  double? height;
  double? weight;
  double? bmi;

  String? gender;
  String? bloodType;

  String? smokingStatus; // "never" | "former" | "current"
  int? cigarettesPerDay;

  String? alcoholUse; // "none" | "occasional" | "regular"
  String? activityLevel; // "low" | "moderate" | "high"

  bool? hasDiabetes;
  bool? hasHypertension;
  bool? hasHeartDisease;
  bool? hasAsthmaCopd;
  bool? hasKidneyDisease;

  bool? isPregnant;

  int? lastBpSystolic;
  int? lastBpDiastolic;
  String? bpMeasuredAt; // ISO datetime string, nullable

  double? lastHba1c;
  String? hba1cMeasuredAt; // YYYY-MM-DD, nullable

  String? allergies;

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
    this.smokingStatus,
    this.cigarettesPerDay,
    this.alcoholUse,
    this.activityLevel,
    this.hasDiabetes,
    this.hasHypertension,
    this.hasHeartDisease,
    this.hasAsthmaCopd,
    this.hasKidneyDisease,
    this.isPregnant,
    this.lastBpSystolic,
    this.lastBpDiastolic,
    this.bpMeasuredAt,
    this.lastHba1c,
    this.hba1cMeasuredAt,
    this.allergies,
    this.chronicDisease,
    this.healthNotes,
  });

  Map<String, dynamic> toJson() => {
    "user_id": userId,
    "date_of_birth": dateOfBirth,
    "height": height,
    "weight": weight,
    "bmi": bmi,
    "gender": gender,
    "blood_type": bloodType,

    "smoking_status": smokingStatus,
    "cigarettes_per_day": cigarettesPerDay,
    "alcohol_use": alcoholUse,
    "activity_level": activityLevel,

    "has_diabetes": hasDiabetes,
    "has_hypertension": hasHypertension,
    "has_heart_disease": hasHeartDisease,
    "has_asthma_copd": hasAsthmaCopd,
    "has_kidney_disease": hasKidneyDisease,

    "is_pregnant": isPregnant,

    "last_bp_systolic": lastBpSystolic,
    "last_bp_diastolic": lastBpDiastolic,
    "bp_measured_at": bpMeasuredAt,

    "last_hba1c": lastHba1c,
    "hba1c_measured_at": hba1cMeasuredAt,

    "allergies": allergies,

    "chronic_disease": chronicDisease,
    "health_notes": healthNotes,
  };
}
