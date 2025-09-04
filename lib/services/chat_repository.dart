// services/chat_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/chat_message_model.dart';

class ChatRepository {
  final String baseUrl;
  final http.Client _client;

  ChatRepository(this.baseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  Future<List<ChatMessageModel>> loadChatByHistoryId(
    String historyId, {
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/list-message-mobile?page=$page&limit=$limit&id=$historyId',
    );

    final resp = await _client.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    if (resp.statusCode != 200) {
      throw Exception(
        'GET $uri failed: ${resp.statusCode} ${resp.reasonPhrase}',
      );
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    if (json['status'] != 200) {
      throw Exception('API error: ${json['message']}');
    }

    final List<dynamic> list = json['data'] ?? [];
    return list.map((e) => ChatMessageModel.fromJson(e)).toList();
  }
}
