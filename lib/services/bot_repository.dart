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

  Future<BotModel> createBot({
    required String name,
    required String templateMessage,
    String? description,
    int? status, // 0=Hoạt động, 1=Bảo trì
    List<int>? imageBytes,
    String? imageFilename,
  }) async {
    final uri = Uri.parse('$baseUrl/registerBot');
    final req = http.MultipartRequest('POST', uri);
    req.fields['name'] = name;
    req.fields['templateMessage'] = templateMessage;
    if (description != null && description.isNotEmpty) {
      req.fields['description'] = description;
    }
    if (status != null) {
      req.fields['status'] = status.toString();
    }
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final filename =
          imageFilename ??
          'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
      req.files.add(
        http.MultipartFile.fromBytes('image', imageBytes, filename: filename),
      );
    }

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) {
      throw Exception(
        'POST $uri -> ${resp.statusCode} ${resp.reasonPhrase}: ${resp.body}',
      );
    }
    final body = resp.body;
    final json = jsonDecode(body);
    final map = (json is Map && json['data'] is Map)
        ? (json['data'] as Map<String, dynamic>)
        : (json as Map<String, dynamic>);
    return BotModel.fromJson(map);
  }

  Future<BotModel> updateBot({
    required String id,
    String? name,
    String? templateMessage,
    String? description,
    int? status, // 0=Hoạt động, 1=Bảo trì
    List<int>? imageBytes,
    String? imageFilename,
  }) async {
    final uri = Uri.parse('$baseUrl/update-bot/$id');
    final req = http.MultipartRequest('PUT', uri);
    if (name != null) req.fields['name'] = name;
    if (templateMessage != null)
      req.fields['templateMessage'] = templateMessage;
    if (description != null) req.fields['description'] = description;
    if (status != null) req.fields['status'] = status.toString();
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final filename =
          imageFilename ??
          'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
      req.files.add(
        http.MultipartFile.fromBytes('image', imageBytes, filename: filename),
      );
    }

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) {
      throw Exception(
        'PUT $uri -> ${resp.statusCode} ${resp.reasonPhrase}: ${resp.body}',
      );
    }
    final json = jsonDecode(resp.body);
    final map = (json is Map && json['data'] is Map)
        ? (json['data'] as Map<String, dynamic>)
        : (json as Map<String, dynamic>);
    return BotModel.fromJson(map);
  }

  Future<void> deleteBot(String id) async {
    final uri = Uri.parse('$baseUrl/delete-bot/$id');
    final resp = await _client.put(uri);
    if (resp.statusCode != 200) {
      throw Exception(
        'PUT $uri -> ${resp.statusCode} ${resp.reasonPhrase}: ${resp.body}',
      );
    }
  }
}
