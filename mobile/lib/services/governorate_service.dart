import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '/models/governorate.dart';
import '../utils/constants.dart';

class GovernorateService {
  Future<List<Governorate>> fetchGovernorates() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final uri = Uri.parse('$accountsBaseUrl/governorates/');

    final res = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Failed to load governorates: ${res.statusCode} ${res.body}',
      );
    }

    final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => Governorate.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
