import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/auth_session.dart';

class AuthRepository {
  static const _kJwt = 'auth.jwt';
  static const _kExp = 'auth.exp';
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> get hasValidSession async {
    final jwt = _prefs?.getString(_kJwt);
    final exp = _prefs?.getInt(_kExp);
    if (jwt == null || exp == null) return false;
    return DateTime.now().isBefore(DateTime.fromMillisecondsSinceEpoch(exp));
  }

  AuthSession? getCurrentSession() {
    final jwt = _prefs?.getString(_kJwt);
    final exp = _prefs?.getInt(_kExp);
    if (jwt == null || exp == null) return null;
    final expires = DateTime.fromMillisecondsSinceEpoch(exp);
    if (DateTime.now().isAfter(expires)) return null;
    return AuthSession(jwt: jwt, expiresAt: expires);
  }

  Future<void> persistSession(AuthSession s) async {
    await _prefs?.setString(_kJwt, s.jwt);
    await _prefs?.setInt(_kExp, s.expiresAt.millisecondsSinceEpoch);
  }

  Future<void> clearSession() async {
    await _prefs?.remove(_kJwt);
    await _prefs?.remove(_kExp);
  }

  /// Đăng nhập Google:
  /// - Web: cần clientId (từ .env)
  /// - Mobile: không cần clientId (plugin tự handle theo package/SHA-1/BundleId)
  /// - Backend trả {token, email, ...}; không có expiresAt → tự suy ra từ JWT hoặc +6h
  Future<(AppUser, AuthSession)> signInWithGoogle() async {
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    final apiBaseUrl = dotenv.env['API_BASE_URL'];

    final google = GoogleSignIn(
      clientId: kIsWeb ? webClientId : null,
      scopes: const ['email', 'profile', 'openid'],
    );

    try {
      await google.signOut(); // clear phiên cũ để luôn mở UI mới
    } catch (_) {}

    final acc = await google.signIn();
    if (acc == null) {
      throw Exception('User huỷ đăng nhập');
    }

    final auth = await acc.authentication;
    final idToken = auth.idToken;       // gửi lên server để verify
    final accessToken = auth.accessToken;

    String jwt;
    DateTime expiresAt;

    if (apiBaseUrl != null && apiBaseUrl.isNotEmpty && idToken != null) {
      final uri = Uri.parse('$apiBaseUrl/auth/google/callback');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      debugPrint('HTTP ${resp.request?.method} $uri -> ${resp.statusCode}');
      if (resp.statusCode == 200) {
        // Parse body
        Map<String, dynamic> data;
        try {
          data = jsonDecode(resp.body) as Map<String, dynamic>;
          debugPrint(const JsonEncoder.withIndent('  ').convert(data), wrapWidth: 1024);
        } catch (e) {
          throw Exception('Body không phải JSON hợp lệ: $e');
        }

        jwt = (data['token'] ?? data['jwt'] ?? '') as String;
        if (jwt.isEmpty) {
          throw Exception('Phản hồi backend không có token');
        }

        // 1) Cố đọc exp từ JWT (nếu là JWT thật)
        expiresAt = _extractExpFromJwt(jwt) ??
            // 2) Fallback +6h (21600s) như server set
            DateTime.now().add(const Duration(hours: 6));
      } else {
        // Fallback DEV: dùng idToken/accessToken để không chặn flow
        final preview = resp.body.length > 300 ? '${resp.body.substring(0, 300)}…' : resp.body;
        debugPrint('Non-200 body: $preview');
        jwt = idToken ?? accessToken ?? 'temp-token';
        expiresAt = DateTime.now().add(const Duration(hours: 6));
      }
    } else {
      // Không cấu hình backend → dùng tạm token Google
      jwt = idToken ?? accessToken ?? 'temp-token';
      expiresAt = DateTime.now().add(const Duration(hours: 6));
    }

    final user = AppUser(
      id: acc.id,                   // id từ Google
      email: acc.email,                 // lấy từ server (ưu tiên), fallback Google
      name: acc.displayName ?? '',  // fallback rỗng
      avatarUrl: acc.photoUrl,
    );


    final session = AuthSession(jwt: jwt, expiresAt: expiresAt);
    await persistSession(session);
    return (user, session);
  }

  Future<void> logout() async {
    try {
      await GoogleSignIn().disconnect();
    } catch (_) {}
    await clearSession();
  }

  /// Giải mã 'exp' từ JWT (nếu token là JWT dạng header.payload.sig)
  /// Trả về DateTime của exp, hoặc null nếu không giải mã được.
  DateTime? _extractExpFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      // base64url decode (cần padding)
      String normalized = payload.padRight(payload.length + (4 - payload.length % 4) % 4, '=');
      final jsonStr = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final expSeconds = (map['exp'] as num?)?.toInt();
      if (expSeconds == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000);
    } catch (_) {
      return null;
    }
  }
}
