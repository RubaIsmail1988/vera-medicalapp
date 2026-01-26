import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/appointment_type.dart';
import '/utils/api_exception.dart';
import 'auth_service.dart';

class AppointmentTypeService {
  final AuthService authService = AuthService();

  Future<List<AppointmentType>> fetchAppointmentTypesReadOnly() async {
    http.Response response;

    try {
      response = await authService.authorizedRequest(
        "/appointment-types-read/",
        "GET",
      );
    } catch (e) {
      // شبكة/انقطاع اتصال أو مشاكل http client
      if (ApiExceptionUtils.isNetworkException(e)) {
        throw ApiExceptionUtils.network(e);
      }
      rethrow;
    }

    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);

      // نتوقع List
      if (decoded is List) {
        return decoded
            .map((e) => AppointmentType.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // body غير متوقع
      throw const ApiException(500, 'Unexpected response format');
    }

    throw ApiExceptionUtils.fromResponse(response);
  }
}
