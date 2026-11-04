import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/providers/floating_cam_provider.dart';
import 'package:mixvy/features/room/widgets/floating_cam_window.dart';

void main() {
  test('tracks an Offset and window state for every active stream id', () {
    final notifier = FloatingCamStateNotifier();

    notifier.syncActiveStreamIds(const ['local', 'remote_42']);

    expect(notifier.state.keys, containsAll(const ['local', 'remote_42']));
    expect(notifier.state['local']?.position, isA<Offset>());
    expect(notifier.state['remote_42']?.position, isA<Offset>());
    expect(
      notifier.state['local']?.position,
      isNot(notifier.state['remote_42']?.position),
    );

    notifier.detach('remote_42');
    notifier.moveBy('remote_42', const Offset(30, 20));
    notifier.resizeBy('remote_42', const Offset(40, 25));
    notifier.setMinimized('remote_42', true);

    final remote = notifier.state['remote_42']!;
    expect(remote.position, const Offset(126, 140));
    expect(remote.size, const Size(320, 225));
    expect(remote.isDetached, isTrue);
    expect(remote.isMinimized, isTrue);
    expect(remote.zIndex, greaterThan(notifier.state['local']!.zIndex));

    notifier.syncActiveStreamIds(const ['local']);
    expect(notifier.state.keys, const ['local']);
  });

  testWidgets('dragging a floating camera header updates provider position', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier =
        container.read(floatingCamStatesProvider('room-1').notifier);
    notifier.syncActiveStreamIds(const ['remote_42']);
    notifier.detach('remote_42');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: FloatingCamWindowLayer(
                roomId: 'room-1',
                labels: const {'remote_42': 'Camera 42'},
                contentBuilder: (_) => const ColoredBox(
                  color: Color(0xFF000000),
                  child: Text('Remote stream'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final header = find.byKey(
      const ValueKey('floating_panel_header_remote_42'),
    );
    expect(header, findsOneWidget);
    final originalPosition = notifier.state['remote_42']!.position;

    await tester.drag(header, const Offset(40, 25));
    await tester.pump();

    final draggedPosition = notifier.state['remote_42']!.position;
    expect(draggedPosition.dx, greaterThan(originalPosition.dx));
    expect(draggedPosition.dy, greaterThan(originalPosition.dy));
    expect(find.text('Remote stream'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
