import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:typed_data';

import '../navigation.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/history_controller.dart';
import '../models/bot_model.dart';
import '../models/chat_message_model.dart';
import '../widgets/app_drawer.dart';
import '../widgets/drawer_key.dart';
import '../services/chat_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../widgets/top_toast.dart';

class HomeView extends StatefulWidget {
  final AuthController auth;
  final HomeController home;
  final HistoryController history;
  final String? initialBotId; // optional bot to pre-select
  final DrawerKey? currentDrawerKey; // override drawer highlight
  final String?
  fixedHistoryId; // when provided, load existing history messages and always send with this id

  const HomeView({
    super.key,
    required this.auth,
    required this.home,
    required this.history,
    this.initialBotId,
    this.currentDrawerKey,
    this.fixedHistoryId,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView>
    with RouteAware, SingleTickerProviderStateMixin {
  final List<ChatMessageModel> _messages = [];
  final ScrollController _listCtrl = ScrollController();
  final TextEditingController _inputCtrl = TextEditingController();
  String? _selectedModel; // dropdown selection for model
  String? _historyId;
  bool _sending = false;

  late final AnimationController _typingController;
  bool get _showTyping =>
      _sending && _messages.isNotEmpty && _messages.last.role == 'user';
  // Attachments & streaming state
  final List<_PendingAttachment> _attachments = [];
  static const Set<String> _allowedImageMimes = {
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/gif',
  };
  static const Set<String> _allowedDocMimes = {
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain',
  };
  Map<String, int> _messageStatus = {};
  Timer? _streamTimer;
  String _streamFull = '';
  bool _streaming = false;

  bool get _hasAttachment => _attachments.isNotEmpty;
  bool get _anyUploading => _attachments.any((a) => a.uploading);

  void _removeAttachment(String id) {
    setState(() {
      _attachments.removeWhere((a) => a.id == id);
    });
  }

  void _clearAllAttachments() => setState(() => _attachments.clear());

  Future<void> _pickAndUploadSingle({required bool image}) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: image
            ? const ['jpg', 'jpeg', 'png', 'webp', 'gif']
            : const ['pdf', 'docx', 'txt'],
      );
    } catch (e) {
      if (!mounted) return;
      TopToast.error(context, 'Không chọn được file: $e');
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.path == null) return;
    final mime = _inferSimpleMime(f.name);
    if (!_isAllowedMime(mime)) {
      TopToast.error(context, 'Loại file không hỗ trợ: ${f.name}');
      return;
    }
    final att = _PendingAttachment(
      id: 'att_${DateTime.now().microsecondsSinceEpoch}_${f.name}',
      file: File(f.path!),
      name: f.name,
      mime: mime,
    );
    setState(() => _attachments.add(att));
    _uploadAttachment(att);
  }

  Future<void> _uploadAttachment(_PendingAttachment att) async {
    setState(() => att.uploading = true);
    try {
      final repo = ChatRepository.fromEnv();
      final url = await repo.uploadChatFile(att.file);
      if (!mounted) return;
      setState(() {
        att.url = url;
        att.uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        att.uploading = false;
        att.error = 'Upload lỗi';
      });
      TopToast.error(context, 'Upload thất bại ${att.name}: $e');
    }
  }

