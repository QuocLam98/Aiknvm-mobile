// views/chat_messages_view.dart
import 'package:flutter/material.dart';
import 'package:niku/niku.dart' as n;

import '../controllers/chat_controller.dart';
import '../models/chat_message_model.dart';

class ChatMessagesView extends StatefulWidget {
  final ChatController ctrl;
  final String? title;

  const ChatMessagesView({super.key, required this.ctrl, this.title});

  @override
  State<ChatMessagesView> createState() => _ChatMessagesViewState();
}

class _ChatMessagesViewState extends State<ChatMessagesView> {
  final _scroll = ScrollController();
  final _inputCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.ctrl.refresh();

    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // reverse: true => chạm gần top: pixels tiến tới maxScrollExtent
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
      appBar: AppBar(
        title: n.Text(widget.title ?? 'Chat')
          ..fontSize(15)
          ..bold()
          ..color(Colors.black87),
        backgroundColor: Colors.white,
        elevation: .5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          if (ctrl.error != null && ctrl.messages.isEmpty) {
            return Center(
              child: n.Column([
                n.Text('Lỗi: ${ctrl.error}')
                  ..color(Colors.red)
                  ..fontSize(14),
                n.Button(n.Text('Thử lại')..bold())
                  ..onPressed(() => ctrl.refresh())
                  ..mt(12),
              ])..center(),
            );
          }

          if (ctrl.busy && ctrl.messages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // BE đang sort desc; hiển thị reverse = true -> giữ thứ tự hiển thị tự nhiên
          final items = ctrl.messages;

          return n.Column([
            // Danh sách chat
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                reverse: true, // tin mới ở dưới
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                itemCount: items.length + 1, // +1 để show loading ở đầu
                itemBuilder: (_, i) {
                  if (i == items.length) {
                    // Loader đầu danh sách khi còn next
                    if (ctrl.hasNext) {
                      return n.Row([
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ])
                        ..center()
                        ..p(12);
                    }
                    return const SizedBox.shrink();
                  }

                  final m = items[i];
                  return _bubble(m);
                },
              ),
            ),

            // Thanh nhập
            _inputBar(),
          ]);
        },
      ),
      backgroundColor: const Color(0xFFF7F8FA),
    );
  }

  Widget _bubble(ChatMessageModel m) {
    final isUser = (m.role == 'user');
    final bg = isUser ? Colors.black : const Color(0xFFEFF3F8);
    final fg = isUser ? Colors.white : Colors.black87;
    final align = isUser ? MainAxisAlignment.end : MainAxisAlignment.start;

    return n.Row([
        n.Container(
            child: n.Text(m.text)
              ..color(fg)
              ..fontSize(14),
          )
          ..bg(bg)
          ..p(12)
          ..rounded(16)
          ..constraints(const BoxConstraints(maxWidth: 320)),
      ])
      ..mainAxisAlignment(align)
      ..py(6);
  }

  Widget _inputBar() {
    return n.Container(
        child: n.Row([
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
          n.Button(const Icon(Icons.send_rounded, size: 18))
            ..onPressed(() {
              FocusScope.of(context).unfocus();
              // TODO: gọi API gửi tin nhắn, rồi ctrl.refresh() hoặc insert local
            })
            ..bg(Colors.black87)
            ..rounded(20)
            ..p(12),
        ]),
      )
      ..bg(Colors.white)
      ..rounded(14)
      ..border(Colors.black12)
      ..px(10)
      ..py(6)
      ..m(12);
  }
}
