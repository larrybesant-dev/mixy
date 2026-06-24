import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/services/camera/camera_permission_service.dart';

class CameraPermissionRequestDialog extends ConsumerStatefulWidget {
  final String ownerId;
  final String ownerName;
  final String? channelId;

  const CameraPermissionRequestDialog({
    super.key,
    required this.ownerId,
    required this.ownerName,
    this.channelId,
  });

  @override
  ConsumerState<CameraPermissionRequestDialog> createState() =>
      _CameraPermissionRequestDialogState();
}

class _CameraPermissionRequestDialogState
    extends ConsumerState<CameraPermissionRequestDialog> {
  bool _isRequesting = false;
  Duration? _selectedDuration;

  final List<Duration?> _durationOptions = const [
    null, // Permanent
    Duration(hours: 1),
    Duration(hours: 24),
    Duration(days: 7),
  ];

  String _getDurationLabel(Duration? duration) {
    if (duration == null) return 'Until revoked';
    if (duration.inDays >= 7) return '${duration.inDays} days';
    if (duration.inHours >= 24) {
      return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    }
    return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
  }

  Future<void> _requestPermission() async {
    setState(() => _isRequesting = true);

    try {
      await CameraPermissionService().requestCameraPermission(
        ownerId: widget.ownerId,
        channelId: widget.channelId,
        duration: _selectedDuration,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission request sent to ${widget.ownerName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on CameraPermissionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFF4C4C), width: 2),
      ),
      title: const Row(
        children: [
          Icon(Icons.videocam, color: Color(0xFFFF4C4C)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Request Camera Access',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request permission to view ${widget.ownerName}\'s camera?',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Text(
            'Duration:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_durationOptions.length, (index) {
            final duration = _durationOptions[index];
            // ignore: deprecated_member_use
            return RadioListTile<Duration?>(
              value: duration,
              // ignore: deprecated_member_use
              groupValue: _selectedDuration,
              // ignore: deprecated_member_use
              onChanged: (val) => setState(() => _selectedDuration = val),
              title: Text(
                _getDurationLabel(duration),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              activeColor: const Color(0xFFFF4C4C),
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isRequesting ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        ElevatedButton(
          onPressed: _isRequesting ? null : _requestPermission,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF4C4C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isRequesting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Request', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

