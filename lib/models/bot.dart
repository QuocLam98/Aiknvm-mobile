class Bot {
  final String name;
  final String description;
  final String templateMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool active;
  final String? image;     // URL ảnh
  final int status;

  const Bot({
    required this.name,
    required this.description,
    required this.templateMessage,
    required this.createdAt,
    required this.updatedAt,
    required this.active,
    required this.image,
    required this.status,
  });

  factory Bot.fromJson(Map<String, dynamic> j) {
    DateTime? _parseDate(dynamic v) {
      if (v == null) return null;
      try { return DateTime.parse(v.toString()); } catch (_) { return null; }
    }

    return Bot(
      name: (j['name'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      templateMessage: (j['templateMessage'] ?? '').toString(),
      createdAt: _parseDate(j['createdAt']),
      updatedAt: _parseDate(j['updatedAt']),
      active: j['active'] == true || j['active'] == 1 || j['active'] == 'true',
      image: (j['image'] as String?)?.trim().isEmpty == true ? null : j['image']?.toString(),
      status: int.tryParse('${j['status'] ?? 0}') ?? 0,
    );
  }
}
