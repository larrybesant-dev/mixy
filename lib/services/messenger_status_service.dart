import 'package:cloud_firestore/cloud_firestore.dart';

import 'schema_mutation_service.dart';

class MessengerProfileStatus {
  const MessengerProfileStatus({
    this.statusMessage = '',
    this.availability = 'online',
  });

  final String statusMessage;
  final String availability;
}

abstract class MessengerStatusService {
  Stream<MessengerProfileStatus> watchProfileStatus(String userId);

  Future<void> updateStatusMessage(String userId, String statusMessage);

  Future<void> updateAvailability(String userId, String availability);
}

class FirestoreMessengerStatusService implements MessengerStatusService {
  FirestoreMessengerStatusService(
    this._firestore, {
    SchemaMutationService? mutationService,
  }) : _mutationService =
            mutationService ?? SchemaMutationService(firestore: _firestore);

  final FirebaseFirestore _firestore;
  final SchemaMutationService _mutationService;

  @override
  Stream<MessengerProfileStatus> watchProfileStatus(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream.value(const MessengerProfileStatus());
    }

    return _firestore
        .collection('users')
        .doc(normalizedUserId)
        .snapshots()
        .map((
      snapshot,
    ) {
      final data = snapshot.data();
      final message = data?['statusMessage'];
      final availability = data?['messengerStatus'];
      final normalizedAvailability =
          availability is String ? availability.trim().toLowerCase() : 'online';
      return MessengerProfileStatus(
        statusMessage: message is String ? message.trim() : '',
        availability: const {
          'online',
          'away',
          'dnd',
        }.contains(normalizedAvailability)
            ? normalizedAvailability
            : 'online',
      );
    });
  }

  @override
  Future<void> updateStatusMessage(
    String userId,
    String statusMessage,
  ) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'User ID is required.');
    }

    await _mutationService.updateMessengerStatus(
      userId: normalizedUserId,
      statusMessage: statusMessage.trim(),
    );
  }

  @override
  Future<void> updateAvailability(
    String userId,
    String availability,
  ) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'User ID is required.');
    }
    final normalizedAvailability = availability.trim().toLowerCase();
    if (!const {'online', 'away', 'dnd'}.contains(normalizedAvailability)) {
      throw ArgumentError.value(
        availability,
        'availability',
        'Availability must be online, away, or dnd.',
      );
    }

    await _mutationService.updateMessengerStatus(
      userId: normalizedUserId,
      availability: normalizedAvailability,
    );
  }
}
