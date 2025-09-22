import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UserUsageResult {
  final double credit;
  final double creditUsed;
  UserUsageResult({required this.credit, required this.creditUsed});
}

class UserRepository {
  final String baseUrl;
  final http.Client _client;
  UserRepository({http.Client? client})
    : _client = client ?? http.Client(),
      baseUrl = dotenv.env['API_BASE_URL'] ?? '' {
    if (baseUrl.isEmpty) {
      throw StateError('Missing API_BASE_URL in .env');
    }
  }

  Future<UserUsageResult> getUsageByEmail(String email) async {
    final uri = Uri.parse('$baseUrl/get-user');
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (resp.statusCode != 200) {
      throw Exception(
        'POST /get-user -> ${resp.statusCode} ${resp.reasonPhrase}',
      );
    }
    final json = jsonDecode(resp.body);
    final credit = (json['credit'] is num)
        ? (json['credit'] as num).toDouble()
        : 0.0;
    final creditUsed = (json['creditUsed'] is num)
        ? (json['creditUsed'] as num).toDouble()
        : 0.0;
    return UserUsageResult(credit: credit, creditUsed: creditUsed);
  }
}
