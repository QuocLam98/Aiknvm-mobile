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
  bool get isLoggedIn => _session != null && _session!.expiresAt.isAfter(DateTime.now());


  Future<void> restore() async {
    _session = _repo.getCurrentSession();
    _error = null;
    notifyListeners();
  }


  Future<bool> loginWithGoogle() async {
    _busy = true; _error = null; notifyListeners();
    try {
      final (u, s) = await _repo.signInWithGoogle();
      _user = u; _session = s;
      _busy = false; notifyListeners();
      return true;
    } catch (e) {
      _busy = false; _error = e.toString(); notifyListeners();
      return false;
    }
  }


  Future<void> logout() async {
    await _repo.logout();
    _user = null; _session = null; _error = null;
    notifyListeners();
  }
}