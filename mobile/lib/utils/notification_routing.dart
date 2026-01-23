import 'dart:convert';

class NotificationRouting {
  static Map<String, dynamic> parsePayload(String? payload) {
    if (payload == null) return <String, dynamic>{};
    final text = payload.trim();
    if (text.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  static String _safeRoute(String? route) {
    final r = (route ?? '').trim();
    if (r.isEmpty) return '';
    // enforce app-only navigation (avoid accidental external paths)
    if (!r.startsWith('/')) return '';
    if (!r.startsWith('/app')) return '';
    return r;
  }

  static String _ensureRoleInOrderRoute({
    required String route,
    required String role,
    int? patientId,
    int? appointmentId,
  }) {
    // We only mutate routes that target order details.
    // Supported patterns:
    // /app/record/orders/<id>
    // /app/record/orders/<id>?...
    final uri = Uri.tryParse(route);
    if (uri == null) return route;

    final path = uri.path;
    if (!path.startsWith('/app/record/orders/')) return route;

    final qp = Map<String, String>.from(uri.queryParameters);

    // Ensure role exists (web-safe)
    final safeRole = (role.trim() == 'doctor') ? 'doctor' : 'patient';
    qp.putIfAbsent('role', () => safeRole);

    // Optional enrichments for doctor context (won't hurt if absent)
    if (safeRole == 'doctor' && patientId != null && patientId > 0) {
      qp.putIfAbsent('patientId', () => patientId.toString());
    }
    if (appointmentId != null && appointmentId > 0) {
      qp.putIfAbsent('appointmentId', () => appointmentId.toString());
    }

    return Uri(path: path, queryParameters: qp.isEmpty ? null : qp).toString();
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
    final safeRole = (currentRole.trim() == 'doctor') ? 'doctor' : 'patient';

    // (A) Optional policy: ignore self file-deleted events created by patient
    // - We keep user inside app, but don't force navigation to files.
    // - If you prefer: return "/app/record/files";
    final eventTypeHint = (data["event_type"] ?? data["type"] ?? "").toString();
    if (eventTypeHint == "MEDICAL_FILE_DELETED") {
      final reason = (data["reason"] ?? '').toString().trim();
      final actorId = _toInt(data["actor_id"]);
      final recipientId = _toInt(data["recipient_id"]);
      final isSelf =
          actorId != null && recipientId != null && actorId == recipientId;
      if (isSelf && reason == "deleted_by_patient") {
        return "/app/inbox";
      }
    }
    // ---------------- Urgent requests (override routing) ----------------
    // Server currently sends route "/app/appointments" for urgent_request_created,
    // but for doctors we want to jump directly to the urgent requests screen.
    if (eventTypeHint == "urgent_request_created" && safeRole == "doctor") {
      return "/app/appointments/urgent-requests";
    }

    // Patient-side urgent updates should go to appointments.
    if (eventTypeHint == "urgent_request_scheduled" ||
        eventTypeHint == "urgent_request_rejected") {
      return "/app/appointments";
    }

    // Emergency absence cancellation: patient should see appointments (priority rebook info)
    if (eventTypeHint == "appointment_cancelled_due_to_emergency_absence") {
      return "/app/appointments";
    }

    // 0) Highest priority: server-provided route (payload richness)
    final rawRoute = _safeRoute(data["route"]?.toString());
    if (rawRoute.isNotEmpty) {
      // If server gave an order route, ensure required web-safe params.
      final patientId = _toInt(data["patient_id"]);
      final appointmentId = _toInt(data["appointment_id"]);
      return _ensureRoleInOrderRoute(
        route: rawRoute,
        role: safeRole,
        patientId: patientId,
        appointmentId: appointmentId,
      );
    }

    // 1) Some events are effectively "status-driven"
    final status = (data["status"] ?? '').toString().toLowerCase().trim();

    // adherence: taken/skipped
    if (status == 'taken' || status == 'skipped') {
      return "/app/record/adherence";
    }

    // appointments: no_show (status)
    if (status == 'no_show') {
      return "/app/appointments";
    }

    final eventType = (data["event_type"] ?? data["type"] ?? "").toString();

    switch (eventType) {
      // ---------------- Appointments ----------------
      case "appointment_created":
      case "appointment_confirmed":
      case "appointment_cancelled":
      case "appointment_no_show":
      case "APPOINTMENT_NO_SHOW":
        return "/app/appointments";
      // ---------------- Urgent Requests ----------------
      case "urgent_request_created":
        // doctor override already handled above; fallback:
        return (safeRole == "doctor")
            ? "/app/appointments/urgent-requests"
            : "/app/appointments";

      case "urgent_request_scheduled":
      case "urgent_request_rejected":
        return "/app/appointments";

      // ---------------- Emergency absence ----------------
      case "appointment_cancelled_due_to_emergency_absence":
        return "/app/appointments";

      // ---------------- Orders ----------------
      case "CLINICAL_ORDER_CREATED":
      case "clinical_order_created":
        final orderId =
            _toInt(data["order_id"]) ??
            _toInt(data["object_id"]) ??
            _toInt(data["entity_id"]);

        if (orderId == null || orderId <= 0) {
          return "/app/record";
        }

        final patientId = _toInt(data["patient_id"]);
        final appointmentId = _toInt(data["appointment_id"]);

        return _orderDetailsLocation(
          orderId: orderId,
          role: safeRole,
          patientId: patientId,
          appointmentId: appointmentId,
        );

      // ---------------- Files ----------------
      case "file_uploaded":
      case "file_reviewed":
        return "/app/record/files";

      case "MEDICAL_FILE_DELETED":
        // General fallback: files tab (except the ignored self-delete policy above)
        return "/app/record/files";

      // ---------------- Prescriptions ----------------
      case "PRESCRIPTION_CREATED":
      case "prescription_created":
        return "/app/record/prescripts";

      // ---------------- Adherence explicit ----------------
      case "ADHERENCE_CREATED":
      case "adherence_created":
      case "MEDICATION_ADHERENCE_RECORDED":
        return "/app/record/adherence";

      default:
        return "/app/inbox";
    }
  }
}
