import 'package:flutter/material.dart';
import '../../../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message msg;
  const MessageBubble({super.key, required this.msg});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.owner == MessageOwner.me;
    final color = isMe
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceVariant;
    final textColor = isMe ? Colors.white : null;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isMe ? 14 : 2),
              bottomRight: Radius.circular(isMe ? 2 : 14),
            ),
          ),
          child: Text(msg.text, style: TextStyle(color: textColor)),
        ),
      ),
    );
  }
}
