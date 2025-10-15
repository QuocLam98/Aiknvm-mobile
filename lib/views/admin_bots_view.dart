import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/bot_model.dart';
import '../services/bot_repository.dart';
import 'admin_table_scaffold.dart';
import '../controllers/app_events.dart';

class AdminBotsView extends StatefulWidget {
  const AdminBotsView({super.key});

  @override
  State<AdminBotsView> createState() => _AdminBotsViewState();
}

class _AdminBotsViewState extends State<AdminBotsView> {
  final _repo = BotRepository();
  final _columns = const ['Tên', 'Mô tả', 'Trạng thái', 'Ngày tạo'];

  List<BotModel> _items = const [];
  bool _loading = true;
  String? _error;
  // Remote-style state (client-side paginate)
  int _page = 1;
  int _limit = 10;
  int _total = 0; // computed from filtered
  String _keyword = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.getAllBots();
      setState(() => _items = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String _statusText(int s) => s == 1 ? 'Bảo trì' : 'Hoạt động';

  List<BotModel> _filtered() {
    final q = _keyword.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((b) {
      return b.name.toLowerCase().contains(q) ||
          (b.description.toLowerCase().contains(q));
    }).toList();
  }

  List<List<String>> _tableDataFor(List<BotModel> list) => list
      .map(
        (b) => [
          b.name,
          b.description,
          _statusText(b.status),
          b.createdAt?.toString() ?? '',
        ],
      )
      .toList();

  Future<void> _onAdd() async {
    final res = await showDialog<_BotFormResult>(
      context: context,
      builder: (_) => const _EditBotDialog(),
    );
    if (res == null) return;
    try {
      setState(() => _loading = true);
      final created = await _repo.createBot(
        name: res.name,
        templateMessage: res.template,
        description: res.description.isNotEmpty ? res.description : null,
        status: res.status,
        priority: res.priority?.toString(),
        models: res.models?.toString(),
        imageBytes: res.imageBytes?.toList(),
        imageFilename: res.imageUrl != null && res.imageUrl!.isNotEmpty
            ? res.imageUrl!.split('/').last
            : null,
      );
      // Refresh from server to ensure list is consistent with BE
      await _load();
      AppEvents.instance.notifyBotsChanged();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Đã tạo bot "${created.name}"')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Tạo bot thất bại: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onEdit(int row) async {
    if (row < 0 || row >= _items.length) return;
    final cur = _items[row];
    final res = await showDialog<_BotFormResult>(
      context: context,
      builder: (_) => _EditBotDialog(
        initial: _BotFormResult(
          name: cur.name,
          description: cur.description,
          template: cur.template,
          status: cur.status,
          priority: cur.priority,
          models: cur.models,
          imageUrl: cur.image,
        ),
      ),
    );
    if (res == null) return;
    try {
      setState(() => _loading = true);
      await _repo.updateBot(
        id: cur.id,
        name: res.name,
        templateMessage: res.template,
        description: res.description,
        status: res.status,
        priority: res.priority?.toString(),
        models: res.models?.toString(),
        imageBytes: res.imageBytes?.toList(),
        imageFilename: res.imageUrl != null && res.imageUrl!.isNotEmpty
            ? res.imageUrl!.split('/').last
            : null,
      );
      await _load();
      AppEvents.instance.notifyBotsChanged();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã cập nhật bot')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cập nhật thất bại: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onDelete(int row) async {
    if (row < 0 || row >= _items.length) return;
    final bot = _items[row];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá bot'),
        content: Text('Bạn có chắc muốn xoá "${bot.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      setState(() => _loading = true);
      await _repo.deleteBot(bot.id);
      await _load();
      AppEvents.instance.notifyBotsChanged();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Đã xoá "${bot.name}"')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Xoá thất bại: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prepare filtered + paged data like Accounts/Messages/Payments
    final filtered = _filtered();
    _total = filtered.length;
    final totalPages = (_total / _limit).ceil().clamp(1, 9999);
    _page = _page.clamp(1, totalPages);
    final start = (_page - 1) * _limit;
    final end = (start + _limit).clamp(0, _total);
    final pageItems = (start < _total)
        ? filtered.sublist(start, end)
        : <BotModel>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('[Admin] Quản lý bot'),
        actions: [
          IconButton(
            onPressed: _onAdd,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Thêm mới',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm + page size (giống các trang khác)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên hoặc mô tả...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      suffixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (v) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 400), () {
                        _keyword = v.trim();
                        setState(() => _page = 1);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _limit,
                  items: const [10, 20, 50]
                      .map(
                        (v) => DropdownMenuItem<int>(
                          value: v,
                          child: Text(v.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _limit = v;
                      _page = 1;
                    });
                  },
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Làm mới',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: AdminTableScaffold(
              columns: _columns,
              data: _tableDataFor(pageItems),
              showSearch: false,
              showPagination: false, // dùng phân trang remote phía dưới
              cellMaxWidth: 260,
              actionsBuilder: (row) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Sửa',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _onEdit((start + row)),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Xoá',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _onDelete((start + row)),
                  ),
                ],
              ),
            ),
          ),
          _remotePagination(_total),
        ],
      ),
    );
  }

  Widget _remotePagination(int total) {
    final totalPages = (total / _limit).ceil().clamp(1, 9999);
    _page = _page.clamp(1, totalPages);
    List<Widget> buttons = [];

    buttons.add(
      ElevatedButton(
        onPressed: _page > 1 ? () => setState(() => _page--) : null,
        child: const Text('Prev'),
      ),
    );

    const maxPagesToShow = 7;
    List<int> pages;
    if (totalPages <= maxPagesToShow) {
      pages = List.generate(totalPages, (i) => i + 1);
    } else {
      pages = <int>{
        1,
        totalPages,
        _page,
        _page - 1,
        _page + 1,
        2,
        totalPages - 1,
      }.where((p) => p >= 1 && p <= totalPages).toList()..sort();
    }

    int? last;
    for (final p in pages) {
      if (last != null && p - last > 1) {
        buttons.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('...'),
          ),
        );
      }
      final isActive = p == _page;
      buttons.add(
        isActive
            ? FilledButton(onPressed: () {}, child: Text(p.toString()))
            : OutlinedButton(
                onPressed: () => setState(() => _page = p),
                child: Text(p.toString()),
              ),
      );
      last = p;
    }

    buttons.add(
      ElevatedButton(
        onPressed: _page < totalPages ? () => setState(() => _page++) : null,
        child: const Text('Next'),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Trang '
            '$_page'
            '/$totalPages',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          ...buttons,
        ],
      ),
    );
  }
}

