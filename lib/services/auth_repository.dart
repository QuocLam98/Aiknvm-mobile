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

  /// API base URL, ví dụ: https://server.aiknvm.vn
  final String baseUrl;

  /// HTTP client (có thể inject Dio/IOClient nếu cần)
  final http.Client _client;

  /// Singleton GoogleSignIn dùng xuyên suốt (v7 API)
  final GoogleSignIn _google = GoogleSignIn.instance;

  /// Khởi tạo mặc định.
  /// - `client`: có thể truyền IOClient custom (VD: dev bypass SSL - **chỉ debug**)
  /// - `baseUrlOverride`: dùng khi bạn muốn override .env
  AuthRepository({http.Client? client, String? baseUrlOverride})
    : _client = client ?? http.Client(),
      baseUrl =
          baseUrlOverride ??
          (dotenv.maybeGet('API_BASE_URL') ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue: '',
                  ))
              .trim();

  static Future<void> clearSession() async {
    await _prefs?.remove(_kJwt);
    await _prefs?.remove(_kExp);
  }

  /// Chỉ gọi một lần ở app start
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    // Khởi tạo Google Sign-In (v7: cần initialize trước khi dùng)
    // Ưu tiên GOOGLE_CLIENT_ID; nếu thiếu, fallback sang GOOGLE_WEB_CLIENT_ID (key bạn đang có trong .env)
    String? clientIdOrNull = dotenv.env['GOOGLE_CLIENT_ID']?.trim();
    clientIdOrNull = (clientIdOrNull != null && clientIdOrNull.isNotEmpty)
        ? clientIdOrNull
        : (dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim().isNotEmpty == true
              ? dotenv.env['GOOGLE_WEB_CLIENT_ID']!.trim()
              : null);

    // Log ngắn gọn để kiểm tra cấu hình (ẩn bớt ID)
    final preview = (clientIdOrNull == null || clientIdOrNull.length < 10)
        ? 'null'
        : '${clientIdOrNull.substring(0, 8)}…${clientIdOrNull.substring(clientIdOrNull.length - 10)}';
    debugPrint('GoogleSignIn init - kIsWeb=$kIsWeb');
    debugPrint('  serverClientId(Android)/clientId(Web) preview: $preview');

    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? clientIdOrNull : null,
      serverClientId: kIsWeb ? null : clientIdOrNull,
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

  /// Đăng nhập Google:
  /// - Web: cần GOOGLE_CLIENT_ID trong .env
  /// - Android/iOS: dựa packageId + SHA-1/BundleId
  /// - BE: POST { idToken } -> { token/jwt, ... }
  Future<(AppUser, AuthSession)> signInWithGoogle() async {
    try {
      await _google.signOut();
    } catch (_) {}

    late GoogleSignInAccount acc;
    try {
      acc = await _google
          .authenticate(); // hoặc authenticate() tuỳ phiên bản plugin
    } catch (e) {
      throw Exception('Google Sign-In thất bại: $e');
    }

    late GoogleSignInAuthentication authentication;
    try {
      authentication = await acc.authentication;
    } catch (e) {
      throw Exception('Không thể lấy authentication: $e');
    }

    final idToken = authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Không lấy được idToken từ Google');
    }

    // --- Gửi idToken tới backend ---
    final uri = Uri.parse('$baseUrl/auth/google-mobile');
    http.Response resp;
    try {
      resp = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw Exception('Không thể kết nối tới server: $e');
    }

    if (resp.statusCode != 200) {
      throw Exception('Đăng nhập thất bại ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;

    final userJson = (data['user'] is Map)
        ? (data['user'] as Map).cast<String, dynamic>()
        : data;

    final user = AppUser(
      id: userJson['id'] as String? ?? '',
      email: userJson['email'] as String? ?? '',
      name: userJson['name'] as String? ?? '',
      avatarUrl: userJson['image'] as String? ?? '',
      role: userJson['role'] as String? ?? 'user',
    );

    final expiresAt = DateTime.now().add(const Duration(hours: 6));
    final session = AuthSession(
      jwt: data['token'] as String? ?? '',
      expiresAt: expiresAt,
    );

    await persistSession(session);
    return (user, session);
  }

  // ===== Tuỳ chọn: tạo client bypass SSL cho DEV (CHỈ DEBUG!) =====
  // Dùng khi server dev tự-signed hoặc sai chain. TUYỆT ĐỐI KHÔNG dùng cho prod.
  static http.Client createInsecureClient({required bool enable}) {
    if (!enable) return http.Client();
    final io = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    return IOClient(io);
  }

  /// Cập nhật số điện thoại theo userId (không cần token)
  Future<void> updatePhoneById({
    required String userId,
    required String phone,
  }) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId is empty');
    }
    final uri = Uri.parse('$baseUrl/update-phone-mobile');
    final headers = <String, String>{'Content-Type': 'application/json'};

    final resp = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({'id': userId, 'phone': phone}),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return;
    }

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

  /// Cập nhật số điện thoại của tài khoản hiện tại
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

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return;
    }

    // Thử lấy message từ body nếu có
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

  /// Lấy thông tin hồ sơ người dùng (email, phone, avatar...) theo userId
  /// Backend chỉ nhận id (không cần token)
  Future<AppUser> getProfileById(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId is empty');
    }
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
