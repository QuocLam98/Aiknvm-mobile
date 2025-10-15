class BotModel {
  final String id;
  final String name;
  final String description;
  final String template;
  final String? image;
  final int status;
  final int? priority; // độ ưu tiên hiển thị trong Drawer (cao trước)
  final int? models; // 1=Gemini, 2=GPT, 3=Gemini+GPT
  final DateTime? createdAt;

  const BotModel({
    required this.id,
    required this.name,
    required this.description,
    required this.template,
    required this.status,
    this.image,
    this.priority,
    this.models,
    this.createdAt,
  });

  factory BotModel.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final rawCreated = json['createdAt'];
    if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated);
    }
    final tmpl =
        (json['templateMessage'] as String?) ??
        (json['template'] as String?) ??
        '';
    final prioRaw = json['priority'] ?? json['pri'];
    int? prio;
    if (prioRaw is num) prio = prioRaw.toInt();
    if (prio == null && prioRaw is String) {
      prio = int.tryParse(prioRaw);
    }
    final modelsRaw = json['models'] ?? json['model'];
    int? models;
    if (modelsRaw is num) models = modelsRaw.toInt();
    if (models == null && modelsRaw is String) {
      models = int.tryParse(modelsRaw);
    }
    return BotModel(
      id: json['_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      template: tmpl,
      image: json['image'] as String?,
      status: (json['status'] as num).toInt(),
      priority: prio,
      models: models,
      createdAt: created,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'description': description,
    'templateMessage': template,
    // keep legacy key for compatibility if needed
    'template': template,
    'image': image,
    'status': status,
    // BE nhận string cho priority/models
    if (priority != null) 'priority': priority.toString(),
    if (models != null) 'models': models.toString(),
    'createdAt': createdAt?.toIso8601String(),
  };

  BotModel copyWith({
    String? id,
    String? name,
    String? description,
    String? template,
    String? image,
    int? status,
    int? priority,
    int? models,
    DateTime? createdAt,
  }) => BotModel(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    template: template ?? this.template,
    image: image ?? this.image,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    models: models ?? this.models,
    createdAt: createdAt ?? this.createdAt,
  );
}
