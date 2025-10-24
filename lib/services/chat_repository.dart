// services/chat_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';
import '../models/create_message_result.dart';

import '../models/chat_message_model.dart';
import 'dart:io';

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
    final safeLimit = limit.clamp(1, 50);
    final safePage = page < 1 ? 1 : page;
    final uri = Uri.parse(
      '$baseUrl/list-message-mobile?page=$safePage&limit=$safeLimit&id=$historyId',
    );
    final resp = await _client.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );
    if (resp.statusCode != 200) {
      throw Exception(
        'GET $uri -> ${resp.statusCode} ${resp.reasonPhrase}: ${resp.body}',
      );
    }

    dynamic root;
    try {
      root = jsonDecode(resp.body);
    } catch (e) {
      throw Exception('Parse error body: ${resp.body}');
    }

    // Accept flexible status indicator
    if (root is Map<String, dynamic>) {
      final status = root['status'];
      if (status is int && status >= 400) {
        throw Exception('API error status=$status message=${root['message']}');
      }
      if (status is String) {
        final lower = status.toLowerCase();
        if (lower.contains('error') || lower.contains('fail')) {
          throw Exception(
            'API error status=$status message=${root['message']}',
          );
        }
      }
    }

    // Unwrap nested data maps until we reach a list or give up
    List<dynamic>? dataList;
    dynamic cursor = root;
    int depth = 0;
    while (depth < 4 && dataList == null && cursor is Map) {
      final m = cursor;
      // candidate keys in preference order
      for (final k in ['data', 'items', 'messages', 'list', 'records']) {
        final v = m[k];
        if (v is List) {
          dataList = v;
          break;
        }
        if (v is Map) {
          cursor = v;
          depth++;
          continue;
        }
      }
      if (dataList == null) break; // none found
    }
    if (dataList == null) {
      if (root is List) {
        dataList = root;
      } else {
        dataList = const []; // empty gracefully
      }
    }

    final messages = <ChatMessageModel>[];
    for (final raw in dataList) {
      if (raw is Map) {
        final expanded = ChatMessageModel.expandFromServer(
          Map<String, dynamic>.from(raw),
        );
        messages.addAll(expanded);
      }
    }
    return messages;
  }

  Future<CreateMessageResult> createMessageMobile({
    required String userId,
    required String botId,
    required String content,
    String? file,
    String? fileType,
    String? historyChat,
    String? model,
  }) async {
    // Backward-compatible: route by model if provided, else default to GPT
    final m = (model ?? '').trim();
    if (m.startsWith('gemini')) {
      return createMessageMobileGemini(
        userId: userId,
        botId: botId,
        content: content,
        file: file,
        fileType: fileType,
        historyChat: historyChat,
        model: model,
      );
    }
    return createMessageMobileGpt(
      userId: userId,
      botId: botId,
      content: content,
      file: file,
      fileType: fileType,
      historyChat: historyChat,
      model: model,
    );
  }

  Future<CreateMessageResult> createMessageMobileGpt({
    required String userId,
    required String botId,
    required String content,
    String? file,
    String? fileType,
    String? historyChat,
    String? model,
  }) async {
    final uri = Uri.parse('$baseUrl/create-message-mobile');
    final bodyMap = <String, dynamic>{
      'id': userId,
      'bot': botId,
      'content': content,
    };
    if (file != null && file.isNotEmpty) bodyMap['file'] = file;
    if (fileType != null && fileType.isNotEmpty) bodyMap['fileType'] = fileType;
    if (historyChat != null && historyChat.isNotEmpty) {
      bodyMap['historyChat'] = historyChat;
    }
    if (model != null && model.isNotEmpty) bodyMap['model'] = model;
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyMap),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'POST $uri failed: ${resp.statusCode} ${resp.reasonPhrase}: ${resp.body}',
      );
    }
    final decodedRaw = jsonDecode(resp.body);
    if (decodedRaw is Map<String, dynamic>) {
      return CreateMessageResult.fromJson(decodedRaw);
    }
    throw Exception('Unexpected response: ${resp.body}');
  }

  Future<CreateMessageResult> createMessageMobileGemini({
    required String userId,
    required String botId,
    required String content,
    String? file,
    String? fileType,
    String? historyChat,
    String? model,
  }) async {
    final uri = Uri.parse('$baseUrl/create-message-mobile-gemini');
    final bodyMap = <String, dynamic>{
      'id': userId,
      'bot': botId,
      'content': content,
    };
    if (file != null && file.isNotEmpty) bodyMap['file'] = file;
    if (fileType != null && fileType.isNotEmpty) bodyMap['fileType'] = fileType;
    if (historyChat != null && historyChat.isNotEmpty) {
      bodyMap['historyChat'] = historyChat;
    }
    if (model != null && model.isNotEmpty) bodyMap['model'] = model;
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyMap),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'POST $uri failed: ${resp.statusCode} ${resp.reasonPhrase}: ${resp.body}',
      );
    }
    final decodedRaw = jsonDecode(resp.body);
    if (decodedRaw is Map<String, dynamic>) {
      return CreateMessageResult.fromJson(decodedRaw);
    }
    throw Exception('Unexpected response: ${resp.body}');
  }

  /// Create an image chat message (image generated by bot) via
  /// POST /create-message-image-mobile
  /// Body: { id, bot, content, (optional) historyChat }
  /// Response (success or credit exhausted) returns a flat JSON object containing
  /// at least: _id, history, contentBot, createdAt, (optional) status, (optional) file
  Future<CreateMessageResult> createMessageImageMobile({
    required String userId,
    required String botId,
    required String content,
    String? historyChat,
  }) async {
    final uri = Uri.parse('$baseUrl/create-message-image-mobile');
    final bodyMap = <String, dynamic>{
      'id': userId,
      'bot': botId,
      'content': content,
    };
    if (historyChat != null && historyChat.isNotEmpty) {
      bodyMap['historyChat'] = historyChat;
    }

    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyMap),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'POST $uri failed: ${resp.statusCode} ${resp.reasonPhrase}: ${resp.body}',
      );
    }
    final decodedRaw = jsonDecode(resp.body);
    if (decodedRaw is Map<String, dynamic>) {
      // Endpoint returns a flat map (no mandatory data wrapper) so reuse CreateMessageResult
      return CreateMessageResult.fromJson(decodedRaw);
    }
    throw Exception('Unexpected response: ${resp.body}');
  }

  /// Create a premium image chat message. Supports optional image file upload (edit mode).
  /// Endpoint: POST /create-message-image-pre-mobile
  /// If [file] provided uses multipart/form-data, else JSON body.
  Future<CreateMessageResult> createMessageImagePremium({
    required String userId,
    required String botId,
    required String content,
    String? historyChat,
    File? file,
  }) async {
    final uri = Uri.parse('$baseUrl/create-message-image-pre-gemini-mobile');
    if (file != null) {
      final req = http.MultipartRequest('POST', uri);
      req.fields['id'] = userId;
      req.fields['bot'] = botId;
      req.fields['content'] = content;
      if (historyChat != null && historyChat.isNotEmpty) {
        req.fields['historyChat'] = historyChat;
      }
      final mime = _inferMime(file.path);
      req.files.add(
        await http.MultipartFile.fromPath('file', file.path, contentType: mime),
      );
      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception(
          'POST $uri failed: ${resp.statusCode} ${resp.reasonPhrase}: ${resp.body}',
        );
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        return CreateMessageResult.fromJson(decoded);
      }
      throw Exception('Unexpected response: ${resp.body}');
    } else {
      // JSON fallback when not uploading a file
      final bodyMap = <String, dynamic>{
        'id': userId,
        'bot': botId,
        'content': content,
      };
      if (historyChat != null && historyChat.isNotEmpty) {
        bodyMap['historyChat'] = historyChat;
      }
      final resp = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyMap),
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception(
          'POST $uri failed: ${resp.statusCode} ${resp.reasonPhrase}: ${resp.body}',
        );
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        return CreateMessageResult.fromJson(decoded);
      }
      throw Exception('Unexpected response: ${resp.body}');
    }
  }

  Future<String> uploadChatFile(File file) async {
    final uri = Uri.parse('$baseUrl/upload-file-chat');
    final req = http.MultipartRequest('POST', uri);
    final mimeType = _inferMime(file.path);
    req.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: mimeType,
      ),
    );
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Upload failed ${resp.statusCode}: ${resp.body}');
    }
    final raw = resp.body.trim();
    // Case 1: backend already returns a bare URL (no JSON)
    if ((raw.startsWith('http://') || raw.startsWith('https://')) &&
        !raw.startsWith('{') &&
        !raw.startsWith('[')) {
      return raw;
    }
    // Try JSON decode
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      // Fallback: treat as URL if it looks like one
      if (raw.contains('://')) return raw;
      throw Exception('Upload response parse error: $raw');
    }
    if (decoded is String) {
      // JSON string value (e.g. "https://...")
      if (decoded.startsWith('http://') || decoded.startsWith('https://')) {
        return decoded;
      }
      throw Exception('Unexpected upload string: $decoded');
    }
    if (decoded is Map) {
      // Common patterns: {url: ...} or {data: {url: ...}} or nested message
      if (decoded['url'] != null) return decoded['url'].toString();
      final data = decoded['data'];
      if (data is Map && data['url'] != null) return data['url'].toString();
      // Some APIs return {status:200, data:"https://..."}
      if (data is String &&
          (data.startsWith('http://') || data.startsWith('https://'))) {
        return data;
      }
      // Last resort: search for first http substring
      final match = RegExp(r'https?://[^"\s]+').firstMatch(raw);
      if (match != null) return match.group(0)!;
      throw Exception('Upload response missing URL: $raw');
    }
    throw Exception('Unhandled upload response shape: $raw');
  }

  // Update a message with a history id after it is created.
  Future<void> updateMessageHistory({
    required String messageId,
    required String historyId,
  }) async {
    if (historyId.isEmpty) return; // nothing to do
    final uri = Uri.parse('$baseUrl/update-message-history');
    final resp = await _client.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': messageId, 'history': historyId}),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'PUT $uri failed: ${resp.statusCode} ${resp.reasonPhrase}: ${resp.body}',
      );
    }
  }

  // Update message status: 1 = like, 2 = dislike
  Future<void> updateMessageStatus({
    required String messageId,
    required int status,
  }) async {
    final uri = Uri.parse('$baseUrl/update-message');
    final resp = await _client.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': messageId, 'status': status}),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'PUT $uri failed: ${resp.statusCode} ${resp.reasonPhrase}: ${resp.body}',
      );
    }
  }

  static MediaType _inferMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))
      return MediaType('image', 'jpeg');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    if (lower.endsWith('.docx'))
      return MediaType(
        'application',
        'vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    if (lower.endsWith('.txt')) return MediaType('text', 'plain');
    return MediaType('application', 'octet-stream');
  }
}
