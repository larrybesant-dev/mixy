import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../providers/cam_view_request_provider.dart';

Future<bool?> showCamViewRequestDialog(
  BuildContext context, {
  required CamViewRequest request,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => CamViewRequestDialog(request: request),
  );
}

class CamViewRequestDialog extends StatelessWidget {
  const CamViewRequestDialog({super.key, required this.request});

  final CamViewRequest request;

  @override
  Widget build(BuildContext context) {
    final requesterName = (request.requesterName ?? '').trim();
    final displayName = requesterName.isEmpty ? 'A room member' : requesterName;
    final initial = displayName.characters.first.toUpperCase();

    return AlertDialog(
      backgroundColor: VelvetNoir.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      icon: CircleAvatar(
        radius: 28,
        backgroundColor: VelvetNoir.primary.withValues(alpha: 0.16),
        child: Text(
          initial,
          style: GoogleFonts.playfairDisplay(
            color: VelvetNoir.primary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        'Camera view request',
        textAlign: TextAlign.center,
        style: GoogleFonts.playfairDisplay(
          color: VelvetNoir.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: displayName,
              style: const TextStyle(
                color: VelvetNoir.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const TextSpan(
              text: ' wants to view your camera. Allow access?',
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: GoogleFonts.raleway(color: VelvetNoir.onSurfaceVariant),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Decline'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.videocam_rounded),
          label: const Text('Allow'),
        ),
      ],
    );
  }
}
