// lib/services/history_message_repository.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/history_message.dart';

class HistoryMessageRepository {
  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  HistoryMessageRepository(
    this.baseUrl, {
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  // === HÀM MỚI: lấy history theo userId, endpoint động, không phân trang ===
  Future<List<HistoryMessage>> fetchByUser({
    required String
    endpoint, // ví dụ: '/v1/history/{userId}' hoặc '/v1/history'
    required String userId,
    Map<String, String>? extraQuery,
  }) async {
    final uri = _buildUriWithUser(baseUrl, endpoint, userId, extraQuery);

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    http.Response resp;
    try {
      resp = await _client.get(uri, headers: headers).timeout(timeout);
    } on HandshakeException catch (e) {
      throw Exception('TLS handshake lỗi tới $uri.\n$e');
    } on SocketException catch (e) {
      throw Exception('Không kết nối được $uri. $e');
    } on TimeoutException {
      throw Exception('Request timeout sau ${timeout.inSeconds}s: $uri');
    }

    if (resp.statusCode != 200) {
      final preview = resp.body.length > 400
          ? '${resp.body.substring(0, 400)}…'
          : resp.body;
      throw Exception(
        'Lấy history thất bại: ${resp.statusCode} ${resp.reasonPhrase}\n$preview',
      );
    }

    dynamic root;
    try {
      root = jsonDecode(resp.body);
      if (kDebugMode) {
        debugPrint(
          const JsonEncoder.withIndent('  ').convert(root),
          wrapWidth: 1024,
        );
      }
    } catch (e) {
      throw Exception('Body không phải JSON hợp lệ: $e');
    }

    final list = _extractList(root);
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .map(HistoryMessage.fromJson)
        .toList(growable: false);
  }

  // === Giữ nguyên hàm fetchHistory của bạn (nếu muốn dùng chung) ===
  Future<List<HistoryMessage>> fetchHistory({
    required String endpoint, // truyền động
    int? page,
    int? limit,
    String? query,
    String? botId,
    Map<String, String>? extraQuery, // nếu cần thêm params tuỳ ý
  }) async {
    final params = <String, String>{
      if (page != null) 'page': '$page',
      if (limit != null) 'limit': '$limit',
      if (query != null && query.isNotEmpty) 'q': query,
      if (botId != null && botId.isNotEmpty) 'botId': botId,
      ...?extraQuery,
    };

    final uri = _resolveUri(baseUrl, endpoint, params);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    http.Response resp;
    try {
      resp = await _client.get(uri, headers: headers).timeout(timeout);
    } on HandshakeException catch (e) {
      throw Exception('TLS handshake lỗi tới $uri.\n$e');
    } on SocketException catch (e) {
      throw Exception('Không kết nối được $uri. $e');
    } on TimeoutException {
      throw Exception('Request timeout sau ${timeout.inSeconds}s: $uri');
    }

    if (resp.statusCode != 200) {
      final preview = resp.body.length > 400
          ? '${resp.body.substring(0, 400)}…'
          : resp.body;
      throw Exception(
        'Lấy history thất bại: ${resp.statusCode} ${resp.reasonPhrase}\n$preview',
      );
    }

    dynamic root;
    try {
      root = jsonDecode(resp.body);
      if (kDebugMode) {
        debugPrint(
          const JsonEncoder.withIndent('  ').convert(root),
          wrapWidth: 1024,
        );
      }
    } catch (e) {
      throw Exception('Body không phải JSON hợp lệ: $e');
    }

    final list = _extractList(root);
    return list
        .whereType<Map>() // chỉ nhận object
        .map((e) => e.cast<String, dynamic>())
        .map(HistoryMessage.fromJson)
        .toList(growable: false);
  }

  // --- Helpers ---
  Uri _resolveUri(String base, String endpoint, Map<String, String> params) {
    final isAbs =
        endpoint.startsWith('http://') || endpoint.startsWith('https://');
    final baseUri = Uri.parse(base.endsWith('/') ? base : '$base/');
    final resolved = isAbs
        ? Uri.parse(endpoint)
        : baseUri.resolve(
            endpoint.startsWith('/') ? endpoint.substring(1) : endpoint,
          );
    return resolved.replace(
      queryParameters: {...resolved.queryParameters, ...params},
    );
  }

  Uri _buildUriWithUser(
    String base,
    String endpoint,
    String userId,
    Map<String, String>? extraQuery,
  ) {
    final isAbs =
        endpoint.startsWith('http://') || endpoint.startsWith('https://');
    final baseUri = Uri.parse(base.endsWith('/') ? base : '$base/');
    String ep = endpoint;

    // Nếu endpoint có placeholder {userId} thì thay thế trong path
    if (ep.contains('{userId}')) {
      ep = ep.replaceAll('{userId}', Uri.encodeComponent(userId));
    }

    final resolved = isAbs
        ? Uri.parse(ep)
        : baseUri.resolve(ep.startsWith('/') ? ep.substring(1) : ep);

    // Nếu endpoint không chứa {userId} → thêm vào query ?userId=...
    final qp = Map<String, String>.from(resolved.queryParameters);
    if (!endpoint.contains('{userId}')) {
      qp['userId'] = userId;
    }
    if (extraQuery != null) qp.addAll(extraQuery);

    return resolved.replace(queryParameters: qp);
  }

  List<dynamic> _extractList(dynamic root) {
    if (root is List) return root;

    if (root is Map<String, dynamic>) {
      for (final k in const [
        'data',
        'items',
        'results',
        'messages',
        'records',
        'list',
      ]) {
        final v = root[k];
        if (v is List) return v;
      }
      final data = root['data'];
      if (data is Map<String, dynamic>) {
        for (final k in const [
          'items',
          'results',
          'messages',
          'records',
          'list',
        ]) {
          final v = data[k];
          if (v is List) return v;
        }
      }
    }
    return const <dynamic>[];
  }

  void dispose() => _client.close();
}
