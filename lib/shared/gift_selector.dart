import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/providers.dart';

// Removed unused imports
class GiftSelector extends ConsumerStatefulWidget {
  final String receiverId;
  final String receiverName;
  final String roomId;

  const GiftSelector({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.roomId,
  });

  @override
  ConsumerState<GiftSelector> createState() => _GiftSelectorState();
}

class _GiftSelectorState extends ConsumerState<GiftSelector> {
  final _messageController = TextEditingController();
  int _selectedAmount = 10;

  final List<Map<String, dynamic>> _gifts = [
    {'name': 'Rose', 'amount': 5, 'emoji': 'ðŸŒ¹'},
    {'name': 'Heart', 'amount': 10, 'emoji': 'â¤ï¸'},
    {'name': 'Diamond', 'amount': 25, 'emoji': 'ðŸ’Ž'},
    {'name': 'Crown', 'amount': 50, 'emoji': 'ðŸ‘‘'},
    {'name': 'Rocket', 'amount': 100, 'emoji': 'ðŸš€'},
    {'name': 'Castle', 'amount': 250, 'emoji': 'ðŸ°'},
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendTip() async {
    try {
      await ref.read(sendTipProvider({
        'receiverId': widget.receiverId,
        'receiverName': widget.receiverName,
        'amount': _selectedAmount,
        'message': _messageController.text.trim(),
        'roomId': widget.roomId,
      }).future);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Sent $_selectedAmount coins to ${widget.receiverName}!'),
            backgroundColor: const Color(0xFFFFD700),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send tip: ${e.toString()}'),
            backgroundColor: const Color(0xFFFF4C4C),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFF4C4C).withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              'Send Gift to ${widget.receiverName}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFD700),
              ),
            ),
            const SizedBox(height: 20),

            // Coin balance
            currentUser.when(
              data: (user) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: Color(0xFFFFD700)),
                    const SizedBox(width: 8),
                    Text(
                      '${user?.coinBalance ?? 0} coins',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // Gift selection grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: _gifts.length,
              itemBuilder: (context, index) {
                final gift = _gifts[index];
                final isSelected = gift['amount'] == _selectedAmount;

                return GestureDetector(
                  onTap: () => setState(() => _selectedAmount = gift['amount']),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF4C4C).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF4C4C)
                            : Colors.white.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          gift['emoji'],
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gift['name'],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        Text(
                          '${gift['amount']}',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 10,
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

            // Message input
            TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add a message (optional)',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFFD700)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFFD700)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFFFF4C4C), width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFF2A2A3E).withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 20),

            // Send button
            ElevatedButton(
              onPressed: _sendTip,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4C4C),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Send $_selectedAmount Coins'),
            ),
          ],
        ),
      ),
    );
  }
}

// Removed unused imports
