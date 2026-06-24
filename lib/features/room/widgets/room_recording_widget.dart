import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/room/services/room_recording_service.dart';

/// Room Recording Widget
///
/// Features:
/// - Start/stop/pause/resume recording
/// - Recording timer
/// - Make recording public/private
/// - Recording info display
class RoomRecordingWidget extends ConsumerStatefulWidget {
  final String roomId;
  final String userId;
  final VoidCallback? onRecordingStarted;
  final VoidCallback? onRecordingStopped;

  const RoomRecordingWidget({
    super.key,
    required this.roomId,
    required this.userId,
    this.onRecordingStarted,
    this.onRecordingStopped,
  });

  @override
  ConsumerState<RoomRecordingWidget> createState() =>
      _RoomRecordingWidgetState();
}

class _RoomRecordingWidgetState extends ConsumerState<RoomRecordingWidget>
    with TickerProviderStateMixin {
  late AnimationController _timerAnimationController;
  bool _isPublic = false;

  @override
  void initState() {
    super.initState();
    _timerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _timerAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(roomRecordingServiceProvider);
    final recordingNotifier = ref.read(roomRecordingServiceProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.fiber_manual_record,
                color: recordingState != null
                    ? const Color(0xFFFF4C4C)
                    : Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Recording',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Recording status and timer
          if (recordingState != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: recordingState.state == RecordingState.paused
                              ? Colors.yellow
                              : const Color(0xFFFF4C4C),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        recordingState.state == RecordingState.paused
                            ? 'PAUSED'
                            : 'RECORDING',
                        style: TextStyle(
                          color: recordingState.state == RecordingState.paused
                              ? Colors.yellow
                              : const Color(0xFFFF4C4C),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Timer
                  StreamBuilder<Duration>(
                    stream: Stream.periodic(
                      const Duration(milliseconds: 100),
                      (_) => recordingNotifier.getRecordingDuration(),
                    ),
                    builder: (context, snapshot) {
                      final duration = snapshot.data ?? Duration.zero;
                      final hours = duration.inHours;
                      final minutes = duration.inMinutes.remainder(60);
                      final seconds = duration.inSeconds.remainder(60);

                      return Text(
                        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Color(0xFFFF4C4C),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Recording details
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey[600],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Started: ${_formatTime(recordingState.startTime)}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Control buttons
            Row(
              children: [
                // Pause/Resume button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (recordingState.state == RecordingState.recording) {
                        await recordingNotifier.pauseRecording();
                      } else if (recordingState.state ==
                          RecordingState.paused) {
                        await recordingNotifier.resumeRecording();
                      }
                    },
                    icon: Icon(
                      recordingState.state == RecordingState.paused
                          ? Icons.play_arrow
                          : Icons.pause,
                      size: 18,
                    ),
                    label: Text(
                      recordingState.state == RecordingState.paused
                          ? 'Resume'
                          : 'Pause',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Stop button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showStopRecordingDialog(
                        context,
                        recordingNotifier,
                      );
                    },
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text(
                      'Stop',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4C4C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Privacy toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isPublic ? Icons.public : Icons.lock,
                        color: const Color(0xFFFF4C4C),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isPublic ? 'Public Recording' : 'Private Recording',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isPublic,
                    onChanged: (value) {
                      setState(() => _isPublic = value);
                      recordingNotifier.setRecordingPublic(value);
                    },
                    activeThumbColor: const Color(0xFFFF4C4C),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Start recording button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await ref
                      .read(roomRecordingServiceProvider.notifier)
                      .startRecording(
                        roomId: widget.roomId,
                        userId: widget.userId,
                      );
                  widget.onRecordingStarted?.call();
                },
                icon: const Icon(Icons.fiber_manual_record, size: 20),
                label: const Text(
                  'Start Recording',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4C4C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start recording to capture this room session',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showStopRecordingDialog(
    BuildContext context,
    RoomRecordingServiceNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2F),
        title: const Text(
          'Stop Recording?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to stop the recording? This action cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await notifier.stopRecording(finalFileSize: 0);
              widget.onRecordingStopped?.call();
              if (mounted) {
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recording saved successfully'),
                    duration: Duration(milliseconds: 2000),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4C4C),
            ),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}

