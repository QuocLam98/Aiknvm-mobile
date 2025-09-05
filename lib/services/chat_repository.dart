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

    final root = jsonDecode(resp.body) as Map<String, dynamic>;
    if (root['status'] != 200) {
      throw Exception('API error: ${root['message']}');
    }

    final List<dynamic> list = root['data'] ?? const [];
    final messages = <ChatMessageModel>[];

    for (final raw in list) {
      final Map<String, dynamic> j = Map<String, dynamic>.from(raw as Map);

      final String baseId = (j['_id'] ?? j['id'] ?? '').toString();
      final String userText = (j['contentUser'] ?? '').toString();
      final String botText = (j['contentBot'] ?? '').toString();
      final String fileUrl = (j['fileUser'] ?? '').toString();
      final String fileType = (j['fileType'] ?? '').toString();
      final DateTime? createdAt = j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt'].toString())
          : null;

      // record -> (user message) + (bot message) nếu có nội dung
      if (userText.isNotEmpty || fileUrl.isNotEmpty) {
        messages.add(
          ChatMessageModel(
            id: '${baseId}_u',
            text: userText,
            role: 'user',
            createdAt: createdAt,
            fileUrl: fileUrl.isNotEmpty ? fileUrl : null,
            fileType: fileType.isNotEmpty ? fileType : null,
          ),
        );
      }
      if (botText.isNotEmpty) {
        messages.add(
          ChatMessageModel(
            id: '${baseId}_b',
            text: botText,
            role: 'bot', // hoặc 'assistant' tuỳ UI bạn check
            createdAt: createdAt,
          ),
        );
      }
    }

    // BE đang sort desc theo createdAt; danh sách đã theo thứ tự từ API
    // Nếu cần đảm bảo, có thể sort nhẹ:
    // messages.sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));

    return messages;
  }
}
