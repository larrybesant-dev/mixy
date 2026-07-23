import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../widgets/safe_network_avatar.dart';
import 'profile_card.dart';

class SocialUserCard extends StatelessWidget {
  const SocialUserCard({
    super.key,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.statusText,
    required this.presenceState,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.onTap,
  });

  final String displayName;
  final String username;
  final String? avatarUrl;
  final String statusText;
  final ProfilePresenceState presenceState;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (presenceState) {
      ProfilePresenceState.online => const Color(0xFF22C55E),
      ProfilePresenceState.recentlyActive => const Color(0xFF86EFAC),
      ProfilePresenceState.inRoom => VelvetNoir.secondaryBright,
      ProfilePresenceState.offline => VelvetNoir.onSurfaceVariant,
    };

    final label = secondaryLabel;

    return Card(
      elevation: 0,
      color: VelvetNoir.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: statusColor, width: 2),
                    ),
                    child: SafeNetworkAvatar(
                      radius: 24,
                      avatarUrl: avatarUrl,
                      backgroundColor: VelvetNoir.surface,
                      fallbackText: displayName.isEmpty
                          ? '?'
                          : displayName[0].toUpperCase(),
                      fallbackTextStyle: GoogleFonts.raleway(
                        fontWeight: FontWeight.w800,
                        color: VelvetNoir.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.raleway(
                            color: VelvetNoir.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.raleway(
                            color: VelvetNoir.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                statusText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.raleway(
                                  color: VelvetNoir.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onPrimaryPressed,
                      child: Text(primaryLabel),
                    ),
                  ),
                  if (label != null &&
                      label.isNotEmpty &&
                      onSecondaryPressed != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSecondaryPressed,
                        child: Text(label),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}



