import 'dart:convert'; // để decode JWT
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../models/auth_session.dart';
import '../services/auth_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository _repo;
  AuthController(this._repo);

  bool _busy = false;
  String? _error;
  AppUser? _user;
  AuthSession? _session;

  bool get busy => _busy;
  String? get error => _error;
  AppUser? get user => _user;
  String? get userId => _user?.id; // tiện cho HistoryController
  AuthSession? get session => _session;

  bool get isLoggedIn =>
      _session != null && _session!.expiresAt.isAfter(DateTime.now());

  /// Dọn lỗi thủ công khi cần
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// Khôi phục phiên từ storage; nếu hết hạn thì xoá.
  /// Đồng thời cố gắng dựng lại AppUser từ JWT để có sẵn id/email.
  Future<void> restore() async {
    try {
      final ok = await _repo.hasValidSession;
      if (ok) {
        _session = _repo.getCurrentSession();

        // Nếu chưa có user được cache, thử extract từ JWT
        if (_user == null &&
            _session?.jwt != null &&
            _session!.jwt.isNotEmpty) {
          _user = _tryBuildUserFromJwt(_session!.jwt);
        }

        _error = null;
      } else {
        await AuthRepository.clearSession();
        _session = null;
        _user = null;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  /// Đăng nhập Google (đã chặn re-entrancy)
  Future<bool> loginWithGoogle() async {
    if (_busy) return false; // chặn bấm liên tiếp
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final (u, s) = await _repo.signInWithGoogle();
      _user = u;
      _session = s;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await AuthRepository.clearSession();
    } finally {
      _user = null;
      _session = null;
      _error = null;
      notifyListeners();
    }
  }

  /// ========= Helpers =========

  /// Cố gắng dựng AppUser từ JWT (nếu backend nhúng claim)
  /// Ưu tiên các khóa phổ biến: userId/id/sub, email, name, avatar/picture
  AppUser? _tryBuildUserFromJwt(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) return null;
      final payload = _base64UrlDecode(parts[1]);
      final map = json.decode(payload) as Map<String, dynamic>;

      final String id = (map['userId'] ?? map['id'] ?? map['sub'] ?? '')
          .toString();
      if (id.isEmpty) return null;

      final String email = (map['email'] ?? '').toString();
      final String name = (map['name'] ?? '').toString();
      final String? avatar =
          (map['avatar'] ?? map['picture'] ?? map['avatarUrl'])?.toString();

      return AppUser(id: id, email: email, name: name, avatarUrl: avatar);
    } catch (_) {
      return null;
    }
  }

  String _base64UrlDecode(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    final bytes = base64.decode(normalized);
    return utf8.decode(bytes);
  }
}
