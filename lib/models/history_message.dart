class HistoryMessage {
  final String? id;
  final String? name;
  final Object? bot;

  HistoryMessage({this.id, this.name, this.bot});

  factory HistoryMessage.fromJson(Map<String, dynamic> json) {
    return HistoryMessage(
      // hỗ trợ nhiều khả năng id
      id: (json['id'] ?? json['_id'] ?? json['message'])?.toString(),
      // hỗ trợ nhiều khả năng tên
      name: (json['name'] ?? json['sender'])?.toString(),
      // giữ nguyên object bot nếu có; fallback thử vài key khác
      bot: json.containsKey('bot')
          ? json['bot']
          : (json['botId'] ?? json['assistant']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (bot != null) 'bot': bot, // giữ nguyên object
    };
  }
}
