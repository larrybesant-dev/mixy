import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/dev/app_state_reasoning.dart';

void main() {
  group('explainCollectionVisibility', () {
    test('reports loading state clearly', () {
      final reason = explainCollectionVisibility(
        sourceName: 'rooms',
        isLoading: true,
        hasError: false,
        totalCount: 0,
        visibleCount: 0,
        filterLabel: 'all',
      );

      expect(reason.stateLabel, 'loading');
      expect(reason.primaryReason, contains('loading'));
      expect(reason.confidence, StateReasonConfidence.medium);
      expect(reason.confidenceLabel, 'expected delay');
    });

    test('reports filter-driven emptiness', () {
      final reason = explainCollectionVisibility(
        sourceName: 'rooms',
        isLoading: false,
        hasError: false,
        totalCount: 4,
        visibleCount: 0,
        filterLabel: 'music',
      );

      expect(reason.stateLabel, 'filtered');
      expect(reason.primaryReason, contains('filter'));
      expect(reason.confidence, StateReasonConfidence.high);
    });

    test('reports cautious emptiness when backend confirmation is missing', () {
      final reason = explainCollectionVisibility(
        sourceName: 'rooms',
        isLoading: false,
        hasError: false,
        totalCount: 0,
        visibleCount: 0,
        filterLabel: 'all',
      );

      expect(reason.stateLabel, 'empty');
      expect(reason.primaryReason, contains('visible'));
      expect(reason.confidence, StateReasonConfidence.low);
      expect(reason.confidenceLabel, 'low confidence');
    });

    test('reports confirmed backend emptiness when explicitly verified', () {
      final reason = explainCollectionVisibility(
        sourceName: 'rooms',
        isLoading: false,
        hasError: false,
        totalCount: 0,
        visibleCount: 0,
        filterLabel: 'all',
        isBackendConfirmed: true,
      );

      expect(reason.stateLabel, 'empty');
      expect(reason.primaryReason, contains('backend'));
      expect(reason.confidence, StateReasonConfidence.confirmed);
      expect(reason.confidenceLabel, 'confirmed backend');
    });

    test('reports ready state when items are visible', () {
      final reason = explainCollectionVisibility(
        sourceName: 'rooms',
        isLoading: false,
        hasError: false,
        totalCount: 5,
        visibleCount: 3,
        filterLabel: 'all',
      );

      expect(reason.stateLabel, 'ready');
      expect(reason.primaryReason, contains('visible'));
      expect(reason.confidence, StateReasonConfidence.high);
      expect(reason.confidenceLabel, 'high confidence');
    });
  });

  group('explainLiveRoomHydration', () {
    test('reports hydrating state with expected delay confidence', () {
      final reason = explainLiveRoomHydration(
        lifecycleLabel: 'hydrating',
        userCount: 0,
        pendingCount: 2,
      );

      expect(reason.stateLabel, 'hydrating');
      expect(reason.confidence, StateReasonConfidence.medium);
      expect(reason.confidenceLabel, 'expected delay');
    });

    test('reports ended state as confirmed', () {
      final reason = explainLiveRoomHydration(
        lifecycleLabel: 'ended',
        userCount: 0,
        pendingCount: 0,
      );

      expect(reason.stateLabel, 'ended');
      expect(reason.confidence, StateReasonConfidence.confirmed);
      expect(reason.confidenceLabel, 'confirmed state');
    });

    test('reports degraded lifecycle as degraded instead of empty', () {
      final reason = explainLiveRoomHydration(
        lifecycleLabel: 'degraded',
        userCount: 0,
        pendingCount: 0,
      );

      expect(reason.stateLabel, 'degraded');
      expect(reason.primaryReason, contains('degraded'));
      expect(reason.confidence, StateReasonConfidence.high);
    });
  });
}
