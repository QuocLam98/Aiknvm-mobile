class BotModel {
  final String id;
  final String name;
  final String description;
  final String template;
  final String? image;
  final int status;

  const BotModel({
    required this.id,
    required this.name,
    required this.description,
    required this.template,
    required this.status,
    this.image,
  });

  factory BotModel.fromJson(Map<String, dynamic> json) => BotModel(
    id: json['_id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    template: json['template'] as String? ?? '',
    image: json['image'] as String?,
    status: (json['status'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'description': description,
    'template': template,
    'image': image,
    'status': status,
  };

  BotModel copyWith({
    String? id,
    String? name,
    String? description,
    String? template,
    String? image,
    int? status,
  }) =>
      BotModel(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        template: template ?? this.template,
        image: image ?? this.image,
        status: status ?? this.status,
      );
}