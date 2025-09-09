import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/bot_model.dart';

class BotRepository {
  final String baseUrl;
  final http.Client _client;

  BotRepository({http.Client? client})
    : _client = client ?? http.Client(),
      baseUrl = dotenv.env['API_BASE_URL'] ?? '' {
    if (baseUrl.isEmpty) {
      throw StateError('Missing API_BASE_URL in .env');
    }
  }

  /// GET /bots/{id}
  Future<BotModel> getBotById(String id) async {
    final uri = Uri.parse('$baseUrl/get-bot/$id'); // đổi path nếu BE khác

    final resp = await _client.get(uri);

    if (resp.statusCode != 200) {
      // ném lỗi để controller hiển thị
      throw Exception('GET $uri -> ${resp.statusCode} ${resp.reasonPhrase}');
    }

    final body = resp.body;
    final json = jsonDecode(body);

    // Tuỳ backend: { data: {...} } hoặc trả thẳng object
    final map = (json is Map && json['data'] is Map)
        ? (json['data'] as Map<String, dynamic>)
        : (json as Map<String, dynamic>);

    return BotModel.fromJson(map);
  }

  /// Lấy bot mặc định từ .env: DEFAULT_BOT
  Future<BotModel> getDefaultBot() async {
    final botId = dotenv.env['DEFAULT_BOT'] ?? '';
    if (botId.isEmpty) {
      throw StateError('Missing DEFAULT_BOT in .env');
    }
    return getBotById(botId);
  }

  Future<List<BotModel>> getAllBots() async {
    final uri = Uri.parse('$baseUrl/list-bot-chat'); // đổi path nếu BE khác

    final resp = await _client.get(uri);

    if (resp.statusCode != 200) {
      // ném lỗi để controller hiển thị
      throw Exception('GET $uri -> ${resp.statusCode} ${resp.reasonPhrase}');
    }

    final body = resp.body;
    final json = jsonDecode(body);

    // Tuỳ backend: { data: [...] } hoặc trả thẳng array
    final list = (json is Map && json['data'] is List)
        ? (json['data'] as List)
        : (json as List);

    return list
        .whereType<Map<String, dynamic>>()
        .map(BotModel.fromJson)
        .toList();
  }
}
