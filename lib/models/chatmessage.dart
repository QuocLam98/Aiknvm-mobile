// sender enum
enum Sender { user, bot }

Sender senderFromString(String v) =>
    v == 'bot' ? Sender.bot : Sender.user;

String senderToString(Sender s) =>
    s == Sender.bot ? 'bot' : 'user';

class ChatMessageModel {
  final Sender sender;
  final String content;
  final DateTime createdAt;

  final String? fileUser;
  final int status;

  final bool? loading;          // map từ _loading?
  final String id;              // map từ _id
  final bool? isCopied;
  final String? displayContent;
  final bool isDone;
  final String? history;
  final String? fileType;
  final String? voice;

  const ChatMessageModel({
    required this.sender,
    required this.content,
    required this.createdAt,
    required this.status,
    required this.id,
    required this.isDone,
    this.fileUser,
    this.loading,
    this.isCopied,
    this.displayContent,
    this.history,
    this.fileType,
    this.voice,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel(
    sender: senderFromString(json['sender'] as String),
    content: json['content'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    fileUser: json['fileUser'] as String?,
    status: (json['status'] as num).toInt(),
    loading: json['_loading'] as bool?,     // dùng nội bộ
    id: json['_id'] as String,
    isCopied: json['isCopied'] as bool?,
    displayContent: json['displayContent'] as String?,
    isDone: (json['isDone'] as bool?) ?? false,
    history: json['history'] as String?,
    fileType: json['fileType'] as String?,
    voice: json['voice'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'sender': senderToString(sender),
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'fileUser': fileUser,
    'status': status,
    '_loading': loading,
    '_id': id,
    'isCopied': isCopied,
    'displayContent': displayContent,
    'isDone': isDone,
    'history': history,
    'fileType': fileType,
    'voice': voice,
  };

  ChatMessageModel copyWith({
    Sender? sender,
    String? content,
    DateTime? createdAt,
    String? fileUser,
    int? status,
    bool? loading,
    String? id,
    bool? isCopied,
    String? displayContent,
    bool? isDone,
    String? history,
    String? fileType,
    String? voice,
  }) =>
      ChatMessageModel(
        sender: sender ?? this.sender,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
        fileUser: fileUser ?? this.fileUser,
        status: status ?? this.status,
        loading: loading ?? this.loading,
        id: id ?? this.id,
        isCopied: isCopied ?? this.isCopied,
        displayContent: displayContent ?? this.displayContent,
        isDone: isDone ?? this.isDone,
        history: history ?? this.history,
        fileType: fileType ?? this.fileType,
        voice: voice ?? this.voice,
      );
}