import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bot.dart';

class ApiClient {
  final String baseUrl;
  final Duration timeout;
  ApiClient({
    this.baseUrl = 'https://server.aiknvm.vn',
    this.timeout = const Duration(seconds: 15),
  });

  // Điều chỉnh path đúng endpoint BE của bạn (ví dụ: /list-bot hoặc /api/list-bot)
  Future<List<Bot>> getBots({String path = '/list-bot'}) async {
    final uri = Uri.parse('$baseUrl$path');

    final resp = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(timeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Get bots failed: HTTP ${resp.statusCode}');
    }

    final body = json.decode(resp.body);

    // Hỗ trợ nhiều dạng bao gói payload
    final dynamic raw =
    (body is Map && body['data'] is List) ? body['data']
        : (body is Map && body['bots'] is List) ? body['bots']
        : (body is List) ? body
        : [];

    final list = (raw as List)
        .whereType<Map<String, dynamic>>()
        .map(Bot.fromJson)
        .toList();

    // Lọc chỉ bot active + status == 1 và sort theo updatedAt (mới nhất trước)
    list.retainWhere((b) => b.active && b.status == 1);
    list.sort((a, b) {
      final at = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });

    return list;
  }
}
