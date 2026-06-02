import 'startup_pipeline_models.dart';

class StartupTrendEngine {
  const StartupTrendEngine();

  TrendAnalysis analyze({
    required List<Map<String, Object?>> entries,
    required int window,
  }) {
    if (entries.length < 2) {
      return const TrendAnalysis(
        status: TrendStatus.stable,
        slopePct: 0,
        driftPct: 0,
        variance: 0,
        sampleCount: 0,
      );
    }

    final int start = entries.length > window ? entries.length - window : 0;
    final List<Map<String, Object?>> recent = entries.sublist(start);

    final List<double> series = <double>[];
    for (final Map<String, Object?> entry in recent) {
      final Object? score = entry['score'];
      if (score is num) {
        series.add(score.toDouble());
      }
    }

    if (series.length < 2) {
      return const TrendAnalysis(
        status: TrendStatus.stable,
        slopePct: 0,
        driftPct: 0,
        variance: 0,
        sampleCount: 0,
      );
    }

    final int n = series.length;
    double sumX = 0;
    double sumY = 0;
    double sumXX = 0;
    double sumXY = 0;

    for (int i = 0; i < n; i++) {
      final double x = i.toDouble();
      final double y = series[i];
      sumX += x;
      sumY += y;
      sumXX += x * x;
      sumXY += x * y;
    }

    final double denominator = (n * sumXX) - (sumX * sumX);
    final double slope =
        denominator == 0 ? 0 : ((n * sumXY) - (sumX * sumY)) / denominator;

    final double mean = sumY / n;
    final double slopePct = mean == 0 ? 0 : slope / mean;

    final double first = series.first;
    final double last = series.last;
    final double driftPct = first == 0 ? 0 : ((last - first) / first);

    double variance = 0;
    for (final double value in series) {
      final double diff = value - mean;
      variance += diff * diff;
    }
    variance = variance / n;

    final TrendStatus status;
    if (slopePct > 0.05) {
      status = TrendStatus.regressing;
    } else if (slopePct > 0.02) {
      status = TrendStatus.degrading;
    } else {
      status = TrendStatus.stable;
    }

    return TrendAnalysis(
      status: status,
      slopePct: slopePct,
      driftPct: driftPct,
      variance: variance,
      sampleCount: n,
    );
  }
}
