import 'chat_repository.dart';

class MessageService {
  final ChatRepository repo;
  MessageService(this.repo);

  Future<void> attachHistoryIfNeeded({
    required String messageId,
    required String? previousHistory,
    required String newHistory,
  }) async {
    if ((previousHistory == null || previousHistory.isEmpty) &&
        newHistory.isNotEmpty) {
      await repo.updateMessageHistory(
        messageId: messageId,
        historyId: newHistory,
      );
    }
  }

  Future<void> rateMessage(String messageId, int status) async {
    await repo.updateMessageStatus(messageId: messageId, status: status);
  }
}
