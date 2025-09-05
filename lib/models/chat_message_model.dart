class ChatMessageModel {
  final String id;
  final String text;
  final String role; // "user" | "bot"
  final DateTime? createdAt;
  final String? fileUrl; // URL tệp đính kèm (user)
  final String? fileType; // loại tệp từ server (image/pdf/docx/txt/...)

  ChatMessageModel({
    required this.id,
    required this.text,
    required this.role,
    this.createdAt,
    this.fileUrl,
    this.fileType,
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

    final userMsg = ChatMessageModel(
      id: "${id}_u",
      text: j['contentUser'] ?? '',
      role: 'user',
      createdAt: createdAt,
      fileUrl: (j['fileUser'] ?? '')?.toString(),
      fileType: (j['fileType'] ?? '')?.toString(),
    );
    final botMsg = ChatMessageModel(
      id: "${id}_b",
      text: j['contentBot'] ?? '',
      role: 'bot',
      createdAt: createdAt,
    );

    return [
      if (userMsg.text.isNotEmpty) userMsg,
      if (botMsg.text.isNotEmpty) botMsg,
    ];
  }
}
