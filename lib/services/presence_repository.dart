import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firestore/firestore_debug_tracing.dart';
import '../core/streams/stream_lifecycle_manager.dart';
import '../models/presence_model.dart';
import 'presence_gateway.dart';

abstract class PresenceRepository {
  Stream<PresenceModel> watchUserPresence(String userId);
  Stream<bool> userPresenceStream(String userId);
  Stream<Map<String, PresenceModel>> watchUsersPresence(List<String> userIds);
  Future<Map<String, PresenceModel>> getUsersPresence(List<String> userIds);
  Future<int> countOnlineUsers({int limit = 500});
}

final presenceRepositoryProvider = Provider<PresenceRepository>((ref) {
  return FirestorePresenceRepository(
    ref.watch(presenceGatewayProvider),
    streamLifecycleManager: ref.watch(streamLifecycleManagerProvider),
  );
});

class FirestorePresenceRepository implements PresenceRepository {
  FirestorePresenceRepository(
    this._gateway, {
    required StreamLifecycleManager streamLifecycleManager,
  }) : _streamLifecycleManager = streamLifecycleManager;

  static const int _firestoreWhereInLimit = 30;
  static const Duration _transientOfflineHold = Duration(seconds: 8);

  final PresenceGateway _gateway;
  final StreamLifecycleManager _streamLifecycleManager;

  bool _isPermissionDenied(Object error) {
    if (error is FirebaseException) {
      final code = error.code.trim().toLowerCase();
      return code == 'permission-denied' ||
          code == 'unauthenticated' ||
          code == 'unauthorized';
    }
    final normalized = error.toString().toLowerCase();
    return normalized.contains('permission-denied') ||
        normalized.contains('insufficient permissions') ||
        normalized.contains('unauthenticated') ||
        normalized.contains('unauthorized');
  }

  List<List<String>> _chunksOf(List<String> values, int size) {
    if (values.isEmpty) {
      return const <List<String>>[];
    }

    final chunks = <List<String>>[];
    for (var index = 0; index < values.length; index += size) {
      final end = (index + size) > values.length ? values.length : index + size;
      chunks.add(values.sublist(index, end));
    }
    return chunks;
  }

  PresenceModel _parsePresence(String userId, Map<String, dynamic>? data) {
    if (data == null) {
      return PresenceModel(
        userId: userId,
        isOnline: false,
        online: false,
        status: UserStatus.offline,
      );
    }
    return PresenceModel.fromJson({'userId': userId, ...data});
  }

  bool _isFresh(DateTime? value, Duration threshold) {
    if (value == null) {
      return false;
    }
    return DateTime.now().difference(value) <= threshold;
  }

  PresenceModel _arbitratePresence(
    String userId,
    PresenceModel next, {
    PresenceModel? previous,
  }) {
    if (previous == null) {
      return next;
    }

    final nextOnline = next.isOnline == true;
    final previousOnline = previous.isOnline == true;
    if (nextOnline || !previousOnline) {
      return next;
    }

    final recentSignal =
        next.activeSessionCount > 0 ||
        _isFresh(next.lastSeen, _transientOfflineHold) ||
        _isFresh(previous.lastSeen, _transientOfflineHold);

    if (!recentSignal) {
      return next;
    }

    developer.log(
      'presence_offline_hold_applied userId=$userId lastSeen=${next.lastSeen?.toIso8601String() ?? previous.lastSeen?.toIso8601String() ?? '-'}',
      name: 'PresenceRepository',
    );

    return next.copyWith(
      isOnline: true,
      online: true,
      status: previous.status == UserStatus.offline
          ? UserStatus.online
          : previous.status,
      inRoom: next.inRoom ?? previous.inRoom,
      roomId: next.roomId ?? previous.roomId,
      activeSessionCount: next.activeSessionCount > 0
          ? next.activeSessionCount
          : previous.activeSessionCount,
    );
  }

  @override
  Stream<PresenceModel> watchUserPresence(String userId) {
    return Stream.multi((controller) {
      PresenceModel? lastPresence;
      final subscription =
          traceFirestoreStream<PresenceModel>(
            key: 'presence/$userId',
            query: 'presence/$userId',
            userId: userId,
            itemCount: (_) => 1,
            stream: _gateway
                .watchPresence(userId)
                .map((doc) => _parsePresence(userId, doc.data())),
          ).listen(
            (presence) {
              final resolved = _arbitratePresence(
                userId,
                presence,
                previous: lastPresence,
              );
              lastPresence = resolved;
              controller.add(resolved);
            },
            onError: (error, stackTrace) {
              if (_isPermissionDenied(error)) {
                developer.log(
                  'presence_watch_permission_denied userId=$userId path=presence/$userId',
                  name: 'PresenceRepository',
                  error: error,
                  stackTrace: stackTrace,
                );
                controller.add(_parsePresence(userId, null));
                return;
              }
              controller.addError(error, stackTrace);
            },
          );

      controller.onCancel = () => subscription.cancel();
    });
  }

  @override
  Stream<bool> userPresenceStream(String userId) =>
      watchUserPresence(userId).map((presence) => presence.isOnline == true);