  String _inferSimpleMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }

  bool _isAllowedMime(String mime) =>
      _allowedImageMimes.contains(mime) || _allowedDocMimes.contains(mime);

  @override
  void initState() {
    super.initState();
    widget.home.loadDefaultBot();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    // If a specific bot is requested (from /chat route), load it.
    final botId = widget.initialBotId;
    if (botId != null && botId.isNotEmpty) {
      // Fire-and-forget; HomeController will notify listeners when loaded.
      scheduleMicrotask(() async {
        try {
          final bot = await widget.home.loadBotById(botId);
          await widget.home.setBot(bot);
        } catch (_) {
          // ignore errors here; UI can show retry if needed
        }
      });
    }
    // Load existing history if fixedHistoryId specified
    if (widget.fixedHistoryId != null && widget.fixedHistoryId!.isNotEmpty) {
      scheduleMicrotask(_loadFixedHistory);
    }
  }

  Future<void> _loadFixedHistory() async {
    try {
      final repo = ChatRepository.fromEnv();
      final historyId = widget.fixedHistoryId!;
      final loaded = await repo.loadChatByHistoryId(historyId, limit: 50);
      // populate status map and determine botId
      String? botId;
      for (final m in loaded) {
        if (m.role == 'bot' && m.status != null) {
          _messageStatus[m.id] = m.status!;
        }
        botId ??= m.botId;
      }
      if (botId != null && botId.isNotEmpty) {
        try {
          final bot = await widget.home.loadBotById(botId);
          await widget.home.setBot(bot);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(loaded);
        _historyId = historyId; // set current history
      });
      // Scroll to bottom after a frame
      await Future.delayed(const Duration(milliseconds: 50));
      if (_listCtrl.hasClients) {
        _listCtrl.jumpTo(_listCtrl.position.maxScrollExtent);
      }
    } catch (e) {
      if (!mounted) return;
      TopToast.error(context, 'Tải lịch sử thất bại: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    setState(() {
      _messages.clear();
      _historyId = null;
      _inputCtrl.clear();
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _streamTimer?.cancel();
    _typingController.dispose();
    _listCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _handleDrawerSelect(DrawerKey key) {
    switch (key.kind) {
      case DrawerKind.chat:
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
        final imgId = dotenv.env['CREATE_IMAGE']?.trim();
        final imgPremiumId = dotenv.env['CREATE_IMAGE_PREMIUM']?.trim();
        if (imgId != null && imgId.isNotEmpty && id == imgId) {
          Navigator.pushReplacementNamed(context, '/chat_image', arguments: id);
          return;
        }
        if (imgPremiumId != null &&
            imgPremiumId.isNotEmpty &&
            id == imgPremiumId) {
          Navigator.pushReplacementNamed(
            context,
            '/chat_image/premium',
            arguments: id,
          );
          return;
        }
        () async {
          if (widget.home.bot?.id != id) {
            try {
              await widget.home.loadBotById(id);
            } catch (_) {}
          }
          if (!mounted) return;
          setState(() {
            _messages.clear();
            _historyId = null;
          });
        }();
        break;
      case DrawerKind.history:
        Navigator.pushReplacementNamed(context, '/history', arguments: key.id!);
        break;
    }
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
        title: AnimatedBuilder(
          animation: home,
          builder: (_, __) {
            if (home.busy) {
              return const Text(
                'Đang tải...',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              );
            }
            final BotModel? bot = home.bot;
            String raw = (bot == null || bot.name.trim().isEmpty)
                ? ''
                : bot.name.trim();
            String shortTitle = raw.length <= 24
                ? raw
                : raw.substring(0, 22) + '…';
            return Row(
              children: [
                if (bot?.image != null && bot!.image!.isNotEmpty)
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
                Tooltip(
                  message: raw,
                  waitDuration: const Duration(milliseconds: 400),
                  child: Text(
                    shortTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
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
        current:
            widget.currentDrawerKey ??
            (widget.initialBotId != null && widget.initialBotId!.isNotEmpty
                ? DrawerKey(DrawerKind.bot, id: widget.initialBotId)
                : const DrawerKey(DrawerKind.chat)),
        onSelect: _handleDrawerSelect,
      ),
      body: AnimatedBuilder(
        animation: home,
        builder: (_, __) {
          if (home.busy) {
            return const Center(child: CircularProgressIndicator());
          }

          if (home.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(home.error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => home.loadDefaultBot(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }
          final BotModel? bot = home.bot;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                const SizedBox(height: 8),
                if (_messages.isEmpty) ...[
                  Row(
                    children: [
                      if (bot != null &&
                          bot.image != null &&
                          bot.image!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              bot.image!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.smart_toy),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bot?.name ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (bot?.description.isNotEmpty == true)
                                  ? bot!.description
                                  : '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color?.withOpacity(.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: ListView.builder(
                    controller: _listCtrl,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: _messages.length + (_showTyping ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (_showTyping && i == _messages.length)
                        return _typingBubble();
                      final m = _messages[i];
                      return _bubble(m, isUser: m.role == 'user');
                    },
                  ),
                ),
              ],
            ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasAttachment)
                    SizedBox(
                      height: 128,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (_, i) {
                          final att = _attachments[i];
                          return _SmallAttachmentTile(
                            att: att,
                            onRemove: att.uploading
                                ? null
                                : () => _removeAttachment(att.id),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: _attachments.length,
                      ),
                    ),
                  // Top row: model selector + attach actions
                  Row(
                    children: [
                      _buildModelSelectorChip(context),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Ảnh',
                        onPressed: _anyUploading
                            ? null
                            : () => _pickAndUploadSingle(image: true),
                        icon: const Icon(Icons.image_outlined),
                      ),
                      IconButton(
                        tooltip: 'Tài liệu',
                        onPressed: _anyUploading
                            ? null
                            : () => _pickAndUploadSingle(image: false),
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
                  // Bottom row: text field + send button
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
                          onPressed: (_sending || _anyUploading)
                              ? null
                              : () async {
                                  FocusScope.of(context).unfocus();
                                  final text = _inputCtrl.text.trim();
                                  if (text.isEmpty) return;
                                  _inputCtrl.clear();
                                  final userId = widget.auth.user?.id;
                                  final botId = widget.home.bot?.id;
                                  if (userId == null ||
                                      userId.isEmpty ||
                                      botId == null ||
                                      botId.isEmpty) {
                                    TopToast.error(
                                      context,
                                      'Thiếu user hoặc bot để chat',
                                    );
                                    return;
                                  }
                                  setState(() => _sending = true);
                                  // choose first fully uploaded attachment (backend supports single file)
                                  _PendingAttachment? ready;
                                  for (final a in _attachments) {
                                    if (a.url != null) {
                                      ready = a;
                                      break;
                                    }
                                  }
                                  final attachedUrl = ready?.url;
                                  final attachedType = ready?.mime;
                                  // Clear preview immediately so it disappears once user presses send
                                  if (_attachments.isNotEmpty) {
                                    _clearAllAttachments();
                                  }
                                  if (_attachments.length > 1) {
                                    TopToast.show(
                                      context,
                                      'Chỉ gửi file đầu tiên (BE chỉ hỗ trợ 1 file).',
                                    );
                                  }
                                  // TODO(MULTI_FILE_BE_SUPPORT): When backend supports multiple files,
                                  // 1. Collect all uploaded attachment URLs: final urls = _attachments.where((a)=>a.url!=null).map((a)=>a.url).toList();
                                  // 2. Modify repository & API payload to accept array (e.g. files: [...]) and optional types.
                                  // 3. Update message model to store list and render gallery / file chips in _bubble.
                                  setState(() {
                                    _messages.add(
                                      ChatMessageModel(
                                        id: 'local_${DateTime.now().millisecondsSinceEpoch}_u',
                                        text: text,
                                        role: 'user',
                                        createdAt: DateTime.now(),
                                        fileUrl: attachedUrl,
                                        fileType: attachedType,
                                      ),
                                    );
                                  });
                                  try {
                                    final forceFixedHistory =
                                        widget.fixedHistoryId != null &&
                                        widget.fixedHistoryId!.isNotEmpty;
                                    final creatingNewHistory = forceFixedHistory
                                        ? false
                                        : (_historyId == null ||
                                              _historyId!.isEmpty);
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
                                            historyChat: forceFixedHistory
                                                ? widget.fixedHistoryId
                                                : _historyId,
                                            file: attachedUrl,
                                            fileType: attachedType,
                                            model: model,
                                          )
                                        : await repo.createMessageMobileGpt(
                                            userId: userId,
                                            botId: botId,
                                            content: text,
                                            historyChat: forceFixedHistory
                                                ? widget.fixedHistoryId
                                                : _historyId,
                                            file: attachedUrl,
                                            fileType: attachedType,
                                            model: model,
                                          );
                                    if (!mounted) return;
                                    final beforeHistory = _historyId;
                                    setState(() {
                                      if (!forceFixedHistory) {
                                        _historyId ??= res.history;
                                      }
                                    });
                                    // If this message just created a new history id, update the message record.
                                    if (!forceFixedHistory) {
                                      if ((beforeHistory == null ||
                                              beforeHistory.isEmpty) &&
                                          _historyId != null &&
                                          _historyId!.isNotEmpty) {
                                        try {
                                          await repo.updateMessageHistory(
                                            messageId: res.id,
                                            historyId: _historyId!,
                                          );
                                        } catch (_) {}
                                      }
                                    }
                                    // Start streaming bot response
                                    _startStreaming(
                                      res.contentBot,
                                      ChatMessageModel(
                                        id: '${res.id}_b',
                                        text: '',
                                        role: 'bot',
                                        createdAt: res.createdAt,
                                        botId: botId,
                                      ),
                                    );
                                    if (creatingNewHistory &&
                                        _historyId != null &&
                                        _historyId!.isNotEmpty) {
                                      try {
                                        await widget.history.refreshHistory();
                                      } catch (_) {}
                                    }
                                  } catch (e) {
                                    if (!mounted) return;
                                    TopToast.error(context, 'Gửi thất bại: $e');
                                    setState(
                                      () => _sending = false,
                                    ); // fail fast
                                  }
                                },
                          child: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
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

  // (Dropdown version removed in favor of chip selector)

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

  // Compact model selector chip with bottom-sheet options
  Widget _buildModelSelectorChip(BuildContext context) {
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

  void _startStreaming(String full, ChatMessageModel baseBot) {
    _streamTimer?.cancel();
    _streamFull = full;
    _streaming = true;
    // Insert placeholder bot message with empty text
    setState(() {
      _messages.add(
        ChatMessageModel(
          id: baseBot.id,
          text: '',
          role: 'bot',
          createdAt: baseBot.createdAt,
        ),
      );
    });
    final int total = full.length;
    int index = 0;
    const chunkMin = 8; // min chars per tick
    const chunkMax = 28; // max chars per tick
    const interval = Duration(milliseconds: 40);
    void scrollAfterFrame() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_listCtrl.hasClients) {
          _listCtrl.jumpTo(_listCtrl.position.maxScrollExtent);
        }
      });
    }

    int tick = 0;
    _streamTimer = Timer.periodic(interval, (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (index >= total) {
        t.cancel();
        _streaming = false;
        _sending = false; // done
        // Replace last message text with full content (final for markdown re-render)
        setState(() {
          final last = _messages.last;
          _messages[_messages.length - 1] = ChatMessageModel(
            id: last.id,
            text: _streamFull,
            role: last.role,
            createdAt: last.createdAt,
          );
        });
        scrollAfterFrame();
        return;
      }
      final remaining = total - index;
      final take = remaining < chunkMin
          ? remaining
          : (remaining < chunkMax
                ? remaining
                : (chunkMin + (remaining % (chunkMax - chunkMin + 1))));
      index += take;
      final partial = _streamFull.substring(0, index);
      setState(() {
        final last = _messages.last;
        _messages[_messages.length - 1] = ChatMessageModel(
          id: last.id,
          text: partial,
          role: last.role,
          createdAt: last.createdAt,
        );
      });
      // Throttle scroll to every 3 ticks for smoother experience
      if (tick % 3 == 0) scrollAfterFrame();
      tick++;
    });
  }

  Widget _typingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F7F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: AnimatedBuilder(
              animation: _typingController,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final segment = 1 / 3;
                    final start = i * segment;
                    final end = start + segment;
                    double t = _typingController.value;
                    // map controller value into this dot's local progress 0..1
                    double local;
                    if (t < start) {
                      local = 0;
                    } else if (t > end) {
                      local = 0;
                    } else {
                      local = (t - start) / segment;
                    }
                    // ease up then down
                    final bounce = (local <= 0.5)
                        ? Curves.easeOut.transform(local * 2)
                        : Curves.easeIn.transform((1 - local) * 2);
                    final dy = -4 * bounce; // upward movement
                    final opacity = 0.4 + 0.6 * bounce;
                    return Transform.translate(
                      offset: Offset(0, dy),
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessageModel m, {required bool isUser}) {
    if (isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: _UserMessageBubble(msg: m),
            ),
          ],
        ),
      );
    }
    final bool isLast = _messages.isNotEmpty && identical(m, _messages.last);
    final bool streamingThis = isLast && _streaming;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    streamingThis
                        ? Text(
                            m.text,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          )
                        : _MarkdownMessage(text: m.text),
                    if (!streamingThis)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _BotActionIcon(
                              tooltip: 'Copy',
                              icon: Icons.copy_rounded,
                              onTap: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: m.text),
                                );
                                if (mounted) {
                                  TopToast.success(context, 'Đã copy');
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            if (_messageStatus[m.id] != 2)
                              _BotActionIcon(
                                tooltip: 'Thích',
                                icon: _messageStatus[m.id] == 1
                                    ? Icons.thumb_up_alt
                                    : Icons.thumb_up_alt_outlined,
                                selected: _messageStatus[m.id] == 1,
                                onTap: () async {
                                  if (_messageStatus[m.id] == 1)
                                    return; // already liked
                                  setState(() => _messageStatus[m.id] = 1);
                                  try {
                                    final repo = ChatRepository.fromEnv();
                                    // bot id stored as message id with _b suffix; remove suffix
                                    final baseId = m.id.endsWith('_b')
                                        ? m.id.substring(0, m.id.length - 2)
                                        : m.id;
                                    await repo.updateMessageStatus(
                                      messageId: baseId,
                                      status: 1,
                                    );
                                  } catch (e) {
                                    setState(() => _messageStatus.remove(m.id));
                                    if (mounted) {
                                      TopToast.error(
                                        context,
                                        'Like thất bại: $e',
                                      );
                                    }
                                  }
                                },
                              ),
                            if (_messageStatus[m.id] != 1) ...[
                              const SizedBox(width: 4),
                              _BotActionIcon(
                                tooltip: 'Không thích',
                                icon: _messageStatus[m.id] == 2
                                    ? Icons.thumb_down_alt
                                    : Icons.thumb_down_alt_outlined,
                                selected: _messageStatus[m.id] == 2,
                                onTap: () async {
                                  if (_messageStatus[m.id] == 2)
                                    return; // already disliked
                                  setState(() => _messageStatus[m.id] = 2);
                                  try {
                                    final repo = ChatRepository.fromEnv();
                                    final baseId = m.id.endsWith('_b')
                                        ? m.id.substring(0, m.id.length - 2)
                                        : m.id;
                                    await repo.updateMessageStatus(
                                      messageId: baseId,
                                      status: 2,
                                    );
                                  } catch (e) {
                                    setState(() => _messageStatus.remove(m.id));
                                    if (mounted) {
                                      TopToast.error(
                                        context,
                                        'Dislike thất bại: $e',
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ],
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

class _BotActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool selected;
  const _BotActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
  });
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected ? Colors.blue.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Colors.blue : Colors.black12),
          ),
          child: Icon(icon, size: 16, color: selected ? Colors.blue : null),
        ),
      ),
    );
  }
}

class _PendingAttachment {
  final String id;
  final File file;
  final String name;
  final String mime;
  bool uploading;
  String? url;
  String? error;
  _PendingAttachment({
    required this.id,
    required this.file,
    required this.name,
    required this.mime,
  }) : uploading = false,
       url = null,
       error = null;
  bool get isImage => mime.startsWith('image/');
}

class _SmallAttachmentTile extends StatelessWidget {
  final _PendingAttachment att;
  final VoidCallback? onRemove;
  const _SmallAttachmentTile({required this.att, this.onRemove});
  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(12);
    final isImage = att.isImage;
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: border,
        border: Border.all(
          color: att.error != null ? Colors.redAccent : Colors.black26,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: isImage
                ? _buildImage()
                : Container(
                    alignment: Alignment.center,
                    color: Colors.white,
                    child: Icon(
                      _iconForMime(att.mime),
                      color: Colors.blueGrey,
                      size: 38,
                    ),
                  ),
          ),
          if (att.uploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.35),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          // Gradient + filename bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: isImage
                      ? [Colors.black.withOpacity(.55), Colors.transparent]
                      : [Colors.white, Colors.white],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    att.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isImage
                          ? Colors.white
                          : (att.error != null ? Colors.red : Colors.black87),
                    ),
                  ),
                  if (att.error != null)
                    Text(
                      att.error!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else if (att.uploading)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Đang tải...',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      isImage ? 'Ảnh' : att.mime,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: isImage ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Remove button
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (att.url != null) {
      return Image.network(
        att.url!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
      );
    }
    return Image.file(
      att.file,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.image),
    );
  }

  static IconData _iconForMime(String mime) {
    if (mime.contains('pdf')) return Icons.picture_as_pdf;
    if (mime.contains('word') || mime.contains('doc')) return Icons.description;
    if (mime.contains('text')) return Icons.notes;
    return Icons.insert_drive_file;
  }
}

class _UserMessageBubble extends StatelessWidget {
  final ChatMessageModel msg;
  const _UserMessageBubble({required this.msg});

  bool get hasAttachment => (msg.fileUrl != null && msg.fileUrl!.isNotEmpty);
  bool get isImage =>
      hasAttachment && (msg.fileType?.startsWith('image/') ?? false);

  @override
  Widget build(BuildContext context) {
    // If both file and text -> return Column with separate bubbles
    if (hasAttachment && msg.text.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          _AttachmentBubble(msg: msg, isImage: isImage),
          const SizedBox(height: 6),
          _TextBubble(msg: msg),
        ],
      );
    }
    if (hasAttachment) return _AttachmentBubble(msg: msg, isImage: isImage);
    return _TextBubble(msg: msg);
  }
}

