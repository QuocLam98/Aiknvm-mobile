class ChatMessageModel {
  final String id;
  final String text;
  final String role; // "user" | "bot"
  final DateTime? createdAt;
  final String? fileUrl; // URL tệp đính kèm (user)
  final String? fileType; // loại tệp từ server (image/pdf/docx/txt/...)
  final String? botId; // id của bot liên quan (dùng trong history)
  final int? status; // 1 = like, 2 = dislike (áp dụng cho bot message)

  ChatMessageModel({
    required this.id,
    required this.text,
    required this.role,
    this.createdAt,
    this.fileUrl,
    this.fileType,
    this.botId,
    this.status,
  });

  /// Lấy "id gốc" của 1 record (bỏ hậu tố _u/_b)
  String get baseId {
    if (id.endsWith('_u') || id.endsWith('_b')) {
      return id.substring(0, id.length - 2);
    }
    return id;
  }

  /// NẾU cần một factory “đơn” (ít dùng)
  factory ChatMessageModel.fromServerJson(Map<String, dynamic> j) {
    final id = (j['_id'] ?? '').toString();
    final createdAt = j['createdAt'] != null
        ? DateTime.tryParse(j['createdAt'])
        : null;

    // Trả về 1 bản bot; KHÔNG dùng trực tiếp để render.
    return ChatMessageModel(
      id: "${id}_b",
      text: j['contentBot'] ?? '',
      role: 'bot',
      createdAt: createdAt,
    );
  }

  /// CHUẨN: Convert 1 record server -> 0..2 messages (user + bot)
  static List<ChatMessageModel> expandFromServer(Map<String, dynamic> j) {
    final id = (j['_id'] ?? '').toString();
    final createdAt = j['createdAt'] != null
        ? DateTime.tryParse(j['createdAt'])
        : null;
    final botId = (j['bot'] ?? j['botId'] ?? '').toString().trim().isEmpty
        ? null
        : (j['bot'] ?? j['botId']).toString();
    final statusRaw = j['status'];
    int? status;
    if (statusRaw is int && (statusRaw == 1 || statusRaw == 2)) {
      status = statusRaw;
    } else if (statusRaw is String) {
      final parsed = int.tryParse(statusRaw);
      if (parsed != null && (parsed == 1 || parsed == 2)) status = parsed;
    }

    // Potential file fields for user/bot
    final fileUser = (j['fileUser'] ?? '').toString();
    final fileBotRaw = (j['fileBot'] ?? j['file'] ?? '').toString();
    String? botFileUrl;
    String botText = (j['contentBot'] ?? '').toString();
    // If bot text empty but we have a URL-like file value, treat it as image URL
    final looksLikeUrl = (String s) =>
        s.startsWith('http://') || s.startsWith('https://');
    if (botText.trim().isEmpty && looksLikeUrl(fileBotRaw)) {
      botFileUrl = fileBotRaw;
      botText = ''; // ensure blank
    } else if (botText.trim().isNotEmpty &&
        looksLikeUrl(botText) &&
        (j['fileBot'] == null && j['file'] == null)) {
      // Server sometimes returns image URL inside contentBot directly
      botFileUrl = botText;
      botText = '';
    }

    final userMsg = ChatMessageModel(
      id: "${id}_u",
      text: j['contentUser'] ?? '',
      role: 'user',
      createdAt: createdAt,
      fileUrl: fileUser.isNotEmpty ? fileUser : null,
      fileType: (j['fileType'] ?? '')?.toString(),
      botId: botId,
    );
    final botMsg = ChatMessageModel(
      id: "${id}_b",
      text: botText,
      role: 'bot',
      createdAt: createdAt,
      fileUrl: botFileUrl,
      botId: botId,
      status: status,
    );

    return [
      if (userMsg.text.isNotEmpty) userMsg,
      // Accept bot message if it has either text OR an image fileUrl
      if (botMsg.text.isNotEmpty ||
          (botMsg.fileUrl != null && botMsg.fileUrl!.isNotEmpty))
        botMsg,
    ];
  }
}
