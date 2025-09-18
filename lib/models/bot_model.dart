class BotModel {
  final String id;
  final String name;
  final String description;
  final String template;
  final String? image;
  final int status;
  final DateTime? createdAt;

  const BotModel({
    required this.id,
    required this.name,
    required this.description,
    required this.template,
    required this.status,
    this.image,
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
    return BotModel(
      id: json['_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      template: tmpl,
      image: json['image'] as String?,
      status: (json['status'] as num).toInt(),
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
    'createdAt': createdAt?.toIso8601String(),
  };

  BotModel copyWith({
    String? id,
    String? name,
    String? description,
    String? template,
    String? image,
    int? status,
    DateTime? createdAt,
  }) => BotModel(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    template: template ?? this.template,
    image: image ?? this.image,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
}
