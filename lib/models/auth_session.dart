class AuthSession {
  final String jwt; // token hệ thống của bạn (tạm dùng idToken demo)
  final DateTime expiresAt;


  const AuthSession({required this.jwt, required this.expiresAt});


  Map<String, dynamic> toJson() => {
    'jwt': jwt,
    'exp': expiresAt.millisecondsSinceEpoch,
  };


  static AuthSession fromJson(Map<String, dynamic> json) => AuthSession(
    jwt: json['jwt'] as String,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(json['exp'] as int),
  );
}