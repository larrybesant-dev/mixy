import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mixvy/features/messaging/models/message_model.dart';
import 'package:mixvy/features/messaging/providers/messaging_provider.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';
import 'package:mixvy/shared/widgets/guest_auth_gate.dart';

class FloatingWhisperPanel {
  static OverlayEntry? _entry;

  static void show(
    BuildContext context,
    WidgetRef ref, {
    required String conversationId,
    required String peerName,
    String? peerAvatarUrl,
  }) {
    dismiss();

    _entry = OverlayEntry(
      builder: (_) => _FloatingWhisperPanelWidget(
        conversationId: conversationId,
        peerName: peerName,
        peerAvatarUrl: peerAvatarUrl,
        onClose: dismiss,
      ),
    );

    Overlay.of(context).insert(_entry!);
  }

  static void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}

class _FloatingWhisperPanelWidget extends ConsumerStatefulWidget {
  const _FloatingWhisperPanelWidget({
    required this.conversationId,
    required this.peerName,
    this.peerAvatarUrl,
    required this.onClose,
  });

  final String conversationId;
  final String peerName;
  final String? peerAvatarUrl;
  final VoidCallback onClose;

  @override
  ConsumerState<_FloatingWhisperPanelWidget> createState() =>
      _FloatingWhisperPanelWidgetState();
}

class _FloatingWhisperPanelWidgetState
    extends ConsumerState<_FloatingWhisperPanelWidget> {
  Offset _position = const Offset(16, 120);
  bool _expanded = true;

  final TextEditingController _controller = TextEditingController();

  Future<void> _sendMessage() async {
    final allowed = await GuestAuthGate.requireMessaging(context, ref);
    if (!allowed) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    final user = ref.read(userProvider);
    if (user == null) return;

    try {
      await ref
          .read(messagingControllerProvider)
          .sendMessage(
            conversationId: widget.conversationId,
            senderId: user.id,
            senderName: user.username,
            senderAvatarUrl: user.avatarUrl,
            content: text,
            clientMessageId:
                '${DateTime.now().microsecondsSinceEpoch}-${user.id}',
          );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FloatingWhisperPanel] send failed: $e\n$st');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    const width = 280.0;
    const expandedHeight = 340.0;
    const collapsedHeight = 44.0;

    return Positioned(
      left: _position.dx.clamp(0, size.width - width),
      top: _position.dy.clamp(
        0,
        size.height - (_expanded ? expandedHeight : collapsedHeight),
      ),
      width: width,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onPanUpdate: (d) {
                setState(() => _position += d.delta);
              },
              child: Container(
                height: 44,
                color: const Color(0xFF282C36),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.drag_indicator,
                      size: 18,
                      color: Color(0xFFB09080),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.peerName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF2EBE0),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _expanded = !_expanded),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: widget.onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),

            if (_expanded) ...[
              SizedBox(
                height: 240,
                child: _MessageList(conversationId: widget.conversationId),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'message…',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageList extends ConsumerWidget {
  const _MessageList({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(messageStreamProvider(conversationId));

    return stream.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (message) {
        if (message.isEmpty) {
          return const Center(child: Text('No message yet'));
        }

        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(8),
          itemCount: message.length,
          itemBuilder: (_, i) {
            final msg = message[message.length - 1 - i];
            return _Bubble(message: msg);
          },
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${message.senderName}: ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFFD4A853),
              ),
            ),
            TextSpan(
              text: message.content,
              style: const TextStyle(fontSize: 12, color: Color(0xFFF2EBE0)),
            ),
          ],
        ),
      ),
    );
  }
}



