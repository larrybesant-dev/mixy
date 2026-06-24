import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/shared/models/report.dart';
import 'package:mixmingle/shared/providers/providers.dart';

/// Dialog for blocking or reporting a user
class BlockReportDialog extends ConsumerStatefulWidget {
  final String userId;
  final String userName;

  const BlockReportDialog({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  ConsumerState<BlockReportDialog> createState() => _BlockReportDialogState();
}

class _BlockReportDialogState extends ConsumerState<BlockReportDialog> {
  bool _isBlocking = false;
  bool _isReporting = false;
  ReportType? _selectedReportType;
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Actions for ${widget.userName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Block Button
            ElevatedButton.icon(
              onPressed: _isBlocking ? null : _handleBlock,
              icon: const Icon(Icons.block),
              label: Text(_isBlocking ? 'Blocking...' : 'Block User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            const Divider(),
            const SizedBox(height: 8),

            // Report Section
            const Text(
              'Report User',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Report Type Dropdown
            DropdownButtonFormField<ReportType>(
              initialValue: _selectedReportType,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              items: ReportType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getReportTypeLabel(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedReportType = value;
                });
              },
            ),
            const SizedBox(height: 12),

            // Description TextField
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
                hintText: 'Provide details about the issue...',
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 12),

            // Report Button
            ElevatedButton.icon(
              onPressed: _selectedReportType == null || _isReporting
                  ? null
                  : _handleReport,
              icon: const Icon(Icons.flag),
              label: Text(_isReporting ? 'Reporting...' : 'Submit Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _handleBlock() async {
    setState(() => _isBlocking = true);

    try {
      final currentUser = ref.read(currentUserProvider);
      final user = currentUser.value;
      if (user == null) throw Exception('Not authenticated');

      final moderationService = ref.read(moderationServiceProvider);
      await moderationService.blockUser(
        user.id,
        widget.userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.userName} has been blocked')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to block user: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBlocking = false);
      }
    }
  }

  Future<void> _handleReport() async {
    if (_selectedReportType == null) return;

    setState(() => _isReporting = true);

    try {
      final currentUser = ref.read(currentUserProvider);
      final user = currentUser.value;
      if (user == null) throw Exception('Not authenticated');

      final moderationService = ref.read(moderationServiceProvider);
      await moderationService.reportUser(
        reporterId: user.id,
        reportedUserId: widget.userId,
        type: _selectedReportType!,
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully. Thank you!'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isReporting = false);
      }
    }
  }

  String _getReportTypeLabel(ReportType type) {
    switch (type) {
      case ReportType.spam:
        return 'Spam';
      case ReportType.harassment:
        return 'Harassment';
      case ReportType.inappropriateContent:
        return 'Inappropriate Content';
      case ReportType.hateSpeech:
        return 'Hate Speech';
      case ReportType.violence:
        return 'Violence or Threats';
      case ReportType.scam:
        return 'Scam or Fraud';
      case ReportType.other:
        return 'Other';
    }
  }
}

/// Simple function to show the block/report dialog
Future<bool?> showBlockReportDialog(
  BuildContext context,
  String userId,
  String userName,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) => BlockReportDialog(
      userId: userId,
      userName: userName,
    ),
  );
}
