import 'dart:convert';
import 'package:http/http.dart' as http;

import '/models/governorate.dart';
import '/utils/api_exception.dart';
import '/utils/constants.dart';

class GovernorateService {
  Uri _buildAccountsUri(String endpoint) {
    final cleanBase =
        accountsBaseUrl.endsWith('/')
            ? accountsBaseUrl.substring(0, accountsBaseUrl.length - 1)
            : accountsBaseUrl;

    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$cleanBase$cleanEndpoint');
  }

  Future<List<Governorate>> fetchGovernorates() async {
    try {
      final url = _buildAccountsUri('/governorates/');

      final response = await http.get(
        url,
        headers: {"Accept": "application/json"},
      );

      if (response.statusCode != 200) {
        throw ApiException(response.statusCode, response.body);
      }

      final dynamic data = jsonDecode(response.body);

      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Governorate.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      // بعض الـ APIs ترجع {results:[...]}
      if (data is Map && data["results"] is List) {
        final items = data["results"] as List;
        return items
            .whereType<Map>()
            .map((e) => Governorate.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      throw ApiException(
        500,
        'Unexpected response shape for governorates: ${response.body}',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(500, 'Governorate fetch/parse error: $e');
    }
  }
}
