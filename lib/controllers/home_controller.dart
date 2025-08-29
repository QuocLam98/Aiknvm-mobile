import 'package:flutter/foundation.dart';
import '../models/bot_model.dart';
import '../services/bot_repository.dart';

class HomeController extends ChangeNotifier {
  final BotRepository _repo;
  HomeController(this._repo);

  BotModel? _bot;
  bool _busy = false;
  String? _error;

  // Cache danh sách bot để FutureBuilder không gọi API nhiều lần
  Future<List<BotModel>>? _botsFuture;

  BotModel? get bot => _bot;
  bool get busy => _busy;
  String? get error => _error;

  /// Gọi khi vào màn để lấy bot mặc định
  Future<void> loadDefaultBot() async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      _bot = await _repo.getDefaultBot();
    } catch (e) {
      _error = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Alias nếu bạn cần refresh lại bot mặc định
  Future<void> refresh({String? bearerToken}) => loadDefaultBot();

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// Lấy tất cả bot (có cache Future)
  Future<List<BotModel>> getAllBots() {
    _botsFuture ??= _repo.getAllBots();
    return _botsFuture!;
  }

  /// Buộc làm mới danh sách bot (nếu bạn muốn có nút Reload trong UI)
  Future<List<BotModel>> reloadBots() {
    _botsFuture = _repo.getAllBots();
    return _botsFuture!;
  }

  /// Chọn bot đang dùng và cập nhật UI
  Future<void> setBot(BotModel newBot) async {
    // Nếu muốn gọi API lấy detail bot ở đây, có thể unwrap thêm:
    // final detail = await _repo.getBotDetail(newBot.id);
    // _bot = detail;
    _bot = newBot;
    notifyListeners();
  }

  /// Chọn bot theo id (nếu menu trả id)
  Future<void> loadBotById(String botId) async {
    try {
      _busy = true;
      _error = null;
      notifyListeners();

      final bot = await _repo.getBotById(botId);
      _bot = bot;
    } catch (e) {
      _error = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