class _BotFormResult {
  final String name;
  final String description;
  final String template;
  final int status; // 0 = Hoạt động, 1 = Bảo trì
  final int? priority; // pri/priority (string số bên BE)
  final int? models; // 1=Gemini, 2=GPT, 3=Gemini+GPT
  final String? imageUrl;
  final Uint8List? imageBytes;

  const _BotFormResult({
    required this.name,
    required this.description,
    required this.template,
    required this.status,
    this.priority,
    this.models,
    this.imageUrl,
    this.imageBytes,
  });
}

class _EditBotDialog extends StatefulWidget {
  final _BotFormResult? initial;
  const _EditBotDialog({this.initial});

  @override
  State<_EditBotDialog> createState() => _EditBotDialogState();
}

class _EditBotDialogState extends State<_EditBotDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _tplCtrl;
  int _status = 0; // 0=Hoạt động, 1=Bảo trì
  int? _priority;
  int? _models; // 1=Gemini, 2=GPT, 3=Gemini+GPT
  Uint8List? _imageBytes;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    _descCtrl = TextEditingController(text: widget.initial?.description ?? '');
    _tplCtrl = TextEditingController(text: widget.initial?.template ?? '');
    _status = widget.initial?.status ?? 0;
    _imageUrl = widget.initial?.imageUrl;
    _imageBytes = widget.initial?.imageBytes;
    _priority = widget.initial?.priority;
    _models = widget.initial?.models;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _tplCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.85;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final minLines = isWide ? 8 : 4;
            return SizedBox(
              height: maxH,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Thêm mới bot AI',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 220, child: _imageSection()),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _field('Tên', _nameCtrl)),
                                    const SizedBox(width: 16),
                                    Expanded(child: _statusField()),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _priorityField()),
                                    const SizedBox(width: 16),
                                    Expanded(child: _modelsField()),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _multiline(
                                        'Mô tả',
                                        _descCtrl,
                                        minLines: minLines,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _multiline(
                                        'Cấu hình câu trả lời',
                                        _tplCtrl,
                                        minLines: minLines,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(child: _imageSection()),
                          const SizedBox(height: 16),
                          _field('Tên', _nameCtrl),
                          const SizedBox(height: 12),
                          _statusField(),
                          const SizedBox(height: 12),
                          _priorityField(),
                          const SizedBox(height: 12),
                          _modelsField(),
                          const SizedBox(height: 12),
                          _multiline('Mô tả', _descCtrl, minLines: minLines),
                          const SizedBox(height: 12),
                          _multiline(
                            'Cấu hình câu trả lời',
                            _tplCtrl,
                            minLines: minLines,
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Huỷ'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _onSave,
                          child: const Text('Lưu'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _imageSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Align(
            alignment: Alignment.center,
            child: Text('Ảnh', style: TextStyle(color: Colors.grey[700])),
          ),
        ),
        InkWell(
          onTap: _pickImage,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 160,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.black26,
                style: BorderStyle.solid,
              ),
            ),
            child: _imagePreview(),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(onPressed: _pickImage, child: const Text('Chọn ảnh')),
      ],
    );
  }

  Widget _imagePreview() {
    if (_imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(_imageBytes!, fit: BoxFit.cover),
      );
    }
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          _imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.image_outlined)),
        ),
      );
    }
    return Center(
      child: Text('Chọn ảnh', style: TextStyle(color: Colors.grey[600])),
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _multiline(
    String label,
    TextEditingController ctrl, {
    int minLines = 5,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        TextField(
          controller: ctrl,
          minLines: minLines,
          maxLines: null,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF7F7F8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            'Trạng thái',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DropdownButtonFormField<int>(
          value: _status,
          items: const [
            DropdownMenuItem(value: 0, child: Text('Hoạt động')),
            DropdownMenuItem(value: 1, child: Text('Bảo trì')),
          ],
          onChanged: (v) => setState(() => _status = v ?? 0),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    setState(() {
      _imageBytes = res.files.first.bytes;
      _imageUrl = null;
    });
  }

  void _onSave() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tên không được để trống')));
      return;
    }
    Navigator.pop(
      context,
      _BotFormResult(
        name: name,
        description: _descCtrl.text.trim(),
        template: _tplCtrl.text.trim(),
        status: _status,
        priority: _priority,
        models: _models ?? 1,
        imageUrl: _imageUrl,
        imageBytes: _imageBytes,
      ),
    );
  }

  Widget _priorityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('Ưu tiên', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        TextFormField(
          initialValue: _priority?.toString() ?? '',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          onChanged: (v) {
            final n = int.tryParse(v.trim());
            setState(() => _priority = n);
          },
        ),
      ],
    );
  }

  Widget _modelsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('Mô hình', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        DropdownButtonFormField<int>(
          value: _models,
          items: const [
            DropdownMenuItem(value: 1, child: Text('Gemini')),
            DropdownMenuItem(value: 2, child: Text('GPT')),
            DropdownMenuItem(value: 3, child: Text('Gemini + GPT')),
          ],
          onChanged: (v) => setState(() => _models = v),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
        ),
      ],
    );
  }
}
