// lib/controllers/history_controller.dart
import 'package:flutter/foundation.dart';
import '../models/history_message.dart';
import '../services/history_message_repository.dart';
import '../controllers/auth_controller.dart';

class HistoryController extends ChangeNotifier {
  final HistoryMessageRepository _repo;
  final AuthController _auth;

  HistoryController(this._repo, this._auth, {String? endpoint})
    : _endpoint = endpoint ?? '/history/messages';

  final List<HistoryMessage> _items = [];
  bool _busy = false;
  String? _error;

  String _endpoint; // endpoint động

  List<HistoryMessage> get items => List.unmodifiable(_items);
  bool get busy => _busy;
  String? get error => _error;
  String get endpoint => _endpoint;

  void setEndpoint(String endpoint, {bool refreshNow = false}) {
    _endpoint = endpoint;
    if (refreshNow) load();
  }

  Future<void> load() async {
    final uid = _auth.user?.id; // lấy từ lúc đăng nhập
    if (uid == null || uid.isEmpty) {
      _error = 'Thiếu userId (chưa đăng nhập?)';
      notifyListeners();
      return;
    }

    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _repo.fetchByUser(
        endpoint: _endpoint, // '/v1/history/{userId}' hoặc '/v1/history'
        userId: uid,
      );
      _items
        ..clear()
        ..addAll(data);
    } catch (e) {
      _error = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}
