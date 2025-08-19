import 'dart:convert';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const _kTokenKey = 'app_jwt';
  static const _kExpireAtKey = 'app_jwt_expire_at';

  final String baseUrl;
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  // điền clientId/redirectUri của bạn
  final String androidClientId;
  final String iosClientId;
  final String androidRedirectUri;
  final String iosRedirectUri;

  AuthService({
    this.baseUrl = 'https://server.aiknvm.vn',
    required this.androidClientId,
    required this.iosClientId,
    required this.androidRedirectUri,
    required this.iosRedirectUri,
  });

  static const _issuer = 'https://accounts.google.com';
  static const _scopes = <String>['openid', 'email', 'profile'];

  Future<bool> hasValidToken() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString(_kTokenKey);
    final expireAtMs = sp.getInt(_kExpireAtKey) ?? 0;
    if (token == null || token.isEmpty) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now + 30 * 1000 < expireAtMs;
  }

  Future<void> clearToken() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kTokenKey);
    await sp.remove(_kExpireAtKey);
  }

  Future<void> _saveToken(String token, DateTime expireAt) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kTokenKey, token);
    await sp.setInt(_kExpireAtKey, expireAt.millisecondsSinceEpoch);
  }

  /// Authorization Code + PKCE, redirect giống FE (không popup).
  /// Cách 1: đổi CODE -> tokens tại Google (trên device) rồi gửi id_token lên server bạn.
  Future<bool> signInWithGoogle() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _platformClientId(),
        _platformRedirectUri(),
        issuer: _issuer,
        scopes: _scopes,
        // promptValues: ['consent'], // giống FE nếu muốn
        // accessType: 'offline',     // Google bỏ qua ở AppAuth, refreshToken phụ thuộc consent
      ),
    );

    if (result == null) return false;

    final idToken = result.idToken;
    // final accessToken = result.accessToken;      // nếu server cần
    // final refreshToken = result.refreshToken;    // nếu muốn lưu để refresh

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google did not return id_token');
    }

    // Gửi lên BE của bạn để đổi JWT nội bộ
    final jwtOk = await _exchangeWithBackend(idToken: idToken);

    return jwtOk;
  }

  /// Cách 2 (nếu BE muốn nhận AUTH CODE thay vì id_token):
  Future<bool> signInGetAuthCodeThenExchangeAtBackend() async {
    final res = await _appAuth.authorize(
      AuthorizationRequest(
        _platformClientId(),
        _platformRedirectUri(),
        issuer: _issuer,
        scopes: _scopes,
        // promptValues: ['consent'],
      ),
    );
    if (res == null || res.authorizationCode == null) return false;
    final code = res.authorizationCode!;

    // Gọi BE /auth/google-code { code, redirectUri, clientId (server biết) }
    final uri = Uri.parse('$baseUrl/auth/google-code');
    final resp = await http.post(uri,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'code': code,
        'redirectUri': _platformRedirectUri(),
        // 'clientId': _platformClientId(), // nếu BE cần xác minh
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Exchange auth code failed: ${resp.statusCode}');
    }
    final body = jsonDecode(resp.body);
    final data = (body is Map) ? body['data'] : null;
    final token = (data is Map ? data['token'] : null)?.toString();
    final expireAtStr = (data is Map ? data['expireAt'] : null)?.toString();

    if (token == null || token.isEmpty) throw Exception('No app token returned');
    final expireAt = expireAtStr != null
        ? DateTime.tryParse(expireAtStr) ?? DateTime.now().add(const Duration(hours: 8))
        : DateTime.now().add(const Duration(hours: 8));
    await _saveToken(token, expireAt);
    return true;
  }

  Future<bool> _exchangeWithBackend({required String idToken}) async {
    final uri = Uri.parse('$baseUrl/auth/google');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Backend exchange failed: ${resp.statusCode}');
    }
    final body = jsonDecode(resp.body);
    final data = (body is Map) ? body['data'] : null;
    final token = (data is Map ? data['token'] : null)?.toString();
    final expireAtStr = (data is Map ? data['expireAt'] : null)?.toString();

    if (token == null || token.isEmpty) return false;

    final expireAt = expireAtStr != null
        ? DateTime.tryParse(expireAtStr) ?? DateTime.now().add(const Duration(hours: 8))
        : DateTime.now().add(const Duration(hours: 8));

    await _saveToken(token, expireAt);
    return true;
  }

  String _platformClientId() {
    // bạn có thể check Platform.isAndroid / isIOS để trả clientId tương ứng
    // package:flutter_appauth tự làm điều này nếu bạn truyền cả 2 vào Android/iOS field,
    // nhưng để rõ ràng:
    // ignore: avoid_print
    // print('Using Android clientId by default');
    return androidClientId;
  }

  String _platformRedirectUri() {
    return androidRedirectUri;
  }
}
