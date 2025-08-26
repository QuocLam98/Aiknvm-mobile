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

  /// Khôi phục phiên từ storage; nếu hết hạn thì xoá
  Future<void> restore() async {
    try {
      final ok = await _repo.hasValidSession;
      if (ok) {
        _session = _repo.getCurrentSession();
      } else {
        await _repo.clearSession();
        _session = null;
      }
      _error = null;
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
    } catch (e, st) {
      // có thể debugPrint nếu cần stacktrace
      // debugPrint('loginWithGoogle error: $e\n$st');
      _error = e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } finally {
      _user = null;
      _session = null;
      _error = null;
      notifyListeners();
    }
  }
}