class _AttachmentBubble extends StatelessWidget {
  final ChatMessageModel msg;
  final bool isImage;
  const _AttachmentBubble({required this.msg, required this.isImage});

  Future<void> _open(BuildContext context) async {
    final url = msg.fileUrl!;
    final isPdf =
        (msg.fileType?.contains('pdf') ?? false) ||
        url.toLowerCase().endsWith('.pdf');
    if (isImage) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => _ImagePreviewDialog(url: url),
      );
      return;
    }
    if (isPdf) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => _PdfPreviewDialog(url: url),
      );
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      TopToast.error(context, 'Không mở được file');
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(14);
    if (isImage) {
      return GestureDetector(
        onTap: () => _open(context),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Image.network(
            msg.fileUrl!,
            width: 180,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 180,
              height: 120,
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image, color: Colors.black45),
            ),
          ),
        ),
      );
    }
    final name = msg.fileUrl!.split('/').last;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: borderRadius,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
          border: Border.all(color: Colors.black26),
        ),
        child: Row(
          children: [
            Icon(_iconForType(msg.fileType), color: Colors.black54, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
            const Icon(Icons.open_in_new, size: 16, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  final ChatMessageModel msg;
  const _TextBubble({required this.msg});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              msg.text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 6),
          _UserCopyIcon(text: msg.text),
        ],
      ),
    );
  }
}

