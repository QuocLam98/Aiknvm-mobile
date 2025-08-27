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

  /// 1 instance GoogleSignIn dùng xuyên suốt
  final GoogleSignIn _google;

  /// Khởi tạo mặc định.
  /// - `client`: có thể truyền IOClient custom (VD: dev bypass SSL - **chỉ debug**)
  /// - `google`: tuỳ biến scopes/clientId
  /// - `baseUrlOverride`: dùng khi bạn muốn override .env
  AuthRepository({
    http.Client? client,
    GoogleSignIn? google,
    String? baseUrlOverride,
  }) : _client = client ?? http.Client(),
       baseUrl = baseUrlOverride ?? dotenv.env['API_BASE_URL'] ?? '',
       _google =
           google ??
           GoogleSignIn(
             clientId: kIsWeb ? dotenv.env['GOOGLE_WEB_CLIENT_ID'] : null,
             scopes: const ['email', 'profile', 'openid'],
           ) {
    if (baseUrl.isEmpty) {
      throw StateError('Missing API_BASE_URL in .env');
    }
  }

  /// Chỉ gọi một lần ở app start
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
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

  Future<void> clearSession() async {
    await _sp.remove(_kJwt);
    await _sp.remove(_kExp);
  }

  /// Đăng nhập Google:
  /// - Web: cần GOOGLE_WEB_CLIENT_ID trong .env
  /// - Android/iOS: dựa packageId + SHA-1/BundleId
  /// - BE: POST { idToken } -> { token/jwt, ... }
  Future<(AppUser, AuthSession)> signInWithGoogle() async {
    // bảo đảm trạng thái sạch để UI luôn hiện popup khi cần
    try {
      if (await _google.isSignedIn()) {
        await _google.signOut();
      }
    } catch (_) {}

    final acc = await _google.signIn();
    if (acc == null) {
      throw Exception('User huỷ đăng nhập');
    }

    final auth = await acc.authentication;
    final idToken = auth.idToken;
    final accessToken = auth.accessToken;

    String jwt;
    DateTime expiresAt;

    if (idToken != null) {
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
        // Lỗi TLS/SSL (cert/chain/SNI). Hiển thị thông tin dễ hiểu hơn cho UI
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
          debugPrint(
            const JsonEncoder.withIndent('  ').convert(data),
            wrapWidth: 1024,
          );
        } catch (e) {
          throw Exception('Body không phải JSON hợp lệ: $e');
        }

        jwt = (data['token'] ?? data['jwt'] ?? '') as String;
        if (jwt.isEmpty) {
          throw Exception('Phản hồi backend không có token');
        }

        // 1) lấy exp từ JWT nếu có
        expiresAt =
            _extractExpFromJwt(jwt) ??
            // 2) Fallback +6h
            DateTime.now().add(const Duration(hours: 6));
      } else {
        // Không 200 → ném lỗi có nội dung để debug
        final preview = resp.body.length > 400
            ? '${resp.body.substring(0, 400)}…'
            : resp.body;
        throw Exception(
          'Đăng nhập thất bại: ${resp.statusCode} ${resp.reasonPhrase}\n$preview',
        );
      }
    } else {
      // Không có idToken → fallback dev (không khuyến nghị)
      jwt = accessToken ?? 'temp-token';
      expiresAt = DateTime.now().add(const Duration(hours: 6));
    }

    final user = AppUser(
      id: acc.id,
      email: acc.email,
      name: acc.displayName ?? '',
      avatarUrl: acc.photoUrl,
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
      if (await _google.isSignedIn()) {
        await _google.signOut();
      }
    } catch (_) {}

    // Chỉ revoke nếu thực sự cần (ít khi phải dùng)
    try {
      if (await _google.isSignedIn()) {
        await _google.disconnect();
      }
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
}