  @override
  Stream<Map<String, PresenceModel>> watchUsersPresence(List<String> userIds) {
    final normalizedIds = userIds.toSet().toList(growable: false);
    if (normalizedIds.isEmpty) {
      return Stream.value(const <String, PresenceModel>{});
    }

    return Stream.multi((controller) {
      final subscriptions = <StreamSubscription>[];
      var usingDocumentFallback = false;

      final lastEmitted = <String, PresenceModel>{};

      void emitFrom(Map<String, PresenceModel> source) {
        final resolved = <String, PresenceModel>{
          for (final userId in normalizedIds)
            userId: _arbitratePresence(
              userId,
              source[userId] ?? _parsePresence(userId, null),
              previous: lastEmitted[userId],
            ),
        };
        lastEmitted
          ..clear()
          ..addAll(resolved);
        controller.add(resolved);
      }

      Future<void> switchToDocumentFallback() async {
        if (usingDocumentFallback) {
          return;
        }
        usingDocumentFallback = true;

        for (final sub in subscriptions) {
          await sub.cancel();
        }
        subscriptions.clear();

        final presenceById = <String, PresenceModel>{};
        void emit() => emitFrom(presenceById);

        for (final userId in normalizedIds) {
          final streamKey = _streamLifecycleManager.buildDedupeKey(
            domain: 'presence-user-doc',
            userId: userId,
            queryHash: 'doc',
          );
          final sub = _streamLifecycleManager
              .bind<DocumentSnapshot<Map<String, dynamic>>>(
                key: streamKey,
                routePrefixes: const <String>['*'],
                create: () => _gateway.watchPresence(userId),
              )
              .listen(
                (doc) {
                  presenceById[userId] = _parsePresence(userId, doc.data());
                  emit();
                },
                onError: (error, stackTrace) {
                  if (_isPermissionDenied(error)) {
                    presenceById[userId] = _parsePresence(userId, null);
                    emit();
                    return;
                  }
                  controller.addError(error, stackTrace);
                },
              );
          subscriptions.add(sub);
        }

        emit();
      }

      final chunks = _chunksOf(normalizedIds, _firestoreWhereInLimit);
      final chunkMaps = List<Map<String, PresenceModel>>.generate(
        chunks.length,
        (_) => <String, PresenceModel>{},
      );

      void emit() {
        if (usingDocumentFallback) {
          return;
        }
        final merged = <String, PresenceModel>{};
        for (final chunkMap in chunkMaps) {
          merged.addAll(chunkMap);
        }
        emitFrom(merged);
      }

      for (var index = 0; index < chunks.length; index += 1) {
        final chunk = chunks[index];
        final queryHash = chunk
            .join('|')
            .hashCode
            .toUnsigned(32)
            .toRadixString(16);
        final streamKey = _streamLifecycleManager.buildDedupeKey(
          domain: 'presence-batch',
          userId: normalizedIds.join(','),
          queryHash: queryHash,
        );
        final sub = _streamLifecycleManager
            .bind<QuerySnapshot<Map<String, dynamic>>>(
              key: streamKey,
              routePrefixes: const <String>['*'],
              create: () => _gateway.watchPresenceBatch(chunk),
            )
            .listen(
              (snapshot) {
                chunkMaps[index] = {
                  for (final doc in snapshot.docs)
                    doc.id: _parsePresence(doc.id, doc.data()),
                };
                emit();
              },
              onError: (error, stackTrace) {
                if (_isPermissionDenied(error)) {
                  unawaited(switchToDocumentFallback());
                  return;
                }
                controller.addError(error, stackTrace);
              },
            );
        subscriptions.add(sub);
      }

      controller.onCancel = () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
      };
    });
  }

  @override
  Future<Map<String, PresenceModel>> getUsersPresence(
    List<String> userIds,
  ) async {
    final normalizedIds = userIds.toSet().toList(growable: false);
    if (normalizedIds.isEmpty) {
      return const <String, PresenceModel>{};
    }

    final result = <String, PresenceModel>{};
    final chunks = _chunksOf(normalizedIds, _firestoreWhereInLimit);

    try {
      for (final chunk in chunks) {
        final snapshot = await _gateway.getPresenceBatch(chunk);
        for (final doc in snapshot.docs) {
          result[doc.id] = _parsePresence(doc.id, doc.data());
        }
      }
    } catch (error) {
      if (!_isPermissionDenied(error)) {
        rethrow;
      }

      for (final userId in normalizedIds) {
        final doc = await _gateway.getPresence(userId);
        result[userId] = _parsePresence(userId, doc.data());
      }
    }

    return {
      for (final userId in normalizedIds)
        userId: result[userId] ?? _parsePresence(userId, null),
    };
  }

  @override
  Future<int> countOnlineUsers({int limit = 500}) async {
    try {
      final snapshot = await _gateway.countOnlinePresence(limit: limit);

      return snapshot.docs
          .where((doc) => _parsePresence(doc.id, doc.data()).isOnline == true)
          .length;
    } catch (error, stackTrace) {
      if (!_isPermissionDenied(error)) {
        rethrow;
      }
      developer.log(
        'count_online_users_permission_denied path=presence query=isOnline==true limit=$limit',
        name: 'PresenceRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }
}



