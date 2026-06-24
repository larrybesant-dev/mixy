// Riverpod provider for Connections
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connection.dart';

// Connections state notifier
class ConnectionsNotifier extends Notifier<List<Connection>> {
  @override
  List<Connection> build() => [];

  void addConnection(Connection connection) {
    state = [...state, connection];
  }

  void removeConnection(String connectionId) {
    state = state.where((c) => c.id != connectionId).toList();
  }

  void clear() {
    state = [];
  }
}

final connectionsProvider = NotifierProvider<ConnectionsNotifier, List<Connection>>(
  () => ConnectionsNotifier(),
);
