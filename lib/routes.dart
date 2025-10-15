import 'package:flutter/material.dart';

import 'controllers/auth_controller.dart';
import 'controllers/home_controller.dart';
import 'controllers/history_controller.dart';

import 'services/bot_repository.dart';
import 'services/history_message_repository.dart';

// import 'views/chat_history_view.dart' as screens; // legacy replaced by HomeView fixedHistoryId
import 'views/splash_view.dart';
import 'views/login_view.dart';
import 'views/home_view.dart';
import 'widgets/drawer_key.dart';
import 'views/chat_image_view.dart';
import 'views/chat_image_premium_view.dart';
import 'views/chat_image_history_view.dart';
import 'views/chat_image_premium_history_view.dart';
import 'services/chat_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'views/account_view.dart';
import 'views/admin_list_view.dart';
import 'views/admin_accounts_view.dart';
import 'views/admin_bots_view.dart';
import 'views/admin_messages_view.dart';
import 'views/admin_payments_view.dart';
import 'views/admin_products_view.dart';
import 'views/usage_view.dart';
import 'views/topup_view.dart';

Route<dynamic> onGenerateRoute(RouteSettings settings, AuthController auth) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(builder: (_) => SplashView(auth: auth));

    case '/login':
      return MaterialPageRoute(builder: (_) => LoginView(auth: auth));

    case '/home':
      final homeController = HomeController(BotRepository());
      final historyController = HistoryController(
        HistoryMessageRepository(),
        auth,
      );
      return MaterialPageRoute(
        builder: (_) => HomeView(
          auth: auth,
          home: homeController,
          history: historyController,
        ),
      );

    case '/account':
      return MaterialPageRoute(builder: (_) => AccountView(auth: auth));

    case '/admin':
      return MaterialPageRoute(builder: (_) => const AdminListView());

    case '/admin/accounts':
      return MaterialPageRoute(builder: (_) => const AdminAccountsView());
    case '/admin/bots':
      return MaterialPageRoute(builder: (_) => const AdminBotsView());
    case '/admin/messages':
      return MaterialPageRoute(builder: (_) => const AdminMessagesView());
    case '/admin/payments':
      return MaterialPageRoute(builder: (_) => const AdminPaymentsView());
    case '/admin/products':
      return MaterialPageRoute(builder: (_) => const AdminProductsView());

    case '/usage':
      return MaterialPageRoute(builder: (_) => UsageView(auth: auth));
    case '/payment':
      // Đã bỏ PaymentView; tạm thời điều hướng về UsageView hoặc trang chủ.
      return MaterialPageRoute(builder: (_) => UsageView(auth: auth));
    case '/topup':
      return MaterialPageRoute(builder: (_) => const TopUpView());

    // Chat by botId (nullable)
    case '/chat':
      final String? botId = (settings.arguments is String)
          ? settings.arguments as String
          : null;
      final homeCtrl = HomeController(BotRepository());
      final historyCtrl = HistoryController(HistoryMessageRepository(), auth);
      return MaterialPageRoute(
        builder: (_) => HomeView(
          auth: auth,
          home: homeCtrl,
          history: historyCtrl,
          initialBotId: botId,
        ),
      );

    // Chat image basic (no file upload)
    case '/chat_image':
      final String? botIdImg = (settings.arguments is String)
          ? settings.arguments as String
          : null;

      final homeCtrlImg = HomeController(BotRepository());
      final historyCtrlImg = HistoryController(
        HistoryMessageRepository(),
        auth,
      );

      return MaterialPageRoute(
        builder: (_) => ChatImageView(
          auth: auth,
          home: homeCtrlImg,
          history: historyCtrlImg,
          botId: botIdImg,
        ),
      );

    // Chat image premium (allow sending images)
    case '/chat_image/premium':
      final String? botIdImgP = (settings.arguments is String)
          ? settings.arguments as String
          : null;

      final homeCtrlImgP = HomeController(BotRepository());
      final historyCtrlImgP = HistoryController(
        HistoryMessageRepository(),
        auth,
      );

      return MaterialPageRoute(
        builder: (_) => ChatImagePremiumView(
          auth: auth,
          home: homeCtrlImgP,
          history: historyCtrlImgP,
          botId: botIdImgP,
        ),
      );

    case '/history':
      // Defensive extraction of historyId.
      String? historyId;
      final arg = settings.arguments;
      if (arg is String && arg.trim().isNotEmpty) {
        historyId = arg.trim();
      }
      if (historyId == null) {
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Lịch sử')),
            body: const Center(child: Text('Không tìm thấy historyId hợp lệ.')),
          ),
        );
      }
      final homeCtrl = HomeController(BotRepository());
      final historyCtrl = HistoryController(HistoryMessageRepository(), auth);
      // We need to determine which view to show based on botId of history messages.
      return MaterialPageRoute(
        builder: (ctx) {
          return FutureBuilder(
            future: _resolveHistoryTarget(historyId!),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Lịch sử')),
                  body: Center(child: Text('Lỗi tải lịch sử: ${snap.error}')),
                );
              }
              final resolved = snap.data; // may be null if resolve failed
              if (resolved == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Lịch sử')),
                  body: Center(
                    child: Text(
                      'Không xác định được kiểu lịch sử ($historyId).',
                    ),
                  ),
                );
              }
              // Instantiate controllers for chosen view.
              switch (resolved.kind) {
                case _HistoryKind.image:
                  return ChatImageHistoryView(
                    auth: auth,
                    home: homeCtrl,
                    history: historyCtrl,
                    historyId: historyId!,
                    botId: resolved.botId,
                  );
                case _HistoryKind.imagePremium:
                  return ChatImagePremiumHistoryView(
                    auth: auth,
                    home: homeCtrl,
                    history: historyCtrl,
                    historyId: historyId!,
                    botId: resolved.botId,
                  );
                case _HistoryKind.text:
                  // TODO: replace with dedicated text history view if needed; reuse HomeView for now
                  return HomeView(
                    auth: auth,
                    home: homeCtrl,
                    history: historyCtrl,
                    fixedHistoryId: historyId!,
                    currentDrawerKey: DrawerKey(
                      DrawerKind.history,
                      id: historyId,
                    ),
                  );
              }
            },
          );
        },
      );

    default:
      return MaterialPageRoute(builder: (_) => SplashView(auth: auth));
  }
}

