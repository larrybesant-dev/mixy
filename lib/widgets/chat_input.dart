import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const ChatInput({super.key, required this.controller, required this.onSend});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: const InputDecoration(hintText: 'Type a message...'),
          ),
        ),
        IconButton(icon: const Icon(Icons.send), onPressed: onSend),
      ],
    );
  }
}



