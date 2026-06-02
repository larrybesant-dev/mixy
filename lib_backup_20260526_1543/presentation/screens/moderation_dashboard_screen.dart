import 'package:flutter/material.dart';

import '../../core/layout/app_layout.dart';
import '../../models/moderation_model.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../services/moderation_service.dart';

class ModerationDashboardScreen extends StatefulWidget {
  const ModerationDashboardScreen({super.key});

  @override
  State<ModerationDashboardScreen> createState() =>
      _ModerationDashboardScreenState();
}

class _ModerationDashboardScreenState extends State<ModerationDashboardScreen> {
  final ModerationService _moderationService = ModerationService();
  ModerationStatus? _statusFilter;

  Future<void> _setStatus(
    ReportRecordModel report,
    ModerationStatus status,
  ) async {
    try {
      await _moderationService.updateReportStatus(
        reportId: report.id,
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report ${report.id} marked ${status.name}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update report: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Moderation Dashboard'),
        actions: [
          PopupMenuButton<ModerationStatus?>(
            initialValue: _statusFilter,
            tooltip: 'Filter status',
            onSelected: (value) => setState(() => _statusFilter = value),
            itemBuilder: (context) => [
              const PopupMenuItem<ModerationStatus?>(
                value: null,
                child: Text('All statuses'),
              ),
              ...ModerationStatus.values.map(
                (status) => PopupMenuItem<ModerationStatus?>(
                  value: status,
                  child: Text(status.name),
                ),
              ),
            ],
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ],
      ),
      body: StreamBuilder<List<ReportRecordModel>>(
        stream: _moderationService.watchRecentReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingView(label: 'Loading moderation reports');
          }

          if (snapshot.hasError) {
            return AppErrorView(
              error: snapshot.error ?? 'Unknown error',
              fallbackContext: 'Could not load moderation reports.',
            );
          }

          final allReports = snapshot.data ?? const <ReportRecordModel>[];
          final reports = _statusFilter == null
              ? allReports
              : allReports
                  .where((report) => report.status == _statusFilter)
                  .toList(growable: false);

          if (reports.isEmpty) {
            return const AppEmptyView(
              title: 'No reports found',
              message: 'No reports match the selected filter.',
              icon: Icons.shield_outlined,
            );
          }

          return ListView.separated(
            padding: EdgeInsets.all(context.pageHorizontalPadding),
            itemCount: reports.length,
            separatorBuilder: (__, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final report = reports[index];
              final createdAt = report.createdAt;
              final createdAtLabel = createdAt == null
                  ? 'Unknown time'
                  : '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} '
                      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Report ${report.id}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          Chip(label: Text(report.status.name)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Target: ${report.targetType.name} ${report.targetId}',
                      ),
                      Text('Reporter: ${report.reporterUserId}'),
                      const SizedBox(height: 4),
                      Text('Reason: ${report.reason}'),
                      if (report.details != null && report.details!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Details: ${report.details}'),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        'Submitted: $createdAtLabel',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ModerationStatus.values.map((status) {
                          final isActive = report.status == status;
                          return ChoiceChip(
                            selected: isActive,
                            label: Text(status.name),
                            onSelected: isActive
                                ? null
                                : (_) => _setStatus(report, status),
                          );
                        }).toList(growable: false),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
