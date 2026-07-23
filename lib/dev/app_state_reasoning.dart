import 'package:flutter/material.dart';

class StateReasonSummary {
  const StateReasonSummary({
    required this.stateLabel,
    required this.primaryReason,
    this.details = const <String>[],
    this.severity = StateReasonSeverity.info,
    this.confidence = StateReasonConfidence.medium,
    this.confidenceNote,
  });

  final String stateLabel;
  final String primaryReason;
  final List<String> details;
  final StateReasonSeverity severity;
  final StateReasonConfidence confidence;
  final String? confidenceNote;

  String get confidenceLabel =>
      confidenceNote ??
      switch (confidence) {
        StateReasonConfidence.low => 'low confidence',
        StateReasonConfidence.medium => 'expected delay',
        StateReasonConfidence.high => 'high confidence',
        StateReasonConfidence.confirmed => 'confirmed state',
      };
}

enum StateReasonSeverity { info, success, warning, error }

enum StateReasonConfidence { low, medium, high, confirmed }

StateReasonSummary explainCollectionVisibility({
  required String sourceName,
  required bool isLoading,
  required bool hasError,
  required int totalCount,
  required int visibleCount,
  required String filterLabel,
  String? errormessage,
  bool isBackendConfirmed = false,
}) {
  final source = sourceName.trim().isEmpty ? 'items' : sourceName.trim();
  final filter = filterLabel.trim().isEmpty ? 'all' : filterLabel.trim();
  final lowerFilter = filter.toLowerCase();

  if (isLoading) {
    return StateReasonSummary(
      stateLabel: 'loading',
      primaryReason:
          'The $source are still loading, so the screen may look temporarily empty.',
      details: ['source=$source', 'filter=$filter'],
      confidence: StateReasonConfidence.medium,
      confidenceNote: 'expected delay',
    );
  }

  if (hasError) {
    return StateReasonSummary(
      stateLabel: 'error',
      primaryReason: errormessage?.trim().isNotEmpty == true
          ? errormessage!.trim()
          : 'The $source stream returned an error.',
      details: ['source=$source', 'filter=$filter'],
      severity: StateReasonSeverity.error,
      confidence: StateReasonConfidence.high,
    );
  }

  if (totalCount == 0) {
    return StateReasonSummary(
      stateLabel: 'empty',
      primaryReason: isBackendConfirmed
          ? 'No live rooms are currently available from the backend.'
          : 'No visible $source have been confirmed yet from the current stream.',
      details: ['source=$source', 'filter=$filter', 'total=0'],
      severity: StateReasonSeverity.warning,
      confidence: isBackendConfirmed
          ? StateReasonConfidence.confirmed
          : StateReasonConfidence.low,
      confidenceNote: isBackendConfirmed ? 'confirmed backend' : null,
    );
  }

  if (visibleCount == 0 && lowerFilter != 'all') {
    return StateReasonSummary(
      stateLabel: 'filtered',
      primaryReason: 'The current filter is hiding all available $source.',
      details: ['source=$source', 'filter=$filter', 'total=$totalCount'],
      severity: StateReasonSeverity.warning,
      confidence: StateReasonConfidence.high,
    );
  }

  if (visibleCount == 0) {
    return StateReasonSummary(
      stateLabel: 'gated',
      primaryReason:
          'Visibility or permission rules are currently hiding the available $source.',
      details: ['source=$source', 'filter=$filter', 'total=$totalCount'],
      severity: StateReasonSeverity.warning,
      confidence: StateReasonConfidence.medium,
      confidenceNote: 'moderate confidence',
    );
  }

  return StateReasonSummary(
    stateLabel: 'ready',
    primaryReason: 'There are visible $source and the screen is hydrated.',
    details: ['source=$source', 'filter=$filter', 'visible=$visibleCount'],
    severity: StateReasonSeverity.success,
    confidence: StateReasonConfidence.high,
  );
}

