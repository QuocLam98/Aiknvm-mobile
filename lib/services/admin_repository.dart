import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/admin_user.dart';

class PagedResult<T> {
  final List<T> items;
  final int total;
  const PagedResult(this.items, this.total);
}

class AdminRepository {
  final String baseUrl;
  final http.Client _client;
  AdminRepository({http.Client? client})
    : _client = client ?? http.Client(),
      baseUrl = dotenv.env['API_BASE_URL'] ?? '' {
    if (baseUrl.isEmpty) {
      throw StateError('Missing API_BASE_URL in .env');
    }
  }

  Future<PagedResult<AdminUser>> listUsers({
    int page = 1,
    int limit = 10,
    String keyword = '',
  }) async {
    final uri = Uri.parse('$baseUrl/list-user').replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        if (keyword.isNotEmpty) 'keyword': keyword,
      },
    );

    final resp = await _client.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode != 200) {
      throw Exception('GET $uri -> ${resp.statusCode} ${resp.reasonPhrase}');
    }

    final root = jsonDecode(resp.body);
    List<dynamic> listDyn;
    int total = 0;
    if (root is Map && root['data'] is Map) {
      final data = root['data'] as Map;
      if (data['items'] is List) {
        listDyn = data['items'] as List;
        total = _extractTotal(data) ?? _extractTotal(root) ?? _extractHeaderTotal(resp.headers) ?? listDyn.length;
      } else if (data['list'] is List) {
        listDyn = data['list'] as List;
        total = _extractTotal(data) ?? _extractTotal(root) ?? _extractHeaderTotal(resp.headers) ?? listDyn.length;
      } else if (data['users'] is List) {
        listDyn = data['users'] as List;
        total = _extractTotal(data) ?? _extractTotal(root) ?? _extractHeaderTotal(resp.headers) ?? listDyn.length;
      } else {
        listDyn = [];
      }
    } else if (root is Map && root['data'] is List) {
      listDyn = root['data'] as List;
      total = _extractTotal(root) ?? _extractHeaderTotal(resp.headers) ?? listDyn.length;
    } else if (root is List) {
      listDyn = root;
      total = listDyn.length;
    } else {
      listDyn = [];
    }

    final items = listDyn
        .whereType<Map>()
        .map((e) => AdminUser.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return PagedResult(items, total);
  }
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) {
    final n = int.tryParse(v);
    return n;
  }
  return null;
}

int? _extractTotal(Map m) {
  // try common keys at current level
  for (final k in const ['total', 'count', 'totalCount', 'total_records', 'totalRecords', 'totalItems']) {
    final t = _asInt(m[k]);
    if (t != null) return t;
  }
  // try nested containers
  for (final nest in const ['meta', 'pagination', 'pageInfo']) {
    final v = m[nest];
    if (v is Map) {
      final t = _extractTotal(Map<String, dynamic>.from(v));
      if (t != null) return t;
    }
  }
  return null;
}

int? _extractHeaderTotal(Map<String, String> headers) {
  String? val;
  for (final e in headers.entries) {
    final k = e.key.toLowerCase();
    if (k == 'x-total-count' || k == 'x-total' || k == 'x-total-records') {
      val = e.value;
      break;
    }
  }
  return _asInt(val);
}
