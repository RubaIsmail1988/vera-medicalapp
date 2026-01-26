import 'dart:convert';

import '/models/governorate.dart';
import '/utils/api_exception.dart';
import '/services/auth_service.dart';

class GovernorateService {
  final AuthService authService = AuthService();

  Future<List<Governorate>> fetchGovernorates() async {
    try {
      final response = await authService.authorizedRequestOrThrow(
        '/governorates/',
        'GET',
      );

      final dynamic data = jsonDecode(response.body);

      if (data is List) {
        return data
            .map((e) => Governorate.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // إذا رجع شكل غير متوقع
      throw ApiException(
        500,
        'Unexpected response shape for governorates: ${response.body}',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      // أي شيء غير متوقع (parsing وغيره)
      throw ApiException(500, 'Governorate parse error: $e');
    }
  }
}
