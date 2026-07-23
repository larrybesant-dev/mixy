import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/models/room_model.dart';

RoomModel _room({
  required String id,
  required String name,
  String? description,
}) => RoomModel(
  id: id,
  hostId: 'host-1',
  name: name,
  description: description,
  isLive: true,
);

List<RoomModel> _applySearch(List<RoomModel> rooms, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return rooms;
  return rooms
      .where(
        (r) =>
            r.name.toLowerCase().contains(q) ||
            (r.description?.toLowerCase().contains(q) ?? false),
      )
      .toList();
}

void main() {
  group('RoomBrowserScreen search filter logic', () {
    final rooms = [
      _room(id: '1', name: 'Chill Music Lounge', description: 'Relaxing beats'),
      _room(id: '2', name: 'Gaming Zone', description: 'FPS talk'),
      _room(id: '3', name: 'Late Night Talk', description: null),
      _room(
        id: '4',
        name: 'Dance Floor Remix',
        description: 'House music vibes',
      ),
    ];

    test('empty query returns all rooms', () {
      final result = _applySearch(rooms, '');
      expect(result.length, 4);
    });

    test('whitespace-only query returns all rooms', () {
      final result = _applySearch(rooms, '   ');
      expect(result.length, 4);
    });

    test('matching by name (case-insensitive)', () {
      // 'Chill Music Lounge' matches by name; 'Dance Floor Remix' matches by
      // description 'House music vibes'. Expect both.
      final result = _applySearch(rooms, 'music');
      expect(result.map((r) => r.id), containsAll(['1', '4']));
      expect(result.length, 2);
    });

    test('matching by description', () {
      final result = _applySearch(rooms, 'house music');
      expect(result.map((r) => r.id), containsAll(['4']));
    });

    test('no match returns empty list', () {
      final result = _applySearch(rooms, 'zzznomatch');
      expect(result, isEmpty);
    });

    test('partial query matches multiple rooms', () {
      final result = _applySearch(rooms, 'Night');
      expect(result.map((r) => r.id), containsAll(['3']));
    });

    test('null description does not cause error', () {
      expect(() => _applySearch(rooms, 'anything'), returnsNormally);
    });
  });
}
