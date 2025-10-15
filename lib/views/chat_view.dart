import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../widgets/top_toast.dart';
import 'dart:io';
import 'package:flutter/services.dart';

import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/history_controller.dart';
import '../models/bot_model.dart';
import '../models/chat_message_model.dart';
import '../widgets/app_drawer.dart';
import '../widgets/drawer_key.dart';
import '../services/chat_repository.dart';

class ChatView extends StatefulWidget {
  final AuthController auth;
  final HomeController home;
  final HistoryController history;
  final String? botId; // null => dùng bot mặc định

  const ChatView({
    super.key,
    required this.auth,
    required this.home,
    required this.history,
    this.botId,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _inputCtrl = TextEditingController();
  late Future<BotModel> _botFuture;
  final ScrollController _listCtrl = ScrollController();
  final List<ChatMessageModel> _messages = [];
  bool _sending = false;
  String? _selectedModel; // dropdown selection

  String _shortName(String name) {
    final t = name.trim();
    if (t.length <= 18) return t;
    return t.substring(0, 16) + '…';
  }

  @override
  void initState() {
    super.initState();
    _botFuture = _loadBot();
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
        // Ưu tiên bot CREATE_IMAGE trước
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
        automaticallyImplyLeading: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: FutureBuilder<BotModel>(
          future: _botFuture,
          builder: (_, snapshot) {
            if (!snapshot.hasData) {
              return const Text(
                'Đang tải...',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              );
            }
            final bot = snapshot.data!;
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
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
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

      body: FutureBuilder<BotModel>(
        future: _botFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lỗi: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => setState(() => _botFuture = _loadBot()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final bot = snapshot.data!;
          return LayoutBuilder(
            builder: (context, constraints) {
              // Show initial info when no messages else show list
              if (_messages.isEmpty) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 40,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: (bot.image != null && bot.image!.isNotEmpty)
                              ? Image.network(
                                  bot.image!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.smart_toy, size: 64),
                                )
                              : const ColoredBox(
                                  color: Color(0xFFEFF3F8),
                                  child: Icon(Icons.smart_toy, size: 64),
                                ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          bot.name.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (bot.description.isNotEmpty == true)
                              ? bot.description
                              : '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color?.withOpacity(.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                controller: _listCtrl,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final m = _messages[i];
                  final isUser = m.role == 'user';
                  return _bubble(m, isUser: isUser);
                },
              );
            },
          );
        },
      ),

      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
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
                  // Top row: model selector + attachments
                  Row(
                    children: [
                      _buildModelDropdown(),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Ảnh',
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: [
                              'png',
                              'jpg',
                              'jpeg',
                              'webp',
                              'gif',
                            ],
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final f = result.files.first;
                            debugPrint('Ảnh được chọn: ${f.name} - ${f.path}');
                          }
                        },
                        icon: const Icon(Icons.image_outlined),
                      ),
                      IconButton(
                        tooltip: 'Tài liệu',
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final f = result.files.first;
                            debugPrint(
                              'Tài liệu được chọn: ${f.name} - ${f.path}',
                            );
                          }
                        },
                        icon: const Icon(Icons.description_outlined),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Theme.of(context).dividerColor.withOpacity(.25),
                    ),
                  ),
                  // Bottom row: rounded text input + circular send
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withOpacity(.8),
                            borderRadius: BorderRadius.circular(12),
                            // Removed border per request (no visible input border)
                          ),
                          child: TextField(
                            controller: _inputCtrl,
                            minLines: 1,
                            maxLines: 5,
                            scrollPadding: const EdgeInsets.only(bottom: 120),
                            decoration: const InputDecoration(
                              hintText: 'Nhập tin nhắn...',
                              isDense: true,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () async {
                            FocusScope.of(context).unfocus();
                            final text = _inputCtrl.text.trim();
                            if (text.isEmpty) return;
                            final userId = widget.auth.user?.id;
                            final botId = widget.home.bot?.id;
                            if (userId == null ||
                                botId == null ||
                                userId.isEmpty ||
                                botId.isEmpty)
                              return;
                            setState(() {
                              _sending = true;
                              _messages.add(
                                ChatMessageModel(
                                  id: 'local_${DateTime.now().millisecondsSinceEpoch}_u',
                                  text: text,
                                  role: 'user',
                                  createdAt: DateTime.now(),
                                  botId: botId,
                                ),
                              );
                            });
                            _inputCtrl.clear();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_listCtrl.hasClients) {
                                _listCtrl.jumpTo(
                                  _listCtrl.position.maxScrollExtent,
                                );
                              }
                            });
                            try {
                              final repo = ChatRepository.fromEnv();
                              final model =
                                  _selectedModel ??
                                  (_availableModelsFor(
                                        widget.home.bot,
                                      ).isNotEmpty
                                      ? _availableModelsFor(
                                          widget.home.bot,
                                        ).first['value']
                                      : null);
                              final isGemini = (model ?? '').startsWith(
                                'gemini',
                              );
                              final res = isGemini
                                  ? await repo.createMessageMobileGemini(
                                      userId: userId,
                                      botId: botId,
                                      content: text,
                                      historyChat: null,
                                      model: model,
                                    )
                                  : await repo.createMessageMobileGpt(
                                      userId: userId,
                                      botId: botId,
                                      content: text,
                                      historyChat: null,
                                      model: model,
                                    );
                              if (!mounted) return;
                              setState(() {
                                _messages.add(
                                  ChatMessageModel(
                                    id: '${res.id}_b',
                                    text: res.contentBot,
                                    role: 'bot',
                                    createdAt: res.createdAt,
                                    botId: botId,
                                  ),
                                );
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_listCtrl.hasClients) {
                                  _listCtrl.jumpTo(
                                    _listCtrl.position.maxScrollExtent,
                                  );
                                }
                              });
                            } catch (_) {
                              if (!mounted) return;
                              setState(() => _sending = false);
                            } finally {
                              if (mounted) setState(() => _sending = false);
                            }
                          },
                          child: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===== Model dropdown helpers (compact) =====
  Widget _buildModelDropdown() {
    final options = _availableModelsFor(widget.home.bot);
    final current = _selectedModel;
    final contains = options.any((o) => o['value'] == current);
    final value = contains
        ? current
        : (options.isNotEmpty ? options.first['value'] : null);
    final label = options.firstWhere(
      (o) => o['value'] == value,
      orElse: () => (options.isNotEmpty
          ? options.first
          : const {'label': 'Model', 'value': ''}),
    )['label'];

    return InputChip(
      label: Text(label ?? 'Model'),
      avatar: const Icon(Icons.tune, size: 16),
      onPressed: options.isEmpty
          ? null
          : () async {
              final selected = await showModalBottomSheet<String>(
                context: context,
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) {
                  return SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          height: 4,
                          width: 36,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...options.map(
                          (o) => ListTile(
                            title: Text(o['label'] ?? ''),
                            trailing: (o['value'] == value)
                                ? const Icon(Icons.check, color: Colors.green)
                                : null,
                            onTap: () => Navigator.of(context).pop(o['value']),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              );
              if (selected != null && selected != _selectedModel) {
                setState(() => _selectedModel = selected);
              }
            },
      visualDensity: VisualDensity.compact,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  List<Map<String, String>> _availableModelsFor(BotModel? bot) {
    const gemini = [
      {'value': 'gemini-2.5-flash', 'label': 'Gemini Flash'},
      {'value': 'gemini-2.5-pro', 'label': 'Gemini Pro'},
    ];
    const gpt = [
      {'value': 'gpt-5', 'label': 'GPT-5'},
      {'value': 'gpt-5-mini', 'label': 'GPT-5 mini'},
    ];
    final type = (bot?.models)?.toString();
    switch (type) {
      case '1':
        return gemini;
      case '2':
        return gpt;
      case '3':
        return [...gemini, ...gpt];
      default:
        return gemini;
    }
  }

  // ---------- Bubble helpers (dùng khi render messages) ----------
  Widget _bubble(ChatMessageModel m, {required bool isUser}) {
    final bg = isUser ? Colors.black : const Color(0xFFEFF3F8);
    final fg = isUser ? Colors.white : Colors.black87;
    final align = isUser ? MainAxisAlignment.end : MainAxisAlignment.start;

    final blocks = <Widget>[];

    if (m.text.isNotEmpty) {
      blocks.add(
        Row(
          mainAxisAlignment: align,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        m.text,
                        style: TextStyle(color: fg, fontSize: 14),
                      ),
                    ),
                    if (!isUser)
                      IconButton(
                        tooltip: 'Sao chép',
                        splashRadius: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: m.text));
                          if (context.mounted) {
                            TopToast.success(context, 'Đã sao chép nội dung');
                          }
                        },
                        icon: Icon(Icons.copy, color: fg, size: 16),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (m.fileUrl != null && m.fileUrl!.isNotEmpty) {
      final isImg = _isImageType(m.fileType, m.fileUrl);
      if (isImg) {
        blocks.add(
          Row(
            mainAxisAlignment: align,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: GestureDetector(
                  onTap: () => _openImageViewer(_absUrl(m.fileUrl!)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _absUrl(m.fileUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        final icon = _iconForFileType(m.fileType, m.fileUrl);
        final name = _filenameFromUrl(m.fileUrl!);
        blocks.add(
          Row(
            mainAxisAlignment: align,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _onFileTap(_absUrl(m.fileUrl!), m.fileType),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: fg),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(color: fg),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            blocks[i],
          ],
        ],
      ),
    );
  }

  bool _isImageType(String? fileType, String? url) {
    final t = (fileType ?? '').toLowerCase();
    if (t.contains('image')) return true;
    final u = (url ?? '').toLowerCase();
    return u.endsWith('.png') ||
        u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.webp') ||
        u.endsWith('.gif');
  }

  IconData _iconForFileType(String? fileType, String? url) {
    final t = (fileType ?? '').toLowerCase();
    final u = (url ?? '').toLowerCase();
    if (t.contains('pdf') || u.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (t.contains('doc') || u.endsWith('.doc') || u.endsWith('.docx'))
      return Icons.description;
    if (t.contains('txt') || u.endsWith('.txt')) return Icons.description;
    return Icons.insert_drive_file;
  }

  String _filenameFromUrl(String url) {
    final idx = url.lastIndexOf('/');
    if (idx == -1 || idx == url.length - 1) return url;
    return url.substring(idx + 1);
  }

  String _absUrl(String url) {
    final u = url.trim();
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    final base = (dotenv.env['API_BASE_URL'] ?? '').trim();
    if (base.isEmpty) return u;
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    if (u.startsWith('/')) return '$b$u';
    return '$b/$u';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(_absUrl(url));
    if (uri == null) return;
    try {
      bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) ok = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      if (!ok) ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {}
  }

  void _openImageViewer(String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(.9),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: InteractiveViewer(
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, color: Colors.white),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isDownloadPreferredType(String? fileType, String? url) {
    final t = (fileType ?? '').toLowerCase();
    final u = (url ?? '').toLowerCase();
    return t.contains('pdf') ||
        t.contains('doc') ||
        t.contains('msword') ||
        t.contains('officedocument') ||
        t.contains('txt') ||
        u.endsWith('.pdf') ||
        u.endsWith('.doc') ||
        u.endsWith('.docx') ||
        u.endsWith('.txt');
  }

  Future<void> _onFileTap(String url, String? fileType) async {
    if (_isDownloadPreferredType(fileType, url)) {
      final action = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Tệp đính kèm'),
          content: const Text('Bạn muốn tải xuống hay mở tệp này?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('open'),
              child: const Text('Mở'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('download'),
              child: const Text('Tải xuống'),
            ),
          ],
        ),
      );

      if (action == 'download') {
        await _downloadFile(url);
        return;
      }
      if (action == 'open') {
        await _openUrl(url);
        return;
      }
      return;
    }
    await _openUrl(url);
  }

  Future<Directory> _resolveDownloadDir() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      if (dirs != null && dirs.isNotEmpty) return dirs.first;
      final d = await getExternalStorageDirectory();
      if (d != null) return d;
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<void> _downloadFile(String url) async {
    try {
      final uri = Uri.parse(_absUrl(url));
      final token = widget.auth.session?.jwt;
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');

      final dir = await _resolveDownloadDir();
      final name = _filenameFromUrl(url);
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(resp.bodyBytes);

      if (!mounted) return;
      TopToast.success(context, 'Đã tải xuống: ${file.path}');
    } catch (e) {
      if (!mounted) return;
      TopToast.error(context, 'Tải xuống thất bại');
    }
  }
}
