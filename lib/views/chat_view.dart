import 'package:flutter/material.dart';
import '../../controllers/chat_controller.dart';
import '../../models/message.dart';
import 'dashboard/widgets/message_bubble.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  late final ChatController controller;
  final TextEditingController input = TextEditingController();
  final ScrollController scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    controller = ChatController();
    controller.messages.addListener(_autoScrollToBottom);
  }

  void _autoScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    controller.messages.removeListener(_autoScrollToBottom);
    controller.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: AppBar(
          automaticallyImplyLeading: true,
          toolbarHeight: 72,
          titleSpacing: 0,
          title: Row(
            children: [
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 28,
                backgroundImage: AssetImage('assets/bot.png'), // đổi ảnh nếu muốn
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('AI. SUPER INTELLIGENCE',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700, letterSpacing: .2)),
                  Text(
                    'Answer any questions in your language.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              )
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Expanded(
              child: ValueListenableBuilder<List<Message>>(
                valueListenable: controller.messages,
                builder: (context, list, _) {
                  return ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    itemCount: list.length,
                    itemBuilder: (c, i) => MessageBubble(msg: list[i]),
                  );
                },
              ),
            ),

            // Typing indicator (optional)
            ValueListenableBuilder<bool>(
              valueListenable: controller.typing,
              builder: (context, v, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: v
                    ? Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('AI is typing…',
                      style: Theme.of(context).textTheme.bodySmall),
                )
                    : const SizedBox.shrink(),
              ),
            ),

            // Input bar
            Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  // nút ảnh
                  IconButton(
                    tooltip: 'Attach image',
                    icon: const Icon(Icons.image_outlined),
                    onPressed: () => _pickAttachment(context, 'image'),
                  ),
                  // nút PDF
                  IconButton(
                    tooltip: 'Attach PDF',
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: () => _pickAttachment(context, 'pdf'),
                  ),
                  // nút DOC
                  IconButton(
                    tooltip: 'Attach DOC',
                    icon: const Icon(Icons.description_outlined),
                    onPressed: () => _pickAttachment(context, 'doc'),
                  ),

                  // input
                  Expanded(
                    child: TextField(
                      controller: input,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'please chat here...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),

                  // send
                  IconButton.filledTonal(
                    tooltip: 'Send',
                    icon: const Icon(Icons.send_rounded),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _send() {
    final text = input.text;
    input.clear();
    controller.send(text);
  }

  void _pickAttachment(BuildContext context, String kind) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text('Pick $kind from device'),
              onTap: () {
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Picked a $kind (demo).')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Attach by URL'),
              onTap: () {
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Attach by URL (demo).')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
