import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymentRecord {
  final String id;
  final String email;
  final String amountRaw; // backend string amount
  final DateTime createdAt;
  PaymentRecord({
    required this.id,
    required this.email,
    required this.amountRaw,
    required this.createdAt,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    String? id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    final email = (json['email'] ?? '').toString();
    final amountAny = json['value'] ?? json['value'] ?? '';
    final amountRaw = amountAny.toString();
    DateTime created;
    final c = json['createdAt'];
    if (c is String) {
      created = DateTime.tryParse(c) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }
    return PaymentRecord(
      id: id,
      email: email,
      amountRaw: amountRaw,
      createdAt: created,
    );
  }
}

class PaymentListResult {
  final List<PaymentRecord> items;
  final int total;
  PaymentListResult(this.items, this.total);
}

class PaymentRepository {
  final String baseUrl;
  final http.Client _client;
  PaymentRepository({http.Client? client})
    : _client = client ?? http.Client(),
      baseUrl = dotenv.env['API_BASE_URL'] ?? '' {
    if (baseUrl.isEmpty) {
      throw StateError('Missing API_BASE_URL in .env');
    }
  }

  Future<PaymentListResult> listPayments({
    int page = 1,
    int limit = 10,
    String keyword = '',
  }) async {
    final uri = Uri.parse(
      '$baseUrl/list-payment?page=$page&limit=$limit&keyword=${Uri.encodeQueryComponent(keyword)}',
    );
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw Exception(
        'GET /list-payment -> ${resp.statusCode} ${resp.reasonPhrase}',
      );
    }
    final json = jsonDecode(resp.body);
    final data = (json is Map && json['data'] is List)
        ? json['data'] as List
        : (json as List);
    final total = (json is Map && json['total'] is num)
        ? (json['total'] as num).toInt()
        : data.length;
    final items = data
        .whereType<Map<String, dynamic>>()
        .map(PaymentRecord.fromJson)
        .toList();
    return PaymentListResult(items, total);
  }
}
