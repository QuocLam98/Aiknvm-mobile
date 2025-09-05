import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/history_controller.dart';
import '../models/bot_model.dart';
import '../models/chat_message_model.dart';
import '../widgets/app_drawer.dart';
import '../widgets/drawer_key.dart';

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
        if (key.id == widget.botId) return;
        Navigator.pushReplacementNamed(context, '/chat', arguments: key.id!);
        break;
      case DrawerKind.history:
        Navigator.pushNamed(context, '/history', arguments: key.id);
        break;
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
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
                Text(
                  bot.name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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
                  Text('Lỗi: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red)),
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
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 24,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          Center(
                            child: Container(
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
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withOpacity(.75),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
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
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      minLines: 1,
                      maxLines: 4,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      decoration: const InputDecoration(
                        hintText: 'please chat here...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  // Ảnh
                  IconButton(
                    tooltip: 'Ảnh',
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final f = result.files.first;
                        debugPrint('Ảnh được chọn: ${f.name} - ${f.path}');
                        // TODO: upload/gửi file ảnh
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                  ),
                  // Tài liệu
                  IconButton(
                    tooltip: 'Tài liệu',
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final f = result.files.first;
                        debugPrint('Tài liệu được chọn: ${f.name} - ${f.path}');
                        // TODO: upload/gửi file tài liệu
                      }
                    },
                    icon: const Icon(Icons.description_outlined),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      // TODO: gửi tin nhắn
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(m.text, style: TextStyle(color: fg, fontSize: 14)),
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
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
    return u.endsWith('.png') || u.endsWith('.jpg') || u.endsWith('.jpeg') || u.endsWith('.webp') || u.endsWith('.gif');
  }

  IconData _iconForFileType(String? fileType, String? url) {
    final t = (fileType ?? '').toLowerCase();
    final u = (url ?? '').toLowerCase();
    if (t.contains('pdf') || u.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (t.contains('doc') || u.endsWith('.doc') || u.endsWith('.docx')) return Icons.description;
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
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                  ),
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
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã tải xuống: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tải xuống thất bại')),
      );
    }
  }
}

