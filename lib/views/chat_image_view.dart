import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/history_controller.dart';
import '../models/bot_model.dart';
import '../models/chat_message_model.dart';
import '../widgets/app_drawer.dart';
import '../widgets/drawer_key.dart';
import '../services/chat_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../widgets/top_toast.dart';

class ChatImageView extends StatefulWidget {
  final AuthController auth;
  final HomeController home;
  final HistoryController history;
  final String? botId;

  const ChatImageView({
    super.key,
    required this.auth,
    required this.home,
    required this.history,
    this.botId,
  });

  @override
  State<ChatImageView> createState() => _ChatImageViewState();
}

class _ProgressiveImage extends StatefulWidget {
  final String url;
  final double width;
  final double borderRadius;
  const _ProgressiveImage({
    required this.url,
    required this.width,
    this.borderRadius = 12,
  });

  @override
  State<_ProgressiveImage> createState() => _ProgressiveImageState();
}

class _ProgressiveImageState extends State<_ProgressiveImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AnimatedBuilder(
        animation: _fade,
        builder: (_, __) {
          final factor = _fade.value; // 0 -> 1
          return Stack(
            children: [
              if (!_started)
                Container(
                  width: widget.width,
                  height: widget.width,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFE9ECF1), Color(0xFFF7F9FC)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: factor.clamp(0.0, 1.0),
                  child: Opacity(
                    opacity: factor,
                    child: Image.network(
                      widget.url,
                      width: widget.width,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 220,
                        height: 120,
                        child: Center(child: Icon(Icons.broken_image)),
                      ),
                      loadingBuilder: (c, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox.shrink();
                      },
                      frameBuilder: (c, child, frame, wasSync) {
                        if (frame != null && !_started) {
                          _started = true;
                          _controller.forward();
                        }
                        return child;
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChatImageViewState extends State<ChatImageView> {
  final _inputCtrl = TextEditingController();
  late Future<BotModel> _botFuture;
  final ScrollController _listCtrl = ScrollController();
  final List<ChatMessageModel> _messages = [];
  bool _sending = false;
  String? _historyId;

  @override
  void initState() {
    super.initState();
    _botFuture = _loadBot();
    // Always start a new chat: no fixed history loading here.
  }

  Future<BotModel> _loadBot() async {
    if (widget.botId != null && widget.botId!.isNotEmpty) {
      final bot = await widget.home.loadBotById(widget.botId!);
      await widget.home.setBot(bot);
      return bot;
    }
    await widget.home.loadDefaultBot();
    final bot = widget.home.bot;
    if (bot == null) throw Exception('Không lấy được bot mặc định');
    await widget.home.setBot(bot);
    return bot;
  }

  void _handleDrawerSelect(DrawerKey key) {
    switch (key.kind) {
      case DrawerKind.chat:
        Navigator.pushReplacementNamed(context, '/chat');
        break;
      case DrawerKind.usage:
        Navigator.pushNamed(context, '/usage');
        break;
      case DrawerKind.adminUsers:
        Navigator.pushNamed(context, '/admin/users');
        break;
      case DrawerKind.adminConfig:
        Navigator.pushNamed(context, '/admin/config');
        break;
      case DrawerKind.bot:
        if (key.id == null) return;
        final id = key.id!;
        if (id == widget.botId) return;
        final imgId = dotenv.env['CREATE_IMAGE']?.trim();
        final imgPremiumId = dotenv.env['CREATE_IMAGE_PREMIUM']?.trim();
        if (imgId != null && imgId.isNotEmpty && id == imgId) {
          Navigator.pushReplacementNamed(context, '/chat_image', arguments: id);
        } else if (imgPremiumId != null &&
            imgPremiumId.isNotEmpty &&
            id == imgPremiumId) {
          Navigator.pushReplacementNamed(
            context,
            '/chat_image/premium',
            arguments: id,
          );
        } else {
          Navigator.pushReplacementNamed(context, '/chat', arguments: id);
        }
        break;
      case DrawerKind.history:
        Navigator.pushNamed(context, '/history', arguments: key.id);
        break;
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    final home = widget.home;
    final history = widget.history;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: .5,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: FutureBuilder<BotModel>(
          future: _botFuture,
          builder: (_, s) {
            if (!s.hasData)
              return const Text(
                'Đang tải...',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              );
            final bot = s.data!;
            return Row(
              children: [
                if (bot.image != null && bot.image!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        bot.image!,
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.smart_toy, color: Colors.black87),
                      ),
                    ),
                  ),
                Expanded(
                  child: Tooltip(
                    message: bot.name,
                    waitDuration: const Duration(milliseconds: 400),
                    child: Text(
                      _shortName(bot.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      drawer: AppDrawer(
        auth: auth,
        home: home,
        history: history,
        current: (widget.botId != null && widget.botId!.isNotEmpty)
            ? DrawerKey(DrawerKind.bot, id: widget.botId)
            : const DrawerKey(DrawerKind.chat),
        onSelect: _handleDrawerSelect,
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<BotModel>(
              future: _botFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Lỗi: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _listCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final isUser = m.role == 'user';
                    return _bubble(m, isUser: isUser);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(.4),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _sending
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          final text = _inputCtrl.text.trim();
                          if (text.isEmpty) return;
                          _send(text);
                        },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shortName(String name) {
    final trimmed = name.trim();
    if (trimmed.length <= 18) return trimmed;
    return trimmed.substring(0, 16) + '…';
  }

  Future<void> _send(String text) async {
    final userId = widget.auth.user?.id;
    final botId = widget.home.bot?.id;
    if (userId == null || userId.isEmpty || botId == null || botId.isEmpty) {
      TopToast.error(context, 'Thiếu user hoặc bot');
      return;
    }
    setState(() => _sending = true);
    final localUserMsg = ChatMessageModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}_u',
      text: text,
      role: 'user',
      createdAt: DateTime.now(),
      botId: botId,
    );
    ChatMessageModel? placeholder;
    setState(() {
      _messages.add(localUserMsg);
      // Add bot placeholder '…' while waiting for image URL
      placeholder = ChatMessageModel(
        id: 'placeholder_${DateTime.now().millisecondsSinceEpoch}',
        text: '…',
        role: 'bot',
        createdAt: DateTime.now(),
        botId: botId,
      );
      _messages.add(placeholder!);
      _inputCtrl.clear();
    });
    try {
      final repo = ChatRepository.fromEnv();
      final res = await repo.createMessageImageMobile(
        userId: userId,
        botId: botId,
        content: text,
        historyChat: _historyId,
      );
      if (!mounted) return;
      setState(() {
        _historyId ??= res.history;
        // Replace placeholder with final image message
        final idx = placeholder == null
            ? -1
            : _messages.indexWhere((m) => m.id == placeholder!.id);
        final botMsg = ChatMessageModel(
          id: '${res.id}_b',
          text: '',
          role: 'bot',
          createdAt: res.createdAt,
          fileUrl: res.contentBot,
          fileType: 'image/auto',
          botId: botId,
        );
        if (idx >= 0) {
          _messages[idx] = botMsg;
        } else {
          _messages.add(botMsg);
        }
      });
      if (_historyId != null && _historyId!.isNotEmpty) {
        try {
          await repo.updateMessageHistory(
            messageId: res.id,
            historyId: _historyId!,
          );
        } catch (_) {}
        try {
          await widget.history.refreshHistory();
        } catch (_) {}
      }
      await Future.delayed(const Duration(milliseconds: 30));
      if (_listCtrl.hasClients) {
        _listCtrl.jumpTo(_listCtrl.position.maxScrollExtent);
      }
    } catch (e) {
      if (!mounted) return;
      TopToast.error(context, 'Gửi thất bại: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _bubble(ChatMessageModel m, {required bool isUser}) {
    final bg = isUser ? Colors.black : const Color(0xFFEFF3F8);
    final fg = isUser ? Colors.white : Colors.black87;
    final align = isUser ? MainAxisAlignment.end : MainAxisAlignment.start;
    final children = <Widget>[];

    if (m.text.isNotEmpty) {
      children.add(
        Row(
          mainAxisAlignment: align,
          children: [
            IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: m.text == '…' ? 12 : 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: (m.text == '…')
                        ? Row(
                            key: const ValueKey('placeholder'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isUser ? Colors.white : Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            m.text,
                            key: const ValueKey('text'),
                            style: TextStyle(color: fg, fontSize: 14),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!isUser && (m.fileUrl != null && m.fileUrl!.isNotEmpty)) {
      children.add(
        Row(
          mainAxisAlignment: align,
          children: [
            Stack(
              children: [
                GestureDetector(
                  onTap: () => _openImage(m.fileUrl!),
                  child: _ProgressiveImage(
                    url: _absUrl(m.fileUrl!),
                    width: 220,
                    borderRadius: 10,
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _downloadImage(m.fileUrl!),
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.download_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            children[i],
          ],
        ],
      ),
    );
  }

  void _openImage(String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(.9),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: Center(
              child: Image.network(
                _absUrl(url),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _absUrl(String url) {
    final u = url.trim();
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    // Không có BASE_URL ở đây: tái sử dụng biến môi trường nếu cần trong tương lai.
    return u;
  }

  Future<void> _downloadImage(String url) async {
    try {
      final uri = Uri.parse(_absUrl(url));
      final resp = await http.get(uri);
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final bytes = resp.bodyBytes;
      final dir = await getTemporaryDirectory();
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = await File('${dir.path}/$fileName').writeAsBytes(bytes);
      if (!mounted) return;
      TopToast.success(context, 'Đã tải xuống: ${file.path.split('/').last}');
    } catch (e) {
      if (!mounted) return;
      TopToast.error(context, 'Tải xuống thất bại: $e');
    }
  }
}
