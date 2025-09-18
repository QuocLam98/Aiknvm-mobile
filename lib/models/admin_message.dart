class AdminMessage {
  final String userName;
  final String botName;
  final String contentUser;
  final String contentBot;
  final double creditCost;
  final DateTime? createdAt;

  const AdminMessage({
    required this.userName,
    required this.botName,
    required this.contentUser,
    required this.contentBot,
    required this.creditCost,
    this.createdAt,
  });

  factory AdminMessage.fromJson(Map<String, dynamic> json) {
    String userName = '';
    final user = json['user'];
    if (user is Map && user['name'] is String) {
      userName = user['name'] as String;
    } else if (json['userName'] is String) {
      userName = json['userName'] as String;
    }

    String botName = '';
    final bot = json['bot'];
    if (bot is Map && bot['name'] is String) {
      botName = bot['name'] as String;
    } else if (json['botName'] is String) {
      botName = json['botName'] as String;
    }

    final contentUser = (json['contentUser'] as String?) ?? '';
    final contentBot = (json['contentBot'] as String?) ?? '';
    double creditCost = 0;
    final cc = json['creditCost'];
    if (cc is num) {
      creditCost = cc.toDouble();
    } else if (cc is String) {
      creditCost = double.tryParse(cc) ?? 0;
    }

    DateTime? createdAt;
    final rawCreated = json['createdAt'];
    if (rawCreated is String) {
      createdAt = DateTime.tryParse(rawCreated);
    }

    return AdminMessage(
      userName: userName,
      botName: botName,
      contentUser: contentUser,
      contentBot: contentBot,
      creditCost: creditCost,
      createdAt: createdAt,
    );
  }
}
