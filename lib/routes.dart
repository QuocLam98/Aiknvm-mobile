import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'controllers/auth_controller.dart';
import 'controllers/home_controller.dart';
import 'controllers/history_controller.dart';

import 'services/bot_repository.dart';
import 'services/history_message_repository.dart';
import 'services/chat_repository.dart';
import 'controllers/chat_controller.dart';

import 'views/chat_history_view.dart' as screens;
import 'views/splash_view.dart';
import 'views/login_view.dart';
import 'views/home_view.dart';
import 'views/chat_view.dart';
import 'views/chat_image_view.dart';
import 'views/chat_image_premium_view.dart';
import 'views/account_view.dart';
import 'views/admin_list_view.dart';
import 'views/admin_accounts_view.dart';
import 'views/admin_bots_view.dart';
import 'views/admin_messages_view.dart';
import 'views/admin_payments_view.dart';
import 'views/admin_products_view.dart';

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
      return MaterialPageRoute(
        builder: (_) => AccountView(auth: auth),
      );

    case '/admin':
      return MaterialPageRoute(
        builder: (_) => const AdminListView(),
      );

    case '/admin/accounts':
      return MaterialPageRoute(
        builder: (_) => const AdminAccountsView(),
      );
    case '/admin/bots':
      return MaterialPageRoute(
        builder: (_) => const AdminBotsView(),
      );
    case '/admin/messages':
      return MaterialPageRoute(
        builder: (_) => const AdminMessagesView(),
      );
    case '/admin/payments':
      return MaterialPageRoute(
        builder: (_) => const AdminPaymentsView(),
      );
    case '/admin/products':
      return MaterialPageRoute(
        builder: (_) => const AdminProductsView(),
      );

    // Chat by botId (nullable)
    case '/chat':
      final String? botId =
          (settings.arguments is String) ? settings.arguments as String : null;

      final homeCtrl = HomeController(BotRepository());
      final historyCtrl = HistoryController(HistoryMessageRepository(), auth);

      return MaterialPageRoute(
        builder: (_) => ChatView(
          auth: auth,
          home: homeCtrl,
          history: historyCtrl,
          botId: botId,
        ),
      );

    // Chat image basic (no file upload)
    case '/chat_image':
      final String? botIdImg =
          (settings.arguments is String) ? settings.arguments as String : null;

      final homeCtrlImg = HomeController(BotRepository());
      final historyCtrlImg = HistoryController(HistoryMessageRepository(), auth);

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
      final String? botIdImgP =
          (settings.arguments is String) ? settings.arguments as String : null;

      final homeCtrlImgP = HomeController(BotRepository());
      final historyCtrlImgP = HistoryController(HistoryMessageRepository(), auth);

      return MaterialPageRoute(
        builder: (_) => ChatImagePremiumView(
          auth: auth,
          home: homeCtrlImgP,
          history: historyCtrlImgP,
          botId: botIdImgP,
        ),
      );

    case '/history':
      final historyId = settings.arguments as String;

      final homeCtrl = HomeController(BotRepository());
      final historyCtrl = HistoryController(HistoryMessageRepository(), auth);

      final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
      if (baseUrl.isEmpty) {
        throw StateError('Thiếu API_BASE_URL trong .env');
      }

      final chatRepo = ChatRepository(baseUrl);
      final chatCtrl = ChatController(chatRepo, historyId: historyId);

      return MaterialPageRoute(
        builder: (_) => screens.HistoryChatView(
          ctrl: chatCtrl,
          historyId: historyId,
          auth: auth,
          home: homeCtrl,
          history: historyCtrl,
        ),
      );

    default:
      return MaterialPageRoute(builder: (_) => SplashView(auth: auth));
  }
}
