// services/chat_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/create_message_result.dart';

import '../models/chat_message_model.dart';

class ChatRepository {
  final String baseUrl;
  final http.Client _client;

  ChatRepository(this.baseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  factory ChatRepository.fromEnv({http.Client? client}) {
    final base = dotenv.env['API_BASE_URL'] ?? '';
    if (base.isEmpty) throw StateError('Missing API_BASE_URL in .env');
    return ChatRepository(base, client: client);
  }

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

  Future<CreateMessageResult> createMessageMobile({
    required String userId,
    required String botId,
    required String content,
    String? file,
    String? fileType,
    String? historyChat,
  }) async {
    final uri = Uri.parse('$baseUrl/create-message-mobile');
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': userId,
        'bot': botId,
        'content': content,
        if (file != null) 'file': file,
        if (fileType != null) 'fileType': fileType,
        if (historyChat != null) 'historyChat': historyChat,
      }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'POST $uri failed: ${resp.statusCode} ${resp.reasonPhrase}: ${resp.body}',
      );
    }
    final decodedRaw = jsonDecode(resp.body);
    if (decodedRaw is Map<String, dynamic>) {
      // API may only return a message on error; detect lack of data fields
      final hasId =
          decodedRaw.containsKey('_id') || decodedRaw.containsKey('id');
      final hasHistory = decodedRaw.containsKey('history');
      final hasData = decodedRaw.containsKey('data');
      if (!hasId &&
          !hasHistory &&
          decodedRaw.containsKey('message') &&
          !hasData) {
        throw Exception(decodedRaw['message']?.toString() ?? 'API error');
      }
      return CreateMessageResult.fromJson(decodedRaw);
    }
    throw Exception('Unexpected response: ${resp.body}');
  }
}
