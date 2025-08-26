import 'package:flutter/foundation.dart';
import '../models/bot_model.dart';
import '../services/bot_repository.dart';

class HomeController extends ChangeNotifier {
  final BotRepository _repo;
  HomeController(this._repo);

  BotModel? _bot;
  bool _busy = false;
  String? _error;

  BotModel? get bot => _bot;
  bool get busy => _busy;
  String? get error => _error;

  Future<void> loadDefaultBot({String? bearerToken}) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      _bot = await _repo.getDefaultBot(bearerToken: bearerToken);
    } catch (e) {
      _error = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> refresh({String? bearerToken}) => loadDefaultBot(bearerToken: bearerToken);

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}