class _UserCopyIcon extends StatelessWidget {
  final String text;
  const _UserCopyIcon({required this.text});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          TopToast.success(context, 'Đã copy');
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.copy, color: Colors.white70, size: 14),
      ),
    );
  }
}

IconData _iconForType(String? t) {
  if (t == null) return Icons.insert_drive_file;
  final lower = t.toLowerCase();
  if (lower.contains('pdf')) return Icons.picture_as_pdf;
  if (lower.contains('word') || lower.contains('doc')) return Icons.description;
  if (lower.contains('text') || lower.contains('plain')) return Icons.notes;
  return Icons.insert_drive_file;
}

class _MarkdownMessage extends StatelessWidget {
  final String text;
  const _MarkdownMessage({required this.text});

  @override
  Widget build(BuildContext context) =>
      SelectionArea(child: _MarkdownBody(text: text));
}

class _ImagePreviewDialog extends StatelessWidget {
  final String url;
  const _ImagePreviewDialog({required this.url});
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Hero(
                  tag: url,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfPreviewDialog extends StatefulWidget {
  final String url;
  const _PdfPreviewDialog({required this.url});
  @override
  State<_PdfPreviewDialog> createState() => _PdfPreviewDialogState();
}

class _PdfPreviewDialogState extends State<_PdfPreviewDialog> {
  PdfControllerPinch? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uri = Uri.parse(widget.url);
      final client = HttpClient();
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final data = await resp.fold<List<int>>(<int>[], (p, e) => p..addAll(e));
      if (!mounted) return;
      setState(() {
        _controller = PdfControllerPinch(
          document: PdfDocument.openData(Uint8List.fromList(data)),
          initialPage: 1,
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        width: 360,
        height: 480,
        child: Stack(
          children: [
            if (_error != null)
              Center(child: Text('Lỗi: $_error'))
            else if (_controller != null)
              PdfViewPinch(controller: _controller!)
            else
              const SizedBox.shrink(),
            if (_loading) const Center(child: CircularProgressIndicator()),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkdownBody extends StatelessWidget {
  final String text;
  const _MarkdownBody({required this.text});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: text,
      selectable: false,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 14, height: 1.4),
        code: TextStyle(
          backgroundColor: Colors.grey.shade200,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: TextStyle(
          color: Colors.grey.shade700,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: Colors.grey.shade400, width: 4),
          ),
        ),
        listBullet: const TextStyle(fontSize: 14),
      ),
      builders: {'code': CodeElementBuilder()},
      onTapLink: (text, href, title) {},
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final raw = element.textContent.trimRight();
    return _CodeBlockWidget(code: raw);
  }
}

class _CodeBlockWidget extends StatefulWidget {
  final String code;
  const _CodeBlockWidget({required this.code});

  @override
  State<_CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<_CodeBlockWidget> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: Size.zero,
                  ),
                  onPressed: _copied ? null : _copy,
                  icon: Icon(_copied ? Icons.check : Icons.copy, size: 14),
                  label: Text(
                    _copied ? 'Copied' : 'Copy',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            child: Text(
              widget.code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFFFAFAFA),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
