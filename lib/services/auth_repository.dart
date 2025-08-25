import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../models/auth_session.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


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
    return AuthSession(jwt: jwt, expiresAt: DateTime.fromMillisecondsSinceEpoch(exp));
  }


  Future<void> persistSession(AuthSession s) async {
    await _prefs?.setString(_kJwt, s.jwt);
    await _prefs?.setInt(_kExp, s.expiresAt.millisecondsSinceEpoch);
  }


  Future<void> clearSession() async {
    await _prefs?.remove(_kJwt);
    await _prefs?.remove(_kExp);
  }


// Đăng nhập Google: trên Web sẽ mở POPUP khi có clientId
  Future<(AppUser, AuthSession)> signInWithGoogle() async {
    final google = GoogleSignIn(
      clientId: kIsWeb ? 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com' : null,
      scopes: const ['email', 'profile', 'openid'],
    );


// Đảm bảo không dính phiên cũ → luôn mở popup mới
    await google.signOut();


    final acc = await google.signIn(); // Web: mở POPUP
    if (acc == null) throw Exception('User huỷ đăng nhập');


    final auth = await acc.authentication;
    final idToken = auth.idToken; // gửi lên backend để verify
    final accessToken = auth.accessToken;


// TODO: gọi API backend (Bun/Elysia) đổi idToken → JWT hệ thống + expiresAt
// final resp = await http.post(...);
// final jwt = resp.jwt; final exp = resp.expiresAt;
    final jwt = idToken ?? accessToken ?? 'temp-token';
    final expiresAt = DateTime.now().add(const Duration(days: 7));


    final user = AppUser(
      id: acc.id,
      email: acc.email,
      name: acc.displayName,
      avatarUrl: acc.photoUrl,
    );


    final session = AuthSession(jwt: jwt, expiresAt: expiresAt);
    await persistSession(session);
    return (user, session);
  }


  Future<void> logout() async {
    try { await GoogleSignIn().disconnect(); } catch (_) {}
    await clearSession();
  }
}