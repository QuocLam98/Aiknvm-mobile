// controllers/chat_controller.dart
import 'package:flutter/foundation.dart';
import '../models/chat_message_model.dart';
import '../services/chat_repository.dart';

class ChatController extends ChangeNotifier {
  final ChatRepository _repo;
  final String historyId;

  ChatController(this._repo, {required this.historyId});

  final List<ChatMessageModel> _messages = [];
  bool _busy = false;
  String? _error;

  int _page = 1;
  final int _limit = 20;
  bool _hasNext = true;

  List<ChatMessageModel> get messages => List.unmodifiable(_messages);
  bool get busy => _busy;
  String? get error => _error;
  bool get hasNext => _hasNext;

  /// Load trang đầu (clear cũ)
  Future<void> refresh() async {
    _page = 1;
    _hasNext = true;
    _messages.clear();
    notifyListeners();
    await loadMore();
  }

  /// Load thêm (khi scroll)
  Future<void> loadMore() async {
    if (_busy || !_hasNext) return;

    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final newMessages = await _repo.loadChatByHistoryId(
        historyId,
        page: _page,
        limit: _limit,
      );

      if (newMessages.length < _limit) {
        _hasNext = false; // hết dữ liệu
      }

      _messages.addAll(newMessages); // BE đang sort desc; UI mình sẽ reverse
      _page++;
    } catch (e) {
      _error = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
