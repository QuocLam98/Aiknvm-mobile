import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/auth_session.dart';

class AuthRepository {
  static const _kJwt = 'auth.jwt';
  static const _kExp = 'auth.exp';

  static SharedPreferences? _prefs;
  static SharedPreferences get _sp =>
      _prefs ?? (throw StateError('Call AuthRepository.init() before use'));

  final String baseUrl;
  final http.Client _client;
  final GoogleSignIn _google = GoogleSignIn.instance;

  AuthRepository({http.Client? client, String? baseUrlOverride})
    : _client = client ?? http.Client(),
      baseUrl =
          (baseUrlOverride ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue: '',
                  ))
              .trim();

  /// Gọi đúng một lần ở app start
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();

    final webClientId = const String.fromEnvironment(
      'GOOGLE_ANDROID_CLIENT_ID',
      defaultValue: '',
    ).trim();

    if (webClientId.isEmpty) {
      throw StateError(
        'Missing GOOGLE_WEB_CLIENT_ID (pass via --dart-define or --dart-define-from-file).',
      );
    }

    debugPrint('GoogleSignIn.initialize id=${webClientId.substring(0, 12)}…');

    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? webClientId : null, // Web
      serverClientId: kIsWeb ? null : webClientId, // Android/iOS
    );
  }

  Future<bool> get hasValidSession async {
    final jwt = _sp.getString(_kJwt);
    final exp = _sp.getInt(_kExp);
    if (jwt == null || exp == null) return false;
    return DateTime.now().isBefore(
      DateTime.fromMillisecondsSinceEpoch(exp, isUtc: false),
    );
  }

  AuthSession? getCurrentSession() {
    final jwt = _sp.getString(_kJwt);
    final exp = _sp.getInt(_kExp);
    if (jwt == null || exp == null) return null;
    final expires = DateTime.fromMillisecondsSinceEpoch(exp, isUtc: false);
    if (DateTime.now().isAfter(expires)) return null;
    return AuthSession(jwt: jwt, expiresAt: expires);
  }

  Future<void> persistSession(AuthSession s) async {
    await _sp.setString(_kJwt, s.jwt);
    await _sp.setInt(_kExp, s.expiresAt.millisecondsSinceEpoch);
  }

  /// Đăng nhập Google (mobile v7), gửi idToken lên /auth/google/mobile
  Future<(AppUser, AuthSession)> signInWithGoogle() async {
    final gs = GoogleSignIn.instance;

    // Dọn trạng thái trước khi auth (tránh kẹt cache)
    try {
      await gs.signOut();
    } catch (_) {}
    try {
      await gs.attemptLightweightAuthentication();
    } catch (_) {}

    // v7: authenticate()
    final acc = await gs.authenticate();
    if (acc == null) {
      throw Exception('Người dùng đã hủy đăng nhập Google');
    }

    // ❌ KHÔNG gọi acc.authentication nữa (tránh lỗi 16)
    // ✅ Xin server auth code qua Authorization API (v7)
    const scopes = <String>['openid', 'email', 'profile'];
    final serverAuth = await acc.authorizationClient.authorizeServer(scopes);
    final code = serverAuth?.serverAuthCode;

    if (code == null || code.isEmpty) {
      throw Exception(
        'Không lấy được serverAuthCode (mã 16). Kiểm tra cấu hình OAuth/keystore như checklist bên dưới.',
      );
    }

    // Gọi API mobile: backend sẽ đổi token với redirect_uri="postmessage"
    final uri = Uri.parse('$baseUrl/auth/google/mobile');
    final resp = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'code': code}),
        )
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode != 200) {
      final preview = resp.body.length > 400
          ? '${resp.body.substring(0, 400)}…'
          : resp.body;
      throw Exception(
        'Đăng nhập thất bại: ${resp.statusCode} ${resp.reasonPhrase}\n$preview',
      );
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final jwt = (data['token'] ?? data['jwt'] ?? '') as String;
    if (jwt.isEmpty) throw Exception('Phản hồi backend không có token');

    final Map<String, dynamic> userJson = (data['user'] is Map)
        ? (data['user'] as Map).cast<String, dynamic>()
        : const {};
    final String userId = (data['id'] ?? userJson['id'] ?? '') as String;
    final String userEmail =
        (data['email'] ?? userJson['email'] ?? acc.email ?? '') as String;
    final String userRole =
        (data['role'] ?? userJson['role'] ?? 'user') as String;

    final expiresAt =
        _extractExpFromJwt(jwt) ?? DateTime.now().add(const Duration(hours: 6));

    final user = AppUser(
      id: userId,
      email: userEmail,
      name: acc.displayName ?? '',
      avatarUrl: acc.photoUrl,
      role: userRole,
    );

    final session = AuthSession(jwt: jwt, expiresAt: expiresAt);
    await persistSession(session);
    return (user, session);
  }

  Future<void> logout() async {
    try {
      await _google.signOut();
    } catch (_) {}
    try {
      await _google.disconnect();
    } catch (_) {}
    await clearSession();
  }

  static Future<void> clearSession() async {
    await _prefs?.remove(_kJwt);
    await _prefs?.remove(_kExp);
  }

  DateTime? _extractExpFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1].padRight(
        parts[1].length + (4 - parts[1].length % 4) % 4,
        '=',
      );
      final map =
          jsonDecode(utf8.decode(base64Url.decode(payload)))
              as Map<String, dynamic>;
      final expSeconds = (map['exp'] as num?)?.toInt();
      if (expSeconds == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        expSeconds * 1000,
        isUtc: true,
      ).toLocal();
    } catch (_) {
      return null;
    }
  }

  // DEV ONLY: bypass SSL self-signed (không dùng cho prod)
  static http.Client createInsecureClient({required bool enable}) {
    if (!enable) return http.Client();
    final io = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    return IOClient(io);
  }

  // === Các API phụ giữ nguyên của bạn (updatePhone*, getProfileById, …) ===
}
