// lib/services/history_message_repository.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/history_message.dart';

class HistoryMessageRepository {
  final String baseUrl;
  final http.Client _client;

  HistoryMessageRepository({http.Client? client})
    : _client = client ?? http.Client(),
      baseUrl = dotenv.env['API_BASE_URL'] ?? '' {
    if (baseUrl.isEmpty) {
      throw StateError('Missing API_BASE_URL in .env');
    }
  }

  // === HÀM MỚI: lấy history theo userId, endpoint động, không phân trang ===
  Future<List<HistoryMessage>> getHistoryChatByUserId(String id) async {
    final uri = Uri.parse('$baseUrl/history-chat-mobile'); //

    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "id": id, // uid lấy từ AuthController
      }),
    );

    if (resp.statusCode != 200) {
      // ném lỗi để controller hiển thị
      throw Exception('POST $uri -> ${resp.statusCode} ${resp.reasonPhrase}');
    }

    final body = resp.body;
    debugPrint(
      const JsonEncoder.withIndent('  ').convert(body),
      wrapWidth: 1024,
    );
    final json = jsonDecode(body);

    // Tuỳ backend: { data: [...] } hoặc trả thẳng array
    final list = (json is Map && json['data'] is List)
        ? (json['data'] as List)
        : (json as List);

    return list
        .whereType<Map<String, dynamic>>()
        .map(HistoryMessage.fromJson)
        .toList();
  }
}
