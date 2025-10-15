class AdminMessage {
  final String userName;
  final String botName;
  final String contentUser;
  final String contentBot;
  final double creditCost;
  final DateTime? createdAt;
  final String? models;

  const AdminMessage({
    required this.userName,
    required this.botName,
    required this.contentUser,
    required this.contentBot,
    required this.creditCost,
    this.createdAt,
    this.models,
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

    // Model (BE trả về 'models' hoặc đôi khi 'model'), có thể null/rỗng
    String? model;
    final rawModel = json['model'];
    final rawModels = json['models'];
    if (rawModel is String && rawModel.trim().isNotEmpty) {
      model = rawModel.trim();
    } else if (rawModels is String && rawModels.trim().isNotEmpty) {
      model = rawModels.trim();
    }

    return AdminMessage(
      userName: userName,
      botName: botName,
      contentUser: contentUser,
      contentBot: contentBot,
      creditCost: creditCost,
      createdAt: createdAt,
      models: model,
    );
  }
}
