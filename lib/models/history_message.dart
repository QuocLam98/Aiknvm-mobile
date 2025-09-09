import 'dart:convert';

class HistoryMessage {
  final String? id;
  final String? name;
  final String? bot; // botId (string)

  const HistoryMessage({this.id, this.name, this.bot});

  // ==== Helpers ====
  static final RegExp _reHex24 = RegExp(r'^[0-9a-fA-F]{24}$');
  // Dùng raw triple quotes để chứa cả ' và "
  static final RegExp _reShellId = RegExp(
    r'''ObjectId\((['"])([0-9a-fA-F]{24})\1\)''',
  );

  static String? _parseMongoId(Object? v) {
    if (v == null) return null;

    // 1) String: hex trực tiếp, ObjectId('...'), hoặc JSON/EJSON dạng chuỗi
    if (v is String) {
      final s = v.trim();

      final m = _reShellId.firstMatch(s);
      if (m != null) return m.group(2); // group(2) là 24-hex

      if (_reHex24.hasMatch(s)) return s;

      // Thử parse nếu đây là chuỗi JSON/EJSON
      try {
        final obj = jsonDecode(s);
        return _parseMongoId(obj); // đệ quy
      } catch (_) {
        // vét cạn: tìm 24-hex trong chuỗi
        final m2 = RegExp(r'([0-9a-fA-F]{24})').firstMatch(s);
        return m2?.group(1);
      }
    }

    // 2) Map: {$oid: "..."} | {_id: "..."} | {_id: {$oid: "..."} } | {id: "..."}
    if (v is Map) {
      final map = v; // giữ dynamic key để tránh lỗi cast

      final fromOid = _parseMongoId(map[r'$oid']);
      if (fromOid != null) return fromOid;

      final fromId = _parseMongoId(map['_id'] ?? map['id']);
      if (fromId != null) return fromId;

      return null;
    }

    // 3) Object khác: thử vét cạn bằng toString()
    try {
      final s = v.toString();
      final m = RegExp(r'([0-9a-fA-F]{24})').firstMatch(s);
      return m?.group(1);
    } catch (_) {
      return null;
    }
  }

  // ==== Factory ====
  factory HistoryMessage.fromJson(Map<String, dynamic> json) {
    final Object? rawId = json['id'] ?? json['_id'] ?? json['message'];
    final Object? rawBot = json['bot'] ?? json['botId'] ?? json['assistant'];
    final Object? rawName = json['name'] ?? json['sender'];

    return HistoryMessage(
      id: _parseMongoId(rawId) ?? rawId?.toString(),
      name: rawName?.toString(),
      bot: _parseMongoId(rawBot),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (name != null) 'name': name,
    if (bot != null) 'bot': bot,
  };
}