StateReasonSummary explainLiveRoomHydration({
  required String lifecycleLabel,
  required int userCount,
  required int pendingCount,
  String? errormessage,
}) {
  final normalizedLifecycle = lifecycleLabel.trim().isEmpty
      ? 'unknown'
      : lifecycleLabel.trim().toLowerCase();

  if (errormessage?.trim().isNotEmpty == true) {
    return StateReasonSummary(
      stateLabel: 'error',
      primaryReason: errormessage!.trim(),
      details: ['lifecycle=$normalizedLifecycle', 'users=$userCount'],
      severity: StateReasonSeverity.error,
      confidence: StateReasonConfidence.high,
    );
  }

  if (normalizedLifecycle == 'ended') {
    return StateReasonSummary(
      stateLabel: 'ended',
      primaryReason:
          'The room has ended, so active content is no longer expected.',
      details: ['lifecycle=$normalizedLifecycle'],
      severity: StateReasonSeverity.warning,
      confidence: StateReasonConfidence.confirmed,
      confidenceNote: 'confirmed state',
    );
  }

  if (normalizedLifecycle == 'degraded') {
    return StateReasonSummary(
      stateLabel: 'degraded',
      primaryReason:
          'The room state is degraded, so presence or media may be temporarily out of sync.',
      details: ['lifecycle=$normalizedLifecycle', 'users=$userCount'],
      severity: StateReasonSeverity.warning,
      confidence: StateReasonConfidence.high,
    );
  }

  if (normalizedLifecycle == 'initializing' ||
      normalizedLifecycle == 'hydrating') {
    return StateReasonSummary(
      stateLabel: 'hydrating',
      primaryReason:
          'Room state is still hydrating, so participants or media may appear delayed.',
      details: [
        'lifecycle=$normalizedLifecycle',
        'users=$userCount',
        'pending=$pendingCount',
      ],
      confidence: StateReasonConfidence.medium,
      confidenceNote: 'expected delay',
    );
  }

  if (userCount == 0) {
    return StateReasonSummary(
      stateLabel: 'empty',
      primaryReason: 'No confirmed room members are present yet.',
      details: ['lifecycle=$normalizedLifecycle', 'pending=$pendingCount'],
      severity: StateReasonSeverity.warning,
      confidence: StateReasonConfidence.low,
    );
  }

  return StateReasonSummary(
    stateLabel: 'ready',
    primaryReason:
        'Room state is active and confirmed participants are present.',
    details: ['lifecycle=$normalizedLifecycle', 'users=$userCount'],
    severity: StateReasonSeverity.success,
    confidence: StateReasonConfidence.high,
  );
}

class StateReasonCard extends StatelessWidget {
  const StateReasonCard({
    super.key,
    required this.title,
    required this.summary,
    required this.metrics,
    this.backgroundColor,
    this.borderColor,
    this.titleColor,
    this.textColor,
    this.metricChipBuilder,
  });

  final String title;
  final StateReasonSummary summary;
  final List<String> metrics;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? titleColor;
  final Color? textColor;
  final Widget Function(String label)? metricChipBuilder;

  @override
  Widget build(BuildContext context) {
    final foreground = textColor ?? Colors.white70;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              borderColor ??
              _severityColor(summary.severity).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: titleColor ?? _severityColor(summary.severity),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FallbackChip(
                label: 'state: ${summary.stateLabel}',
                textColor: foreground,
              ),
              _FallbackChip(
                label: 'confidence: ${summary.confidenceLabel}',
                textColor: foreground,
              ),
              if (metricChipBuilder != null)
                ...metrics.map(metricChipBuilder!)
              else
                ...metrics.map(
                  (label) => _FallbackChip(label: label, textColor: foreground),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Why: ${summary.primaryReason}',
            style: TextStyle(
              fontSize: 12,
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (summary.details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: summary.details
                  .map(
                    (detail) =>
                        _FallbackChip(label: detail, textColor: foreground),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  static Color _severityColor(StateReasonSeverity severity) {
    switch (severity) {
      case StateReasonSeverity.success:
        return const Color(0xFFA5D6A7);
      case StateReasonSeverity.warning:
        return const Color(0xFFFFCC80);
      case StateReasonSeverity.error:
        return const Color(0xFFEF9A9A);
      case StateReasonSeverity.info:
        return const Color(0xFF90CAF9);
    }
  }
}

class _FallbackChip extends StatelessWidget {
  const _FallbackChip({required this.label, required this.textColor});

  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}



