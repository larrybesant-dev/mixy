import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../features/room/models/room_gift_catalog.dart';
import '../features/room/providers/room_gift_provider.dart';
import '../features/room/providers/free_gift_allowance_provider.dart';
import '../features/room/providers/room_session_provider.dart';
import '../presentation/providers/user_provider.dart';
import '../core/theme.dart';
import 'buy_coin_modal.dart';

/// A bottom sheet for picking and sending a room gift with recipient selection.
///
/// Usage:
/// ```dart
/// await RoomGiftPickerSheet.show(context, ref, roomId: roomId);
/// ```
class RoomGiftPickerSheet {
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required String roomId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RoomGiftPickerSheetContent(
        roomId: roomId,
        callerRef: ref,
      ),
    );
  }
}

class _RoomGiftPickerSheetContent extends ConsumerStatefulWidget {
  const _RoomGiftPickerSheetContent({
    required this.roomId,
    required this.callerRef,
  });

  final String roomId;
  final WidgetRef callerRef;

  @override
  ConsumerState<_RoomGiftPickerSheetContent> createState() =>
      _RoomGiftPickerSheetContentState();
}

class _RoomGiftPickerSheetContentState
    extends ConsumerState<_RoomGiftPickerSheetContent> {
  RoomGiftItem? _selectedGift;
  String? _selectedRecipientId;
  String? _selectedRecipientName;
  bool _sending = false;
  String? _errorMessage;

  Future<void> _send() async {
    final gift = _selectedGift;
    final recipientId = _selectedRecipientId;
    if (gift == null || recipientId == null) return;

    final currentUser = ref.read(userProvider);
    if (currentUser == null) return;

    final allowance = ref.read(freeGiftAllowanceProvider).value;
    
    // Check if user has allowance or sufficient coins
    if (allowance == null || !allowance.canSendFreeGift) {
      // No free gifts remaining - check if user has coins to pay
      if (mounted) {
        setState(() => _errorMessage = 'no_free_gifts_no_coins');
      }
      return;
    }

    setState(() {
      _sending = true;
      _errorMessage = null;
    });

    try {
      final controller = ref.read(roomGiftControllerProvider);
      await controller.sendGift(
        roomId: widget.roomId,
        receiverId: recipientId,
        receiverName: _selectedRecipientName ?? '',
        senderName: currentUser.username,
        gift: gift,
      );

      // Decrement allowance (invalidate forces a fresh read; fires in background)
      ref.invalidate(useGiftAllowanceFunction);

      if (mounted) Navigator.of(context).pop();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to send gift.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowanceAsync = ref.watch(freeGiftAllowanceProvider);
    final sessionState = ref.watch(roomSessionProvider(widget.roomId));

    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) {
        return Container(
          color: VelvetNoir.surface,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: VelvetNoir.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header with allowance
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Send a Gift',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: VelvetNoir.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  allowanceAsync.when(
                    data: (allowance) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: VelvetNoir.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${allowance.remainingToday} free left',
                        style: const TextStyle(
                          color: VelvetNoir.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    loading: () => const SizedBox(width: 80, height: 28),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Recipient selector
              Text(
                'Who to gift?',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: VelvetNoir.onSurface,
                    ),
              ),
              const SizedBox(height: 12),
              _RecipientSelector(
                sessionState: sessionState,
                selected: _selectedRecipientId,
                onSelected: (id, name) => setState(() {
                  _selectedRecipientId = id;
                  _selectedRecipientName = name;
                }),
              ),
              const SizedBox(height: 24),

              // Gift selector
              Text(
                'Choose gift',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: VelvetNoir.onSurface,
                    ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: RoomGiftCatalog.items.length,
                itemBuilder: (_, i) {
                  final item = RoomGiftCatalog.items[i];
                  final isSelected = _selectedGift?.id == item.id;
                  return InkWell(
                    onTap: () => setState(() => _selectedGift = item),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? VelvetNoir.primary
                              : VelvetNoir.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                        color: isSelected
                            ? VelvetNoir.secondary.withValues(alpha: 0.2)
                            : Colors.transparent,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.displayName,
                            style: const TextStyle(
                              color: VelvetNoir.onSurface,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '${item.coinCost} 🪙',
                            style: const TextStyle(
                              color: VelvetNoir.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Error message
              if (_errorMessage != null) ...[
                if (_errorMessage == 'no_free_gifts_no_coins')
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VelvetNoir.secondary.withValues(alpha: 0.2),
                          border: Border.all(color: VelvetNoir.secondary),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'You\'ve used all your free gifts for today. Buy coins to send more! 🎁',
                          style: TextStyle(
                            color: VelvetNoir.onSurface,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          BuyCoinModal.show(context, ref);
                        },
                        icon: const Icon(Icons.shopping_cart),
                        style: FilledButton.styleFrom(
                          backgroundColor: VelvetNoir.primary,
                          foregroundColor: VelvetNoir.surface,
                        ),
                        label: const Text('Buy Coins Now'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  )
                else
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VelvetNoir.error.withValues(alpha: 0.2),
                          border: Border.all(color: VelvetNoir.error),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: VelvetNoir.onSurface,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
              ],

              // Send button
              FilledButton.icon(
                onPressed: (_selectedGift == null ||
                        _selectedRecipientId == null ||
                        _sending)
                    ? null
                    : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            VelvetNoir.primary,
                          ),
                        ),
                      )
                    : const Icon(Icons.card_giftcard),
                style: FilledButton.styleFrom(
                  backgroundColor: VelvetNoir.primary,
                  foregroundColor: VelvetNoir.surface,
                ),
                label: Text(
                  _selectedGift == null
                      ? 'Pick a gift'
                      : 'Send ${_selectedGift!.displayName}',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Selector for choosing gift recipient from room participants.
class _RecipientSelector extends StatelessWidget {
  final RoomSessionState sessionState;
  final String? selected;
  final Function(String id, String name) onSelected;

  const _RecipientSelector({
    required this.sessionState,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (sessionState.remoteUsers.isEmpty) {
      return const Text(
        'No participants in room',
        style: TextStyle(color: VelvetNoir.onSurface),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final userId in sessionState.remoteUsers)
          _RecipientChip(
            participantId: userId,
            participantName: sessionState.userDisplayNames[userId] ?? userId,
            isSelected: selected == userId,
            onTap: () => onSelected(userId, sessionState.userDisplayNames[userId] ?? userId),
          ),
      ],
    );
  }
}

class _RecipientChip extends StatelessWidget {
  final String participantId;
  final String participantName;
  final bool isSelected;
  final VoidCallback onTap;

  const _RecipientChip({
    required this.participantId,
    required this.participantName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        participantName,
        style: TextStyle(
          color: isSelected ? VelvetNoir.surface : VelvetNoir.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: VelvetNoir.surfaceHigh,
      selectedColor: VelvetNoir.primary,
      side: BorderSide(
        color: isSelected ? VelvetNoir.primary : VelvetNoir.outlineVariant,
      ),
    );
  }
}
