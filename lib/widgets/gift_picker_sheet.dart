import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../features/room/models/room_gift_catalog.dart';
import '../presentation/providers/user_provider.dart';

/// A bottom sheet for picking and sending a direct (non-room) gift.
///
/// Usage:
/// ```dart
/// await GiftPickerSheet.show(context, ref,
///     recipientId: uid, recipientName: name);
/// ```
class GiftPickerSheet {
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required String recipientId,
    required String recipientName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GiftPickerSheetContent(
        recipientId: recipientId,
        recipientName: recipientName,
        callerRef: ref,
      ),
    );
  }
}

class _GiftPickerSheetContent extends ConsumerStatefulWidget {
  const _GiftPickerSheetContent({
    required this.recipientId,
    required this.recipientName,
    required this.callerRef,
  });

  final String recipientId;
  final String recipientName;
  // Passed in so we can read userProvider from caller's container.
  final WidgetRef callerRef;

  @override
  ConsumerState<_GiftPickerSheetContent> createState() =>
      _GiftPickerSheetContentState();
}

class _GiftPickerSheetContentState
    extends ConsumerState<_GiftPickerSheetContent> {
  RoomGiftItem? _selected;
  bool _sending = false;
  String? _errormessage;

  Future<void> _send() async {
    final gift = _selected;
    if (gift == null) return;

    final currentUser = ref.read(userProvider);
    if (currentUser == null) return;

    setState(() {
      _sending = true;
      _errormessage = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'sendDirectGift',
      );
      await callable.call<Map<String, dynamic>>({
        'receiverId': widget.recipientId,
        'giftId': gift.id,
        'coinCost': gift.coinCost,
        'senderName': currentUser.username,
      });
      if (mounted) Navigator.of(context).pop();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _errormessage = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => _errormessage = 'Failed to send gift.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Send a gift to ${widget.recipientName}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Gift grid
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.85,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: RoomGiftCatalog.items.length,
              itemBuilder: (_, i) {
                final item = RoomGiftCatalog.items[i];
                final isSelected = _selected?.id == item.id;
                return InkWell(
                  onTap: () => setState(() => _selected = item),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          ? theme.colorScheme.primaryContainer.withAlpha(100)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(item.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(
                          item.displayName,
                          style: theme.textTheme.labelSmall,
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          '${item.coinCost} 🪙',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_errormessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errormessage!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_selected == null || _sending) ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.card_giftcard),
              label: Text(
                _selected == null
                    ? 'Pick a gift'
                    : 'Send ${_selected!.displayName} for ${_selected!.coinCost} coins',
              ),
            ),
          ),
        ],
      ),
    );
  }
}



