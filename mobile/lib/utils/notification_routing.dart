import 'dart:convert';

class NotificationRouting {
  static Map<String, dynamic> parsePayload(String? payload) {
    if (payload == null) return {};
    final text = payload.trim();
    if (text.isEmpty) return {};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  /// يبني URL لتفاصيل الطلب مع query params "web-safe"
  static String _orderDetailsLocation({
    required int orderId,
    required String role,
    int? patientId,
    int? appointmentId,
  }) {
    final qp = <String, String>{"role": role};

    if (role == "doctor" && patientId != null && patientId > 0) {
      qp["patientId"] = patientId.toString();
    }

    if (appointmentId != null && appointmentId > 0) {
      qp["appointmentId"] = appointmentId.toString();
    }

    final query = Uri(queryParameters: qp).query;
    return "/app/record/orders/$orderId?$query";
  }

  /// role: يتم تمريره من الخارج (من prefs) لضمان الصحة على نفس الجهاز (طبيب/مريض)
  static String resolveLocation(
    Map<String, dynamic> data, {
    required String currentRole,
  }) {
    final eventType = (data["event_type"] ?? data["type"] ?? "").toString();

    switch (eventType) {
      // ---------------- Appointments ----------------
      case "appointment_created":
      case "appointment_confirmed":
      case "appointment_cancelled":
        return "/app/appointments";

      // ---------------- Orders / Files ----------------
      case "CLINICAL_ORDER_CREATED":
      case "clinical_order_created":
      case "file_uploaded":
      case "file_reviewed":
        final orderId =
            _toInt(data["order_id"]) ??
            _toInt(data["object_id"]) ??
            _toInt(data["entity_id"]);

        if (orderId == null || orderId <= 0) {
          // fallback
          return "/app/record/files";
        }

        final patientId = _toInt(data["patient_id"]);
        final appointmentId = _toInt(data["appointment_id"]);

        return _orderDetailsLocation(
          orderId: orderId,
          role: currentRole,
          patientId: patientId,
          appointmentId: appointmentId,
        );

      // ---------------- Prescriptions ----------------
      case "PRESCRIPTION_CREATED":
      case "prescription_created":
        return "/app/record/prescripts";

      default:
        return "/app/inbox";
    }
  }
}
