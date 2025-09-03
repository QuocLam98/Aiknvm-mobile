import 'package:flutter/foundation.dart';
import '../models/history_message.dart';
import '../services/history_message_repository.dart';
import '../controllers/auth_controller.dart';

class HistoryController extends ChangeNotifier {
  final HistoryMessageRepository _repo;
  final AuthController _auth;

  HistoryController(this._repo, this._auth);

  final List<HistoryMessage> _items = [];
  HistoryMessage? _selected;
  Future<List<HistoryMessage>>? _historyFuture;

  List<HistoryMessage> get items => List.unmodifiable(_items);
  HistoryMessage? get selected => _selected;
  Future<List<HistoryMessage>>? get historyFuture => _historyFuture;

  /// Lấy Future đã cache nếu có; nếu chưa thì tạo mới
  Future<List<HistoryMessage>> getHistoryFuture() {
    final uid = _auth.user?.id ?? '';
    if (uid.isEmpty) {
      _historyFuture = Future.error('Thiếu userId (chưa đăng nhập?)');
      return _historyFuture!;
    }
    _historyFuture ??= _repo.getHistoryChatByUserId(uid).then((list) {
      _items
        ..clear()
        ..addAll(list);
      notifyListeners();
      return _items;
    });
    return _historyFuture!;
  }

  /// Refresh cưỡng bức (kéo để làm mới)
  Future<void> refreshHistory() async {
    final uid = _auth.user?.id ?? '';
    if (uid.isEmpty) {
      throw StateError('Thiếu userId (chưa đăng nhập?)');
    }
    _historyFuture = _repo.getHistoryChatByUserId(uid).then((list) {
      _items
        ..clear()
        ..addAll(list);
      notifyListeners();
      return _items;
    });
    await _historyFuture;
  }

  void selectHistory(HistoryMessage item) {
    _selected = item;
    notifyListeners();
  }
}
