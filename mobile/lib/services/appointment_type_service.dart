import 'dart:convert';

import '../models/appointment_type.dart';
import 'auth_service.dart';

class AppointmentTypeService {
  final AuthService authService = AuthService();

  Future<List<AppointmentType>> fetchAppointmentTypesReadOnly() async {
    final response = await authService.authorizedRequest(
      "/appointment-types-read/",
      "GET",
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => AppointmentType.fromJson(e)).toList();
    }

    throw Exception(
      'Failed to load appointment types: ${response.statusCode} - ${response.body}',
    );
  }
}