enum _HistoryKind { text, image, imagePremium }

class _HistoryRouteResolution {
  final _HistoryKind kind;
  final String? botId;
  _HistoryRouteResolution(this.kind, this.botId);
}

Future<_HistoryRouteResolution> _resolveHistoryTarget(String historyId) async {
  try {
    final repo = ChatRepository.fromEnv();
    // Load a small page (limit 1 or 2) to inspect botId.
    final msgs = await repo.loadChatByHistoryId(historyId, limit: 2);
    if (msgs.isEmpty) return _HistoryRouteResolution(_HistoryKind.text, null);
    String? botId = msgs.first.botId;
    for (final m in msgs) {
      if (m.botId != null && m.botId!.isNotEmpty) {
        botId = m.botId;
        break;
      }
    }
    final imgId = dotenv.env['CREATE_IMAGE']?.trim();
    final imgPremiumId = dotenv.env['CREATE_IMAGE_PREMIUM']?.trim();
    if (botId != null && botId.isNotEmpty) {
      if (imgPremiumId != null &&
          imgPremiumId.isNotEmpty &&
          botId == imgPremiumId) {
        return _HistoryRouteResolution(_HistoryKind.imagePremium, botId);
      }
      if (imgId != null && imgId.isNotEmpty && botId == imgId) {
        return _HistoryRouteResolution(_HistoryKind.image, botId);
      }
    }
    return _HistoryRouteResolution(_HistoryKind.text, botId);
  } catch (_) {
    return _HistoryRouteResolution(_HistoryKind.text, null);
  }
}
