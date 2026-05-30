import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'connections_providers.dart';

class PendingRequestsScreen extends ConsumerWidget {
  const PendingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(dummyPendingRequestsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF110D0F),
        title: Text(
          'Friend Requests',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFFD4AF37),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      body: requests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No pending requests',
                    style: GoogleFonts.montserrat(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final user = requests[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1416),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                            ? CachedNetworkImageProvider(user.avatarUrl!)
                            : null,
                        child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.username,
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Wants to connect with you',
                              style: GoogleFonts.montserrat(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _ActionButton(
                            icon: Icons.check,
                            color: const Color(0xFFD4AF37),
                            onTap: () {
                              _handleResponse(ref, user.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Accepted ${user.username}')),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.close,
                            color: Colors.redAccent,
                            onTap: () {
                              _handleResponse(ref, user.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Ignored ${user.username}')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _handleResponse(WidgetRef ref, String userId) {
    // Remove the user from the dummy list
    ref.read(dummyPendingRequestsProvider.notifier).update((state) {
      return state.where((u) => u.id != userId).toList();
    });
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}



