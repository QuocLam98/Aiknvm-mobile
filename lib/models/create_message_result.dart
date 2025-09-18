class CreateMessageResult {
  final String contentBot;
  final DateTime? createdAt;
  final String? file;
  final int? status;
  final String id; // message _id
  final String history; // history id

  const CreateMessageResult({
    required this.contentBot,
    required this.id,
    required this.history,
    this.createdAt,
    this.file,
    this.status,
  });

  factory CreateMessageResult.fromJson(Map<String, dynamic> json) {
    final map = (json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : Map<String, dynamic>.from(json);
    return CreateMessageResult(
      contentBot: (map['contentBot'] ?? '').toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      file: (map['file'] ?? '').toString().isEmpty
          ? null
          : (map['file'] as String),
      status: map['status'] is int ? map['status'] as int : null,
      id: (map['_id'] ?? map['id'] ?? '').toString(),
      history: (map['history'] ?? '').toString(),
    );
  }
}
