import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/bot.dart';
import '../services/api_client.dart';

class ChatController {
  final messages = ValueNotifier<List<Message>>([]);
  final typing = ValueNotifier<bool>(false);

  final bots = ValueNotifier<List<Bot>>([]);
  final selectedBot = ValueNotifier<Bot?>(null);

  final _api = ApiClient();

  ChatController() {
    _init();
  }

  Future<void> _init() async {
    messages.value = [
      const Message(
        id: 'welcome',
        text: 'Hello! 👋 Loading bots…',
        time: null,
        owner: MessageOwner.bot,
      ),
    ];
    await loadBots();
  }

  Future<void> loadBots() async {
    try {
      final list = await _api.getBots(); // '/list-bot'
      bots.value = list;
      if (list.isEmpty) {
        messages.value = [
          ...messages.value,
          Message(
            id: 'no-bot',
            text: '⚠️ No active bot found.',
            time: DateTime.now(),
            owner: MessageOwner.bot,
          ),
        ];
        return;
      }
      selectedBot.value = list.first;
      // thêm gợi ý templateMessage nếu có
      final tmpl = selectedBot.value?.templateMessage.trim();
      if (tmpl != null && tmpl.isNotEmpty) {
        messages.value = [
          ...messages.value,
          Message(
            id: 'tmpl',
            text: 'Tip • ${selectedBot.value!.name}: $tmpl',
            time: DateTime.now(),
            owner: MessageOwner.bot,
          ),
        ];
      }
    } catch (e) {
      messages.value = [
        ...messages.value,
        Message(
          id: 'err',
          text: '⚠️ Cannot load bots: $e',
          time: DateTime.now(),
          owner: MessageOwner.bot,
        ),
      ];
    }
  }

  void changeBot(Bot bot) {
    selectedBot.value = bot;
    final tmpl = bot.templateMessage.trim();
    messages.value = [
      ...messages.value,
      Message(
        id: 'bot-change-${bot.name}',
        text: 'Switched to bot: ${bot.name}${tmpl.isNotEmpty ? '\nTip • $tmpl' : ''}',
        time: DateTime.now(),
        owner: MessageOwner.bot,
      ),
    ];
  }

  void send(String text) async {
    if (text.trim().isEmpty) return;

    messages.value = [
      ...messages.value,
      Message(
        id: UniqueKey().toString(),
        text: text.trim(),
        time: DateTime.now(),
        owner: MessageOwner.me,
      ),
    ];

    // TODO: thay phần echo này bằng call API chat thực sự
    typing.value = true;
    await Future.delayed(const Duration(milliseconds: 500));
    messages.value = [
      ...messages.value,
      Message(
        id: UniqueKey().toString(),
        text: '[${selectedBot.value?.name ?? 'Bot'}] echo: $text',
        time: DateTime.now(),
        owner: MessageOwner.bot,
      ),
    ];
    typing.value = false;
  }

  void dispose() {
    messages.dispose();
    typing.dispose();
    bots.dispose();
    selectedBot.dispose();
  }
}
