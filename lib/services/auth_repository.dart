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
    // Ưu tiên lấy từ dotenv (web: từ public /.env; mobile: từ --dart-define nếu truyền vào main())
    final envClientId = dotenv.env['GOOGLE_CLIENT_ID']?.trim();
    // Fallback an toàn cho Android: hard-code giá trị không bí mật (OAuth Web Client ID)
    // để tránh lỗi clientConfigurationError khi chưa truyền --dart-define.
    const fallbackAndroidWebClientId =
        '514725903844-d2lfdqh57kegcck6hpva4p442e4jbaje.apps.googleusercontent.com';

    final resolvedClientId = (envClientId != null && envClientId.isNotEmpty)
        ? envClientId
        : fallbackAndroidWebClientId;

    final clientIdOrNull = resolvedClientId.isEmpty ? null : resolvedClientId;

    // Log ngắn gọn để kiểm tra cấu hình (ẩn bớt ID)
    final preview = (clientIdOrNull == null || clientIdOrNull.length < 10)
        ? 'null'
        : '${clientIdOrNull.substring(0, 8)}…${clientIdOrNull.substring(clientIdOrNull.length - 10)}';
    debugPrint(
      'GoogleSignIn init - kIsWeb=$kIsWeb, serverClientId(Android)=$preview',
    );

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
    // Sạch trạng thái trước khi auth
    try {
      await _google.signOut();
    } catch (_) {}

    // v7 API: authenticate() trả về account + tokens; authentication là getter
    final acc = await _google.authenticate();
    final auth = acc.authentication;
    final idToken = auth.idToken;

    // Biến cục bộ để KHÔNG đụng vào getter final
    String userId = '';
    String userEmail = '';
    String userRole = 'user'; // mặc định
    String jwt = '';
    late DateTime expiresAt;

    if (idToken != null) {
      // --- Flow chuẩn: gửi idToken cho backend verify ---
      final uri = Uri.parse('$baseUrl/auth/google/callback');
      http.Response resp;

      try {
        resp = await _client
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'idToken': idToken}),
            )
            .timeout(const Duration(seconds: 20));
      } on HandshakeException catch (e) {
        throw Exception(
          'Không thể thiết lập kết nối an toàn tới $uri (TLS handshake). Kiểm tra chứng chỉ HTTPS của server.\n$e',
        );
      } on SocketException catch (e) {
        throw Exception('Không thể kết nối tới server ($uri). $e');
      }

      debugPrint('HTTP ${resp.request?.method} $uri -> ${resp.statusCode}');
      debugPrint(resp.body);

      if (resp.statusCode == 200) {
        late final Map<String, dynamic> data;
        try {
          data = jsonDecode(resp.body) as Map<String, dynamic>;
        } catch (e) {
          throw Exception('Body không phải JSON hợp lệ: $e');
        }

        // token
        jwt = (data['token'] ?? data['jwt'] ?? '') as String;
        if (jwt.isEmpty) {
          throw Exception('Phản hồi backend không có token');
        }

        // user info: ưu tiên root, fallback data['user'], cuối cùng mới fallback Google account (display-only)
        final Map<String, dynamic> userJson = (data['user'] is Map)
            ? (data['user'] as Map).cast<String, dynamic>()
            : const {};

        userId = (data['id'] ?? userJson['id'] ?? '') as String;
        userEmail = (data['email'] ?? userJson['email'] ?? '') as String;

        // Hạn dùng
        expiresAt =
            _extractExpFromJwt(jwt) ??
            DateTime.now().add(const Duration(hours: 6));
      } else {
        final preview = resp.body.length > 400
            ? '${resp.body.substring(0, 400)}…'
            : resp.body;
        throw Exception(
          'Đăng nhập thất bại: ${resp.statusCode} ${resp.reasonPhrase}\n$preview',
        );
      }
    } else {
      // --- Fallback DEV: mobile-login (không khuyến nghị) ---
      final uri = Uri.parse('$baseUrl/mobile-login');
      http.Response resp;
      try {
        resp = await _client
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': acc.email,
                'name': acc.displayName,
                'picture': acc.photoUrl,
              }),
            )
            .timeout(const Duration(seconds: 20));
      } on HandshakeException catch (e) {
        throw Exception(
          'Không thể thiết lập kết nối an toàn tới $uri (TLS handshake). Kiểm tra chứng chỉ HTTPS của server.\n$e',
        );
      } on SocketException catch (e) {
        throw Exception('Không thể kết nối tới server ($uri). $e');
      }

      if (resp.statusCode == 200) {
        late final Map<String, dynamic> data;
        try {
          data = jsonDecode(resp.body) as Map<String, dynamic>;
          debugPrint(
            const JsonEncoder.withIndent('  ').convert(data),
            wrapWidth: 1024,
          );
        } catch (e) {
          throw Exception('Body không phải JSON hợp lệ: $e');
        }

        // Từ ví dụ bạn đưa: id/email nằm ở root
        jwt = (data['token'] ?? data['jwt'] ?? '') as String? ?? '';
        userId = data['id'] as String? ?? '';
        userEmail = data['email'] as String? ?? '';
        userRole = data['role'] as String? ?? 'user'; // lấy role nếu có

        expiresAt =
            _extractExpFromJwt(jwt) ??
            DateTime.now().add(const Duration(hours: 6));
      } else {
        final preview = resp.body.length > 400
            ? '${resp.body.substring(0, 400)}…'
            : resp.body;
        throw Exception(
          'Đăng nhập thất bại: ${resp.statusCode} ${resp.reasonPhrase}\n$preview',
        );
      }
    }

    // Tạo AppUser từ DỮ LIỆU SERVER (không dùng acc.id/email cho auth)
    final user = AppUser(
      id: userId,
      email: userEmail,
      name:
          acc.displayName ??
          '', // chỉ dùng để hiển thị nếu server không trả name
      avatarUrl: acc.photoUrl,
      role: userRole,
    );

    final session = AuthSession(jwt: jwt, expiresAt: expiresAt);
    await persistSession(session);
    return (user, session);
  }

  /// Logout an toàn:
  /// - Dùng signOut() là đủ cho hầu hết case
  /// - disconnect() chỉ khi muốn revoke scopes; bọc try/catch để tránh channel-error
  Future<void> logout() async {
    try {
      await _google.signOut();
    } catch (_) {}

    // Chỉ revoke nếu thực sự cần (ít khi phải dùng)
    try {
      await _google.disconnect();
    } catch (_) {
      // Bỏ qua lỗi channel-error trên một số thiết bị
    }

    await clearSession();
  }

  /// Giải mã 'exp' từ JWT (header.payload.sig)
  DateTime? _extractExpFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = payload.padRight(
        payload.length + (4 - payload.length % 4) % 4,
        '=',
      );
      final jsonStr = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
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
