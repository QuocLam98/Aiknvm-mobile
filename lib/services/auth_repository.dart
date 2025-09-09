import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
                  (dotenv.maybeGet('API_BASE_URL') ??
                      const String.fromEnvironment(
                        'API_BASE_URL',
                        defaultValue: '',
                      )))
              .trim();

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();

    final webClientId = const String.fromEnvironment(
      'GOOGLE_WEB_CLIENT_ID',
      defaultValue: '',
    ).trim();
    if (webClientId.isEmpty) {
      throw StateError(
        'Missing GOOGLE_WEB CLIENT_ID (pass via --dart-define).',
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

  /// Đăng nhập Google (mobile v7 + web), **không dùng Firebase**.
  /// Mobile gửi idToken lên `/auth/google/mobile`.
  Future<(AppUser, AuthSession)> signInWithGoogle() async {
    final gs = GoogleSignIn.instance;

    // làm sạch trạng thái trước khi auth (tránh cache account cũ)
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

    final auth = await acc.authentication; // v7 vẫn có
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Không lấy được idToken. Kiểm tra initialize(serverClientId: GOOGLE_WEB_CLIENT_ID).',
      );
    }

    final uri = Uri.parse('$baseUrl/auth/google/mobile');

    final resp = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': idToken}),
        )
        .timeout(const Duration(seconds: 20));

    debugPrint('HTTP ${resp.request?.method} $uri -> ${resp.statusCode}');
    debugPrint(resp.body);

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

  // DEV ONLY: bypass SSL self-signed (tuyệt đối không dùng cho prod)
  static http.Client createInsecureClient({required bool enable}) {
    if (!enable) return http.Client();
    final io = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    return IOClient(io);
  }

  // ====== Các API khác giữ nguyên ======

  Future<void> updatePhoneById({
    required String userId,
    required String phone,
  }) async {
    if (userId.isEmpty) throw ArgumentError('userId is empty');
    final uri = Uri.parse('$baseUrl/update-phone-mobile');
    final headers = <String, String>{'Content-Type': 'application/json'};

    final resp = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({'id': userId, 'phone': phone}),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;

    try {
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      final msg = (map['message'] ?? map['error'] ?? resp.reasonPhrase)
          .toString();
      throw Exception('Cập nhật thất bại: ${resp.statusCode} $msg');
    } catch (_) {
      throw Exception(
        'Cập nhật thất bại: ${resp.statusCode} ${resp.reasonPhrase}',
      );
    }
  }

  Future<void> updatePhone(String phone, {String? bearerToken}) async {
    final uri = Uri.parse('$baseUrl/update-phone-mobile');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (bearerToken != null && bearerToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }

    final resp = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({'phone': phone}),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;

    try {
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      final msg = (map['message'] ?? map['error'] ?? resp.reasonPhrase)
          .toString();
      throw Exception('Cập nhật thất bại: ${resp.statusCode} $msg');
    } catch (_) {
      throw Exception(
        'Cập nhật thất bại: ${resp.statusCode} ${resp.reasonPhrase}',
      );
    }
  }

  Future<AppUser> getProfileById(String userId) async {
    if (userId.isEmpty) throw ArgumentError('userId is empty');
    final uri = Uri.parse('$baseUrl/me');
    final resp = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'id': userId}),
    );
    if (resp.statusCode != 200) {
      throw Exception('POST $uri -> ${resp.statusCode} ${resp.reasonPhrase}');
    }

    late final Map<String, dynamic> data;
    final root = jsonDecode(resp.body);
    if (root is Map && root['data'] is Map) {
      data = Map<String, dynamic>.from(root['data'] as Map);
    } else if (root is Map<String, dynamic>) {
      data = root;
    } else {
      throw Exception('Unexpected profile format');
    }

    final id = (data['id'] ?? data['_id'] ?? data['userId'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final name = (data['name'] ?? data['fullName'] ?? '').toString();
    final avatar =
        (data['avatar'] ?? data['avatarUrl'] ?? data['picture'] ?? '')
            .toString();
    final role = (data['role'] ?? 'user').toString();
    final phone = (data['phone'] ?? data['phoneNumber'] ?? '').toString();

    return AppUser(
      id: id,
      email: email,
      name: name.isEmpty ? null : name,
      avatarUrl: avatar.isEmpty ? null : avatar,
      role: role.isEmpty ? null : role,
      phone: phone.isEmpty ? null : phone,
    );
  }
}
