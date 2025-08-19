import 'package:flutter/material.dart';

enum MessageOwner { me, bot }

class Message {
  final String id;
  final String text;
  final DateTime? time;
  final MessageOwner owner;

  const Message({
    required this.id,
    required this.text,
    required this.time,
    required this.owner,
  });
}