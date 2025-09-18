import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/history_controller.dart';
import '../models/bot_model.dart';
import '../models/chat_message_model.dart';
import '../models/history_message.dart';
import '../widgets/app_drawer.dart';
import '../widgets/drawer_key.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class HistoryChatView extends StatefulWidget {
  final ChatController ctrl;
  final String historyId; // id của history
  final AuthController auth; // dùng cho Drawer
  final HomeController home;
  final HistoryController history;
  final String? title;

  const HistoryChatView({
    super.key,
    required this.ctrl,
    required this.historyId,
    required this.auth,
    required this.home,
    required this.history,
    this.title,
  });

  @override
  State<HistoryChatView> createState() => _HistoryChatViewState();
}

class _HistoryChatViewState extends State<HistoryChatView> {
  final _scroll = ScrollController();
  final _inputCtrl = TextEditingController();

  BotModel? _bot;
  String? _botErr;
  bool _loadingBot = false;

  @override
  void initState() {
    super.initState();
    widget.ctrl.refresh();
    _scroll.addListener(_onScroll);
    _loadBotFromHistory();
  }

  // ===== Drawer handlers
  void _handleDrawerSelect(DrawerKey key) {
    switch (key.kind) {
      case DrawerKind.chat:
        Navigator.pushReplacementNamed(context, '/chat');
        break;
      case DrawerKind.usage:
        Navigator.pushReplacementNamed(context, '/usage');
        break;
      case DrawerKind.adminUsers:
        Navigator.pushReplacementNamed(context, '/admin/users');
        break;
      case DrawerKind.adminConfig:
        Navigator.pushReplacementNamed(context, '/admin/config');
        break;
      case DrawerKind.bot:
        if (key.id == null || key.id!.isEmpty) return;
        final id = key.id!;
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
        if (key.id == null || key.id!.isEmpty) return;
        if (key.id == widget.historyId) return;
        Navigator.pushReplacementNamed(context, '/history', arguments: key.id);
        break;
    }
  }
  // =====

  Future<void> _loadBotFromHistory() async {
    setState(() {
      _loadingBot = true;
      _botErr = null;
    });

    try {
      final HistoryMessage? h = await widget.history.getById(widget.historyId);
      if (h == null) throw Exception('Không tìm thấy lịch sử chat');

      final String? botId = h.bot?.toString();
      if (botId == null || botId.isEmpty) {
        throw Exception('Lịch sử chat không có botId');
      }

      final BotModel bot = await widget.home.loadBotById(botId);
      setState(() => _bot = bot);
    } catch (e) {
      setState(() => _botErr = e.toString());
    } finally {
      setState(() => _loadingBot = false);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final threshold = _scroll.position.maxScrollExtent - 200;
    if (_scroll.position.pixels >= threshold &&
        widget.ctrl.hasNext &&
        !widget.ctrl.busy) {
      widget.ctrl.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),

      drawer: AppDrawer(
        auth: widget.auth,
        home: widget.home,
        history: widget.history,
        current: DrawerKey(DrawerKind.history, id: widget.historyId),
        onSelect: _handleDrawerSelect,
      ),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: .5,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: _buildAppBarTitle(),
      ),

      body: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          if (ctrl.error != null && ctrl.messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lỗi: ${ctrl.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: ctrl.refresh,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          if (ctrl.busy && ctrl.messages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // 1) BE thường trả DESC; để group đúng, ta tạo chronological ASC
          final chronological = List<ChatMessageModel>.from(
            ctrl.messages.reversed,
          );

          // 2) Group mỗi record thành 1 unit: user (trên) + bot (dưới)
          final units = _groupByBaseId(chronological);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  reverse: true, // tin mới ở dưới – giữ UX hiện tại
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  itemCount: units.length + 1,
                  itemBuilder: (_, i) {
                    if (i == units.length) {
                      if (ctrl.hasNext) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }

                    // reverse:true => hiển thị từ cuối mảng units
                    final unit = units[units.length - 1 - i];

                    // BẮT BUỘC: user TRÊN, bot DƯỚI (nếu có)
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (unit.user != null)
                          _bubble(unit.user!, isUser: true),
                        if (unit.user != null && unit.bot != null)
                          const SizedBox(height: 6),
                        if (unit.bot != null) _bubble(unit.bot!, isUser: false),
                      ],
                    );
                  },
                ),
              ),
              _inputBar(context),
            ],
          );
        },
      ),
    );
  }

  // ---------- AppBar title ----------
  Widget _buildAppBarTitle() {
    if (_loadingBot) {
      return const Text(
        'Đang tải...',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      );
    }
    if (_botErr != null || _bot == null) {
      return Text(
        widget.title ?? 'Chat',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      );
    }

    final bot = _bot!;
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
          child: Text(
            bot.name,
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
      ],
    );
  }

  // ---------- Helpers render ----------
  Widget _bubble(ChatMessageModel m, {required bool isUser}) {
    final bg = isUser ? Colors.black : const Color(0xFFEFF3F8);
    final fg = isUser ? Colors.white : Colors.black87;
    final align = isUser ? MainAxisAlignment.end : MainAxisAlignment.start;

    final blocks = <Widget>[];

    // 1) Text bubble (nếu có)
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép nội dung'),
                              ),
                            );
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

    // 2) File bubble riêng (nếu có file)
    if (m.fileUrl != null && m.fileUrl!.isNotEmpty) {
      final isImg = _isImageType(m.fileType, m.fileUrl);

      if (isImg) {
        // Ảnh: không cần bubble
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã tải xuống: ${file.path}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tải xuống thất bại')));
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(_absUrl(url));
    if (uri == null) return;
    try {
      // Try external app (e.g., PDF viewer). Fallback to in-app web view, then platform default.
      bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) ok = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      if (!ok) ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!ok && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Không mở được tệp.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Không mở được tệp.')));
      }
    }
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

  Widget _inputBar(BuildContext context) {
    return SafeArea(
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
    );
  }
}

/// ===== Grouping logic: 1 record -> 1 unit (user trên, bot dưới)
class _RenderUnit {
  final ChatMessageModel? user;
  final ChatMessageModel? bot;
  const _RenderUnit({this.user, this.bot});
  bool get isPair => user != null && bot != null;
}

/// Gom theo baseId. Input là **chronological ASC** (cũ -> mới).
List<_RenderUnit> _groupByBaseId(List<ChatMessageModel> chronological) {
  final map = <String, _RenderUnit>{};

  for (final m in chronological) {
    final key = m.baseId;
    final old = map[key];

    if (m.role == 'user') {
      map[key] = _RenderUnit(user: m, bot: old?.bot);
    } else {
      map[key] = _RenderUnit(user: old?.user, bot: m);
    }
  }

  // Giữ thứ tự xuất hiện theo chronological
  final orderedKeys = <String>{};
  for (final m in chronological) {
    orderedKeys.add(m.baseId);
  }

  return orderedKeys.map((k) => map[k]!).toList();
}
