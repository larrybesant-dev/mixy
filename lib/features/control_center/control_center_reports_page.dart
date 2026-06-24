// lib/features/control_center/control_center_reports_page.dart
//
// Admin view of pending content reports: review, resolve, dismiss.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/core/design_system/design_constants.dart';
import 'package:mixvy/features/control_center/providers/control_center_providers.dart';
import 'package:mixvy/features/control_center/services/audit_log_service.dart';
import 'package:mixvy/services/events/reporting_service.dart';

class ControlCenterReportsPage extends ConsumerWidget {
  const ControlCenterReportsPage({super.key});

  Future<void> _updateReport(
    BuildContext context,
    String reportId,
    String reportedId,
    ReportStatus status,
  ) async {
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .update({
      'status': status.name,
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    final action = status == ReportStatus.resolved
        ? ActionType.resolveReport
        : ActionType.dismissReport;

    await AuditLogService.instance.logAction(
      actionType: action,
      targetId: reportedId,
      metadata: {'reportId': reportId},
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == ReportStatus.resolved
              ? 'Report resolved'
              : 'Report dismissed'),
          backgroundColor: status == ReportStatus.resolved
              ? Colors.orange
              : Colors.grey,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(pendingReportsProvider);

    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.red))),
      data: (reports) {
        if (reports.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle,
                    color: Colors.green, size: 64),
                SizedBox(height: 16),
                Text('No pending reports',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, i) {
            final r = reports[i];
            final reportId = r['id'] as String;
            final reportedId = r['reportedId'] as String? ?? '';
            final type = r['type'] as String? ?? '—';
            final reason = r['reason'] as String? ?? '—';
            final info = r['additionalInfo'] as String?;
            final reporterId = r['reporterId'] as String? ?? '—';

            return Card(
              color: DesignColors.surfaceLight,
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flag,
                            color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          type.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          reason.replaceAllMapped(
                            RegExp(r'([A-Z])'),
                            (m) => ' ${m.group(0)}',
                          ).trim(),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reported ID: $reportedId',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                    Text(
                      'Reporter: $reporterId',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11),
                    ),
                    if (info != null && info.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        info,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Colors.white38),
                            foregroundColor: Colors.white54,
                          ),
                          onPressed: () => _updateReport(
                            context,
                            reportId,
                            reportedId,
                            ReportStatus.dismissed,
                          ),
                          child: const Text('Dismiss'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _updateReport(
                            context,
                            reportId,
                            reportedId,
                            ReportStatus.resolved,
                          ),
                          child: const Text('Resolve'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

