import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/streams/stream_lifecycle_manager.dart';
import '../features/friends/models/friend_roster_entry.dart';
import '../features/friends/models/friendship_model.dart';
import '../models/friend_request_model.dart';
import '../models/presence_model.dart';
import '../models/user_model.dart';
import 'analytics_service.dart';
import 'moderation_service.dart';
import 'presence_repository.dart';
import 'schema_mutation_service.dart';

class FriendService {
  FriendService({
    FirebaseFirestore? firestore,
    AnalyticsService? analyticsService,
    ModerationService? moderationService,
    PresenceRepository? presenceRepository,
    SchemaMutationService? mutationService,
    required StreamLifecycleManager streamLifecycleManager,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _analyticsService = analyticsService ?? AnalyticsService(),
        _moderationService = moderationService ??
            ModerationService(
              firestore: firestore ?? FirebaseFirestore.instance,
            ),
        _presenceRepository = presenceRepository ??
            FirestorePresenceRepository(
              firestore ?? FirebaseFirestore.instance,
              streamLifecycleManager: streamLifecycleManager,
            ),
        _mutationService =
            mutationService ?? SchemaMutationService(firestore: firestore),
        _streamLifecycleManager = streamLifecycleManager;

  static const int _firestoreWhereInLimit = 30;

  final FirebaseFirestore _firestore;
  final AnalyticsService _analyticsService;
  final ModerationService _moderationService;
  final PresenceRepository _presenceRepository;
  final SchemaMutationService _mutationService;
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

  CollectionReference<Map<String, dynamic>> get _friendshipsCollection =>
      _firestore.collection('friendships');

  CollectionReference<Map<String, dynamic>> get _friendLinksCollection =>
      _firestore.collection('friend_links');

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  List<String> _asStringList(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((entry) => entry is String ? entry.trim() : '')
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  void _logReadFallback({
    required String action,
    required String details,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      '$action $details',
      name: 'FriendService',
      error: error,
      stackTrace: stackTrace,
    );
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

  DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  FriendshipModel _friendshipFromSchemaDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    final users = _asStringList(data['users'])..sort();
    final userA = users.isNotEmpty ? users.first : '';
    final userB = users.length > 1 ? users[1] : '';
    return FriendshipModel(
      id: id,
      userA: userA,
      userB: userB,
      status: (data['status'] as String?)?.trim().toLowerCase() ?? 'pending',
      requestedBy: (data['requestedBy'] as String?)?.trim(),
      createdAt: _asDateTime(data['createdAt']) ??
          _asDateTime(data['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _asDateTime(data['updatedAt']),
    );
  }

  String friendshipIdFor(String firstUserId, String secondUserId) {
    return FriendshipModel.canonicalIdFor(firstUserId, secondUserId);
  }

  Stream<List<FriendshipModel>> watchFriendships(
    String userId, {
    Set<String> statuses = const <String>{},
  }) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream.value(const <FriendshipModel>[]);
    }

    final normalizedStatuses = statuses
        .map((status) => status.trim().toLowerCase())
        .where((status) => status.isNotEmpty)
        .toSet();

    return Stream.multi((controller) {
      List<FriendshipModel> userAFriendships = const <FriendshipModel>[];
      List<FriendshipModel> userBFriendships = const <FriendshipModel>[];
      List<FriendshipModel> schemaFriendships = const <FriendshipModel>[];
      var userAReady = false;
      var userBReady = false;
      var schemaReady = false;

      void emit() {
        if (!userAReady || !userBReady || !schemaReady) {
          return;
        }

        final merged = <String, FriendshipModel>{
          for (final friendship in userAFriendships) friendship.id: friendship,
          for (final friendship in userBFriendships) friendship.id: friendship,
          for (final friendship in schemaFriendships) friendship.id: friendship,
        };

        final friendships = merged.values.toList(growable: false)
          ..sort((left, right) {
            final createdCompare = right.createdAt.compareTo(left.createdAt);
            if (createdCompare != 0) return createdCompare;
            return left.id.compareTo(right.id);
          });
        controller.add(friendships);
      }

      Query<Map<String, dynamic>> buildLegacyQuery(String field) {
        var query = _friendshipsCollection.where(
          field,
          isEqualTo: normalizedUserId,
        );
        if (normalizedStatuses.length == 1) {
          query = query.where('status', isEqualTo: normalizedStatuses.first);
        } else if (normalizedStatuses.length > 1) {
          query = query.where(
            'status',
            whereIn: normalizedStatuses.toList(growable: false),
          );
        }
        return query;
      }

      Query<Map<String, dynamic>> buildSchemaQuery() {
        var query = _friendLinksCollection.where(
          'users',
          arrayContains: normalizedUserId,
        );
        if (normalizedStatuses.length == 1) {
          query = query.where('status', isEqualTo: normalizedStatuses.first);
        } else if (normalizedStatuses.length > 1) {
          query = query.where(
            'status',
            whereIn: normalizedStatuses.toList(growable: false),
          );
        }
        return query;
      }

      final subA = _streamLifecycleManager
          .bind<QuerySnapshot<Map<String, dynamic>>>(
        key: _streamLifecycleManager.buildDedupeKey(
          domain: 'friendships-legacy-userA',
          userId: normalizedUserId,
          queryHash: normalizedStatuses.join('|'),
        ),
        routePrefixes: const <String>['*'],
        create: () => buildLegacyQuery('userA').snapshots(),
      )
          .listen(
        (snapshot) {
          userAFriendships = snapshot.docs
              .map((doc) => FriendshipModel.fromJson(doc.id, doc.data()))
              .toList(growable: false);
          userAReady = true;
          emit();
        },
        onError: (error, stackTrace) {
          if (_isPermissionDenied(error)) {
            userAFriendships = const <FriendshipModel>[];
            userAReady = true;
            emit();
            return;
          }
          controller.addError(error, stackTrace);
        },
      );

      final subB = _streamLifecycleManager
          .bind<QuerySnapshot<Map<String, dynamic>>>(
        key: _streamLifecycleManager.buildDedupeKey(
          domain: 'friendships-legacy-userB',
          userId: normalizedUserId,
          queryHash: normalizedStatuses.join('|'),
        ),
        routePrefixes: const <String>['*'],
        create: () => buildLegacyQuery('userB').snapshots(),
      )
          .listen(
        (snapshot) {
          userBFriendships = snapshot.docs
              .map((doc) => FriendshipModel.fromJson(doc.id, doc.data()))
              .toList(growable: false);
          userBReady = true;
          emit();
        },
        onError: (error, stackTrace) {
          if (_isPermissionDenied(error)) {
            userBFriendships = const <FriendshipModel>[];
            userBReady = true;
            emit();
            return;
          }
          controller.addError(error, stackTrace);
        },
      );

      final schemaSub = _streamLifecycleManager
          .bind<QuerySnapshot<Map<String, dynamic>>>(
        key: _streamLifecycleManager.buildDedupeKey(
          domain: 'friendships-schema',
          userId: normalizedUserId,
          queryHash: normalizedStatuses.join('|'),
        ),
        routePrefixes: const <String>['*'],
        create: () => buildSchemaQuery().snapshots(),
      )
          .listen(
        (snapshot) {
          schemaFriendships = snapshot.docs
              .map((doc) => _friendshipFromSchemaDoc(doc.id, doc.data()))
              .where(
                (friendship) => friendship.involvesUser(normalizedUserId),
              )
              .toList(growable: false);
          schemaReady = true;
          emit();
        },
        onError: (error, stackTrace) {
          if (_isPermissionDenied(error)) {
            schemaFriendships = const <FriendshipModel>[];
            schemaReady = true;
            emit();
            return;
          }
          controller.addError(error, stackTrace);
        },
      );

      controller.onCancel = () async {
        await subA.cancel();
        await subB.cancel();
        await schemaSub.cancel();
      };
    });
  }

  Stream<List<FriendshipModel>> watchAcceptedFriendships(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream.value(const <FriendshipModel>[]);
    }

    return Stream.multi((controller) {
      StreamSubscription<List<FriendshipModel>>? primarySub;
      StreamSubscription<List<FriendshipModel>>? fallbackSub;
      List<FriendshipModel> primaryFriendships = const <FriendshipModel>[];
      List<FriendshipModel> fallbackFriendships = const <FriendshipModel>[];
      var primaryReady = false;
      var fallbackReady = false;

      void emit() {
        if (!primaryReady || !fallbackReady) {
          return;
        }

        final merged = <String, FriendshipModel>{
          for (final friendship in primaryFriendships)
            friendship.id: friendship,
          for (final friendship in fallbackFriendships)
            friendship.id: friendship,
        };
        final friendships = merged.values.toList(growable: false)
          ..sort((left, right) {
            final createdCompare = right.createdAt.compareTo(left.createdAt);
            if (createdCompare != 0) return createdCompare;
            return left.id.compareTo(right.id);
          });
        controller.add(friendships);
      }

      fallbackSub =
          _watchAcceptedFriendshipsFromUserDoc(normalizedUserId).listen(
        (friendships) {
          fallbackFriendships = friendships;
          fallbackReady = true;
          emit();
        },
        onError: (error, stackTrace) {
          if (_isPermissionDenied(error)) {
            fallbackFriendships = const <FriendshipModel>[];
            fallbackReady = true;
            emit();
            return;
          }
          controller.addError(error, stackTrace);
        },
      );

      primarySub = watchFriendships(
        normalizedUserId,
        statuses: const <String>{'accepted'},
      ).listen(
        (friendships) {
          primaryFriendships = friendships;
          primaryReady = true;
          emit();
        },
        onError: (error, stackTrace) {
          if (_isPermissionDenied(error)) {
            primaryFriendships = const <FriendshipModel>[];
            primaryReady = true;
            emit();
            return;
          }
          controller.addError(error, stackTrace);
        },
      );

      controller.onCancel = () async {
        await primarySub?.cancel();
        await fallbackSub?.cancel();
      };
    });
  }

  Stream<List<FriendshipModel>> _watchAcceptedFriendshipsFromUserDoc(
    String userId,
  ) {
    return _usersCollection.doc(userId).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) {
        return const <FriendshipModel>[];
      }

      final friendIds = _asStringList(data['friends']);
      final fallbackCreatedAt = DateTime.fromMillisecondsSinceEpoch(0);
      return friendIds.map((friendId) {
        final sorted = FriendshipModel.sortedPair(userId, friendId);
        return FriendshipModel(
          id: FriendshipModel.canonicalIdFor(userId, friendId),
          userA: sorted.userA,
          userB: sorted.userB,
          status: 'accepted',
          createdAt: fallbackCreatedAt,
        );
      }).toList(growable: false);
    });
  }

  Stream<List<UserModel>> watchFriends(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream.value(const <UserModel>[]);
    }

    return Stream.multi((controller) {
      StreamSubscription<List<FriendshipModel>>? friendshipsSub;
      StreamSubscription<List<UserModel>>? usersSub;

      Future<void> bindUsers(List<FriendshipModel> friendships) async {
        final excludedIds = await _moderationService.getExcludedUserIds(
          normalizedUserId,
        );
        final friendIds = friendships
            .map((friendship) => friendship.otherUserId(normalizedUserId))
            .where(
              (friendId) =>
                  friendId.isNotEmpty && !excludedIds.contains(friendId),
            )
            .toList(growable: false);

        await usersSub?.cancel();
        if (friendIds.isEmpty) {
          controller.add(const <UserModel>[]);
          return;
        }

        usersSub = watchUsersByIds(friendIds).listen((users) {
          final usersById = <String, UserModel>{
            for (final user in users) user.id: user,
          };
          final ordered = friendIds
              .map((friendId) => usersById[friendId])
              .whereType<UserModel>()
              .toList(growable: false);
          controller.add(ordered);
        }, onError: controller.addError);
      }

      friendshipsSub = watchAcceptedFriendships(normalizedUserId).listen(
        (friendships) => bindUsers(friendships),
        onError: (error, stackTrace) {
          if (_isPermissionDenied(error)) {
            controller.add(const <UserModel>[]);
            return;
          }
          controller.addError(error, stackTrace);
        },
      );

      controller.onCancel = () async {
        await friendshipsSub?.cancel();
        await usersSub?.cancel();
      };
    });
  }

  Stream<List<FriendRosterEntry>> watchFriendRoster(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream.value(const <FriendRosterEntry>[]);
    }

    return Stream.multi((controller) {
      StreamSubscription<List<FriendshipModel>>? friendshipsSub;
      StreamSubscription<List<UserModel>>? usersSub;
      StreamSubscription<Map<String, PresenceModel>>? presenceSub;

      List<FriendshipModel> latestFriendships = const <FriendshipModel>[];
      Map<String, UserModel> usersById = const <String, UserModel>{};
      Map<String, PresenceModel> presenceById = const <String, PresenceModel>{};
      var usersReady = false;
      var presenceReady = false;

      void emit() {
        if (latestFriendships.isNotEmpty && (!usersReady || !presenceReady)) {
          return;
        }
        final entries = latestFriendships
            .map((friendship) {
              final friendId = friendship.otherUserId(normalizedUserId);
              final user = usersById[friendId];
              if (friendId.isEmpty || user == null) {
                return null;
              }
              final presence = presenceById[friendId] ??
                  PresenceModel(
                    userId: friendId,
                    isOnline: false,
                    status: UserStatus.offline,
                  );
              return FriendRosterEntry(
                friendship: friendship,
                user: user,
                presence: presence,
              );
            })
            .whereType<FriendRosterEntry>()
            .toList(growable: false)
          ..sort(
            (left, right) => left.user.username.toLowerCase().compareTo(
                  right.user.username.toLowerCase(),
                ),
          );
        controller.add(entries);
      }

      void logPresenceTransitions(Map<String, PresenceModel> nextPresenceById) {
        for (final entry in nextPresenceById.entries) {
          final previous = presenceById[entry.key];
          final previousOnline = previous?.isOnline == true;
          final nextOnline = entry.value.isOnline == true;
          if (previous != null && previousOnline != nextOnline) {
            developer.log(
              'friend_presence_changed userId=${entry.key} online=$nextOnline roomId=${entry.value.inRoom ?? '-'}',
              name: 'FriendService',
            );
          }
        }
      }

      Future<void> rebindFriendData(List<FriendshipModel> friendships) async {
        final excludedIds = await _moderationService.getExcludedUserIds(
          normalizedUserId,
        );
        final filteredFriendships = friendships
            .where(
              (friendship) => !excludedIds.contains(
                friendship.otherUserId(normalizedUserId),
              ),
            )
            .toList(growable: false);
        final friendIds = filteredFriendships
            .map((friendship) => friendship.otherUserId(normalizedUserId))
            .where((friendId) => friendId.isNotEmpty)
            .toList(growable: false);

        latestFriendships = filteredFriendships;

        await usersSub?.cancel();
        await presenceSub?.cancel();
        usersReady = false;
        presenceReady = false;

        if (friendIds.isEmpty) {
          usersById = const <String, UserModel>{};
          presenceById = const <String, PresenceModel>{};
          usersReady = true;
          presenceReady = true;
          emit();
          return;
        }

        usersSub = watchUsersByIds(friendIds).listen(
          (users) {
            usersById = {for (final user in users) user.id: user};
            usersReady = true;
            emit();
          },
          onError: (error, stackTrace) {
            if (_isPermissionDenied(error)) {
              usersById = const <String, UserModel>{};
              usersReady = true;
              emit();
              return;
            }
            controller.addError(error, stackTrace);
          },
        );

        presenceSub = _watchPresenceByUserIds(friendIds).listen(
          (presenceMap) {
            logPresenceTransitions(presenceMap);
            presenceById = presenceMap;
            presenceReady = true;
            emit();
          },
          onError: (error, stackTrace) {
            if (_isPermissionDenied(error)) {
              presenceById = const <String, PresenceModel>{};
              presenceReady = true;
              emit();
              return;
            }
            controller.addError(error, stackTrace);
          },
        );
      }

      friendshipsSub = watchAcceptedFriendships(normalizedUserId).listen(
        (friendships) => rebindFriendData(friendships),
        onError: (error, stackTrace) {
          if (_isPermissionDenied(error)) {
            latestFriendships = const <FriendshipModel>[];
            usersById = const <String, UserModel>{};
            presenceById = const <String, PresenceModel>{};
            usersReady = true;
            presenceReady = true;
            emit();
            return;
          }
          controller.addError(error, stackTrace);
        },
      );

      controller.onCancel = () async {
        await friendshipsSub?.cancel();
        await usersSub?.cancel();
        await presenceSub?.cancel();
      };
    });
  }

  Stream<List<UserModel>> watchFriendsFromFriendships(
    String userId,
    Stream<List<FriendshipModel>> friendships,
  ) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream.value(const <UserModel>[]);
    }

    return Stream.multi((controller) {
      StreamSubscription<List<FriendshipModel>>? friendshipsSub;
      StreamSubscription<List<UserModel>>? usersSub;

      Future<void> bindUsers(List<FriendshipModel> latestFriendships) async {
        final excludedIds = await _moderationService.getExcludedUserIds(
          normalizedUserId,
        );
        final friendIds = latestFriendships
            .map((f) => f.otherUserId(normalizedUserId))
            .where((id) => id.isNotEmpty && !excludedIds.contains(id))
            .toList(growable: false);

        await usersSub?.cancel();
        if (friendIds.isEmpty) {
          controller.add(const <UserModel>[]);
          return;
        }

        usersSub = watchUsersByIds(friendIds).listen((users) {
          final usersById = <String, UserModel>{for (final u in users) u.id: u};
          final ordered = friendIds
              .map((id) => usersById[id])
              .whereType<UserModel>()
              .toList(growable: false);
          controller.add(ordered);
        }, onError: controller.addError);
      }

      friendshipsSub = friendships.listen(
        bindUsers,
        onError: (error, stackTrace) {
          if (_isPermissionDenied(error)) {
            controller.add(const <UserModel>[]);
            return;
          }
          controller.addError(error, stackTrace);
        },
      );

      controller.onCancel = () async {
        await friendshipsSub?.cancel();
        await usersSub?.cancel();
      };
    });
  }

  Stream<List<FriendRosterEntry>> watchFriendRosterFromFriendships(
    String userId,
    Stream<List<FriendshipModel>> friendships,
  ) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream.value(const <FriendRosterEntry>[]);
    }

    return Stream.multi((controller) {
      StreamSubscription<List<FriendshipModel>>? friendshipsSub;
      StreamSubscription<List<UserModel>>? usersSub;
      StreamSubscription<Map<String, PresenceModel>>? presenceSub;

      List<FriendshipModel> latestFriendships = const <FriendshipModel>[];
      Map<String, UserModel> usersById = const <String, UserModel>{};
      Map<String, PresenceModel> presenceById = const <String, PresenceModel>{};
      var usersReady = false;
      var presenceReady = false;

      void emit() {
        if (latestFriendships.isNotEmpty && (!usersReady || !presenceReady)) {
          return;
        }
        final entries = latestFriendships
            .map((friendship) {
              final friendId = friendship.otherUserId(normalizedUserId);
              final user = usersById[friendId];
              if (friendId.isEmpty || user == null) return null;
              final presence = presenceById[friendId] ??
                  PresenceModel(
                    userId: friendId,
                    isOnline: false,
                    status: UserStatus.offline,
                  );
              return FriendRosterEntry(
                friendship: friendship,
                user: user,
                presence: presence,
              );
            })
            .whereType<FriendRosterEntry>()
            .toList(growable: false)
          ..sort(
            (l, r) => l.user.username.toLowerCase().compareTo(
                  r.user.username.toLowerCase(),
                ),
          );
        controller.add(entries);
      }

      void logPresenceTransitions(Map<String, PresenceModel> nextPresenceById) {
        for (final entry in nextPresenceById.entries) {
          final previous = presenceById[entry.key];
          final previousOnline = previous?.isOnline == true;
          final nextOnline = entry.value.isOnline == true;
          if (previous != null && previousOnline != nextOnline) {
            developer.log(
              'friend_presence_changed userId=${entry.key} online=$nextOnline roomId=${entry.value.inRoom ?? '-'}',
              name: 'FriendService',
            );
          }
        }
      }

      Future<void> rebindFriendData(
        List<FriendshipModel> incomingFriendships,
      ) async {
        final excludedIds = await _moderationService.getExcludedUserIds(
          normalizedUserId,
        );
        final filteredFriendships = incomingFriendships
            .where(
              (f) => !excludedIds.contains(f.otherUserId(normalizedUserId)),
            )
            .toList(growable: false);
        final friendIds = filteredFriendships
            .map((f) => f.otherUserId(normalizedUserId))
            .where((id) => id.isNotEmpty)
            .toList(growable: false);

        latestFriendships = filteredFriendships;

        await usersSub?.cancel();
        await presenceSub?.cancel();
        usersReady = false;
        presenceReady = false;

        if (friendIds.isEmpty) {
          usersById = const <String, UserModel>{};
          presenceById = const <String, PresenceModel>{};
          usersReady = true;
          presenceReady = true;
          emit();
          return;
        }

        usersSub = watchUsersByIds(friendIds).listen(
          (users) {
            usersById = {for (final u in users) u.id: u};
            usersReady = true;
            emit();
          },
          onError: (error, stackTrace) {
            if (_isPermissionDenied(error)) {
              usersById = const <String, UserModel>{};
              usersReady = true;
              emit();
              return;
            }
            controller.addError(error, stackTrace);
          },
        );

        presenceSub = _watchPresenceByUserIds(friendIds).listen(
          (presenceMap) {
            logPresenceTransitions(presenceMap);
            presenceById = presenceMap;
            presenceReady = true;
            emit();
          },
          onError: (error, stackTrace) {
            if (_isPermissionDenied(error)) {
              presenceById = const <String, PresenceModel>{};
              presenceReady = true;
              emit();
              return;
            }
            controller.addError(error, stackTrace);
          },
        );
      }

      friendshipsSub = friendships.listen(
        rebindFriendData,
        onError: (error, stackTrace) {
          if (_isPermissionDenied(error)) {
            latestFriendships = const <FriendshipModel>[];
            usersById = const <String, UserModel>{};
            presenceById = const <String, PresenceModel>{};
            usersReady = true;
            presenceReady = true;
            emit();
            return;
          }
          controller.addError(error, stackTrace);
        },
      );

      controller.onCancel = () async {
        await friendshipsSub?.cancel();
        await usersSub?.cancel();
        await presenceSub?.cancel();
      };
    });
  }

  Stream<List<FriendRequestModel>> incomingRequests(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream.value(const <FriendRequestModel>[]);
    }

    return watchFriendships(
      normalizedUserId,
      statuses: const <String>{'pending'},
    ).map((friendships) {
      final requests = friendships
          .where((friendship) => friendship.requestedBy != normalizedUserId)
          .map(
            (friendship) => FriendRequestModel(
              id: friendship.id,
              fromUserId: friendship.requestedBy ?? friendship.userA,
              toUserId: normalizedUserId,
              status: friendship.status,
              createdAt: friendship.createdAt,
            ),
          )
          .toList(growable: false)
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
      return requests;
    });
  }

  Stream<List<String>> outgoingPendingRequestIds(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream.value(const <String>[]);
    }

    return watchFriendships(
      normalizedUserId,
      statuses: const <String>{'pending'},
    ).map((friendships) {
      return friendships
          .where((friendship) => friendship.requestedBy == normalizedUserId)
          .map((friendship) => friendship.otherUserId(normalizedUserId))
          .where((friendId) => friendId.isNotEmpty)
          .toList(growable: false);
    });
  }

  Future<void> sendFriendRequest(String fromUserId, String toUserId) async {
    final normalizedFromUserId = fromUserId.trim();
    final normalizedToUserId = toUserId.trim();
    if (normalizedFromUserId.isEmpty ||
        normalizedToUserId.isEmpty ||
        normalizedFromUserId == normalizedToUserId) {
      return;
    }

    if (await _moderationService.hasBlockingRelationship(
      normalizedFromUserId,
      normalizedToUserId,
    )) {
      return;
    }

    final friendshipId = friendshipIdFor(
      normalizedFromUserId,
      normalizedToUserId,
    );
    final friendshipRef = _friendshipsCollection.doc(friendshipId);
    final sortedPair = FriendshipModel.sortedPair(
      normalizedFromUserId,
      normalizedToUserId,
    );

    FriendshipModel? friendship;
    try {
      final friendshipSnap = await friendshipRef.get();
      if (friendshipSnap.exists) {
        friendship = FriendshipModel.fromJson(
          friendshipSnap.id,
          friendshipSnap.data() ?? <String, dynamic>{},
        );
      }
    } catch (error, stackTrace) {
      if (!_isPermissionDenied(error)) {
        rethrow;
      }
      developer.log(
        'friendship_lookup_denied from=$normalizedFromUserId to=$normalizedToUserId proceeding_with_create=true',
        name: 'FriendService',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (friendship != null) {
      if (friendship.status == 'accepted' || friendship.status == 'blocked') {
        return;
      }

      if (friendship.status == 'pending') {
        if (friendship.requestedBy == normalizedFromUserId) {
          return;
        }
        await acceptFriendRequest(friendship.id);
        return;
      }
    }

    await _mutationService.syncFriendLinks(
      firstUserId: sortedPair.userA,
      secondUserId: sortedPair.userB,
      status: 'pending',
      requestedBy: normalizedFromUserId,
      collectionName: 'friendships',
    );

    try {
      final fromUser = await getUserById(normalizedFromUserId);
      await _createNotification(
        normalizedToUserId,
        type: 'friend_request',
        content:
            '${fromUser?.username ?? 'Someone'} sent you a friend request.',
        actorId: normalizedFromUserId,
      );
    } catch (error, stackTrace) {
      developer.log(
        'friend_request_notification_failed from=$normalizedFromUserId to=$normalizedToUserId friendshipId=$friendshipId',
        name: 'FriendService',
        error: error,
        stackTrace: stackTrace,
      );
    }

    developer.log(
      'friend_request_sent from=$normalizedFromUserId to=$normalizedToUserId friendshipId=$friendshipId',
      name: 'FriendService',
    );

    try {
      await _analyticsService.logEvent(
        'friend_request_sent',
        params: {
          'from_user_id': normalizedFromUserId,
          'to_user_id': normalizedToUserId,
          'friendship_id': friendshipId,
        },
      );
    } catch (_) {
      // Keep the friendship flow resilient when analytics is unavailable.
    }
  }

  Future<void> acceptFriendRequest(String requestId) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) return;

    final friendshipRef = _friendshipsCollection.doc(normalizedRequestId);
    final friendshipSnap = await friendshipRef.get();
    if (!friendshipSnap.exists) return;

    final friendship = FriendshipModel.fromJson(
      friendshipSnap.id,
      friendshipSnap.data() ?? <String, dynamic>{},
    );
    if (friendship.status != 'pending') {
      return;
    }

    await _mutationService.syncFriendLinks(
      firstUserId: friendship.userA,
      secondUserId: friendship.userB,
      status: 'accepted',
      requestedBy: friendship.requestedBy ?? friendship.userA,
      collectionName: 'friendships',
    );

    final accepterId = friendship.requestedBy == friendship.userA
        ? friendship.userB
        : friendship.userA;
    final accepter = await getUserById(accepterId);
    final requesterId = friendship.requestedBy ?? friendship.userA;

    await _createNotification(
      requesterId,
      type: 'friend_accept',
      content:
          '${accepter?.username ?? 'Someone'} accepted your friend request.',
      actorId: accepterId,
    );

    developer.log(
      'friend_request_accepted friendshipId=$normalizedRequestId requester=$requesterId accepter=$accepterId',
      name: 'FriendService',
    );

    try {
      await _analyticsService.logEvent(
        'friend_request_accepted',
        params: {
          'friendship_id': normalizedRequestId,
          'requester_id': requesterId,
          'accepter_id': accepterId,
        },
      );
    } catch (_) {
      // Keep the friendship flow resilient when analytics is unavailable.
    }
  }

  Future<void> declineFriendRequest(String requestId) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) return;

    final friendshipRef = _friendshipsCollection.doc(normalizedRequestId);
    final friendshipSnap = await friendshipRef.get();
    if (!friendshipSnap.exists) {
      return;
    }

    final friendship = FriendshipModel.fromJson(
      friendshipSnap.id,
      friendshipSnap.data() ?? <String, dynamic>{},
    );
    if (friendship.status != 'pending') {
      return;
    }

    await Future.wait<void>([
      friendshipRef.delete(),
      _firestore.collection('friend_links').doc(normalizedRequestId).delete(),
    ]);
  }

  Future<List<UserModel>> getFriends(String userId) async {
    final friendIds = await getFriendIds(userId);
    if (friendIds.isEmpty) return const <UserModel>[];

    final excludedIds = await _moderationService.getExcludedUserIds(userId);
    final visibleFriendIds = friendIds
        .where((id) => !excludedIds.contains(id))
        .toList(growable: false);
    if (visibleFriendIds.isEmpty) {
      return const <UserModel>[];
    }

    final favoriteIds = await getFavoriteFriendIds(userId);
    final friends = await getUsersByIds(visibleFriendIds);

    friends.sort((a, b) {
      final aFav = favoriteIds.contains(a.id) ? 0 : 1;
      final bFav = favoriteIds.contains(b.id) ? 0 : 1;
      if (aFav != bFav) return aFav.compareTo(bFav);
      return a.username.toLowerCase().compareTo(b.username.toLowerCase());
    });
    return friends;
  }

  Future<UserModel?> getUserById(String userId) async {
    final snapshot = await _usersCollection.doc(userId).get();
    if (!snapshot.exists) {
      return null;
    }

    return UserModel.fromJson(
        {'id': snapshot.id, if (snapshot.data() != null) ...snapshot.data()!});
  }

  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) {
      return const <UserModel>[];
    }

    final uniqueIds = userIds.toSet().toList(growable: false);
    final usersById = <String, UserModel>{};
    for (final chunk in _chunksOf(uniqueIds, _firestoreWhereInLimit)) {
      try {
        final query = await _usersCollection
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in query.docs) {
          usersById[doc.id] = UserModel.fromJson({'id': doc.id, ...doc.data()});
        }
      } catch (error, stackTrace) {
        if (!_isPermissionDenied(error)) {
          rethrow;
        }
        _logReadFallback(
          action: 'users_query_permission_denied',
          details: 'path=users ids=${chunk.join(',')}',
          error: error,
          stackTrace: stackTrace,
        );
        for (final userId in chunk) {
          try {
            final doc = await _usersCollection.doc(userId).get();
            if (doc.exists) {
              usersById[doc.id] = UserModel.fromJson({
                'id': doc.id,
                if (doc.data() != null) ...doc.data()!,
              });
            }
          } catch (docError, docStackTrace) {
            if (_isPermissionDenied(docError)) {
              _logReadFallback(
                action: 'user_doc_permission_denied',
                details: 'path=users/$userId',
                error: docError,
                stackTrace: docStackTrace,
              );
              continue;
            }
            rethrow;
          }
        }
      }
    }

    return uniqueIds
        .map((userId) => usersById[userId])
        .whereType<UserModel>()
        .toList(growable: false);
  }

  Future<List<String>> getFriendIds(String userId) async {
    final friendships = await _getFriendships(
      userId,
      statuses: const <String>{'accepted'},
    );
    return friendships
        .map((friendship) => friendship.otherUserId(userId))
        .where((friendId) => friendId.isNotEmpty)
        .toList(growable: false);
  }

  Future<Set<String>> getFavoriteFriendIds(String userId) async {
    final userDoc = await _usersCollection.doc(userId).get();
    if (!userDoc.exists) return const <String>{};
    final data = userDoc.data() ?? <String, dynamic>{};
    return _asStringList(data['favoriteFriendIds']).toSet();
  }

  Future<void> setFavorite(
    String userId,
    String friendId, {
    required bool isFavorite,
  }) async {
    if (userId.trim().isEmpty || friendId.trim().isEmpty) return;
    await _mutationService.setLegacyFavoriteFriend(
      userId: userId,
      friendId: friendId,
      isFavorite: isFavorite,
    );
    if (isFavorite) {
      await _createNotification(
        friendId,
        type: 'friend_favorite',
        content: 'Someone added you as a favorite friend.',
        actorId: userId,
      );
    }
  }

  Future<List<String>> getIncomingRequesterIds(String userId) async {
    final friendships = await _getFriendships(
      userId,
      statuses: const <String>{'pending'},
    );
    return friendships
        .where((friendship) => friendship.requestedBy != userId.trim())
        .map((friendship) => friendship.requestedBy ?? '')
        .where((requesterId) => requesterId.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> getOutgoingPendingRequestIds(String userId) async {
    final normalizedUserId = userId.trim();
    final friendships = await _getFriendships(
      normalizedUserId,
      statuses: const <String>{'pending'},
    );
    return friendships
        .where((friendship) => friendship.requestedBy == normalizedUserId)
        .map((friendship) => friendship.otherUserId(normalizedUserId))
        .where((friendId) => friendId.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> removeFriend(String userId, String friendId) async {
    final friendshipId = friendshipIdFor(userId, friendId);
    await Future.wait<void>([
      _friendshipsCollection.doc(friendshipId).delete(),
      _firestore.collection('friend_links').doc(friendshipId).delete(),
    ]);
  }

  Future<List<UserModel>> searchUsers(
    String query, {
    String? currentUserId,
    List<String> excludeUserIds = const <String>[],
  }) async {
    final normalizedQuery = query.trim().toLowerCase();
    final blockedIds = currentUserId == null
        ? const <String>{}
        : await _moderationService.getExcludedUserIds(currentUserId);

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      if (normalizedQuery.isEmpty) {
        snapshot = await _usersCollection
            .where('isPrivate', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();
      } else {
        snapshot = await _usersCollection
            .where('isPrivate', isEqualTo: false)
            .where('usernameLower', isGreaterThanOrEqualTo: normalizedQuery)
            .where('usernameLower', isLessThan: '$normalizedQuery\uf8ff')
            .limit(20)
            .get();
      }
    } catch (error, stackTrace) {
      if (!_isPermissionDenied(error)) {
        rethrow;
      }
      _logReadFallback(
        action: 'search_users_permission_denied',
        details: 'path=users query=$normalizedQuery',
        error: error,
        stackTrace: stackTrace,
      );
      return const <UserModel>[];
    }

    if (snapshot.docs.isEmpty) {
      try {
        if (normalizedQuery.isEmpty) {
          snapshot = await _usersCollection
              .orderBy('createdAt', descending: true)
              .limit(50)
              .get();
        } else {
          snapshot = await _usersCollection
              .where('usernameLower', isGreaterThanOrEqualTo: normalizedQuery)
              .where('usernameLower', isLessThan: '$normalizedQuery\uf8ff')
              .limit(20)
              .get();
        }
      } catch (_) {
        // Keep the safer public-only query result when the legacy fallback is denied.
      }
    }

    return snapshot.docs
        .where((doc) => (doc.data()['isPrivate'] as bool?) != true)
        .map((doc) => UserModel.fromJson({'id': doc.id, ...doc.data()}))
        .where((user) => user.id.isNotEmpty)
        .where((user) => user.id != currentUserId)
        .where((user) => !excludeUserIds.contains(user.id))
        .where((user) => !blockedIds.contains(user.id))
        .where((user) {
      if (normalizedQuery.isEmpty) return true;
      return user.username.toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);
  }

  Future<List<UserModel>> getFriendSuggestions(
    String userId, {
    int limit = 20,
  }) async {
    if (userId.trim().isEmpty) return const <UserModel>[];

    final myFriendIds = (await getFriendIds(userId)).toSet();
    if (myFriendIds.isEmpty) return const <UserModel>[];

    final excludedIds = await _moderationService.getExcludedUserIds(userId);
    final excluded = {...excludedIds, userId, ...myFriendIds};

    final mutualCount = <String, int>{};
    for (final friendId in myFriendIds) {
      final theirFriendIds = await getFriendIds(friendId);
      for (final candidate in theirFriendIds) {
        if (excluded.contains(candidate)) continue;
        mutualCount[candidate] = (mutualCount[candidate] ?? 0) + 1;
      }
    }
    if (mutualCount.isEmpty) return const <UserModel>[];

    final sorted = mutualCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topIds =
        sorted.take(limit).map((entry) => entry.key).toList(growable: false);
    if (topIds.isEmpty) return const <UserModel>[];

    return getUsersByIds(topIds);
  }

  Stream<List<UserModel>> watchUsersByIds(List<String> userIds) {
    final normalizedIds = userIds.toSet().toList(growable: false);
    if (normalizedIds.isEmpty) {
      return Stream.value(const <UserModel>[]);
    }

    return Stream.multi((controller) {
      final chunks = _chunksOf(normalizedIds, _firestoreWhereInLimit);
      final chunkMaps = List<Map<String, UserModel>>.generate(
        chunks.length,
        (_) => <String, UserModel>{},
      );
      final subscriptions = <StreamSubscription<dynamic>>[];
      var usingDocumentFallback = false;

      void emitMerged(Map<String, UserModel> merged) {
        controller.add(
          normalizedIds
              .map((userId) => merged[userId])
              .whereType<UserModel>()
              .toList(growable: false),
        );
      }

      void emit() {
        final merged = <String, UserModel>{};
        for (final chunkMap in chunkMaps) {
          merged.addAll(chunkMap);
        }
        emitMerged(merged);
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

        final usersById = <String, UserModel>{};

        void emitFallback() => emitMerged(usersById);

        for (final userId in normalizedIds) {
          final sub = _usersCollection.doc(userId).snapshots().listen(
            (doc) {
              final data = doc.data();
              if (!doc.exists || data == null) {
                usersById.remove(userId);
              } else {
                usersById[userId] = UserModel.fromJson({
                  'id': doc.id,
                  ...data,
                });
              }
              emitFallback();
            },
            onError: (error, stackTrace) {
              if (_isPermissionDenied(error)) {
                usersById.remove(userId);
                _logReadFallback(
                  action: 'user_stream_permission_denied',
                  details: 'path=users/$userId',
                  error: error,
                  stackTrace: stackTrace,
                );
                emitFallback();
                return;
              }
              controller.addError(error, stackTrace);
            },
          );
          subscriptions.add(sub);
        }

        emitFallback();
      }

      for (var index = 0; index < chunks.length; index += 1) {
        final chunk = chunks[index];
        final sub = _usersCollection
            .where(FieldPath.documentId, whereIn: chunk)
            .snapshots()
            .listen(
          (snapshot) {
            if (usingDocumentFallback) {
              return;
            }
            chunkMaps[index] = {
              for (final doc in snapshot.docs)
                doc.id: UserModel.fromJson({'id': doc.id, ...doc.data()}),
            };
            emit();
          },
          onError: (error, stackTrace) {
            if (_isPermissionDenied(error)) {
              _logReadFallback(
                action: 'users_stream_query_permission_denied',
                details: 'path=users ids=${chunk.join(',')}',
                error: error,
                stackTrace: stackTrace,
              );
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

  Stream<Map<String, PresenceModel>> _watchPresenceByUserIds(
    List<String> userIds,
  ) {
    return _presenceRepository.watchUsersPresence(userIds);
  }

  Future<List<FriendshipModel>> _getFriendships(
    String userId, {
    Set<String> statuses = const <String>{},
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return const <FriendshipModel>[];
    }

    final normalizedStatuses = statuses
        .map((status) => status.trim().toLowerCase())
        .where((status) => status.isNotEmpty)
        .toSet();

    Query<Map<String, dynamic>> buildLegacyQuery(String field) {
      var query = _friendshipsCollection.where(
        field,
        isEqualTo: normalizedUserId,
      );
      if (normalizedStatuses.length == 1) {
        query = query.where('status', isEqualTo: normalizedStatuses.first);
      } else if (normalizedStatuses.length > 1) {
        query = query.where(
          'status',
          whereIn: normalizedStatuses.toList(growable: false),
        );
      }
      return query;
    }

    Query<Map<String, dynamic>> buildSchemaQuery() {
      var query = _friendLinksCollection.where(
        'users',
        arrayContains: normalizedUserId,
      );
      if (normalizedStatuses.length == 1) {
        query = query.where('status', isEqualTo: normalizedStatuses.first);
      } else if (normalizedStatuses.length > 1) {
        query = query.where(
          'status',
          whereIn: normalizedStatuses.toList(growable: false),
        );
      }
      return query;
    }

    final merged = <String, FriendshipModel>{};

    Future<void> collectLegacy(Query<Map<String, dynamic>> query) async {
      try {
        final snapshot = await query.get();
        for (final doc in snapshot.docs) {
          merged[doc.id] = FriendshipModel.fromJson(doc.id, doc.data());
        }
      } catch (error) {
        if (!_isPermissionDenied(error)) {
          rethrow;
        }
      }
    }

    Future<void> collectSchema() async {
      try {
        final snapshot = await buildSchemaQuery().get();
        for (final doc in snapshot.docs) {
          final friendship = _friendshipFromSchemaDoc(doc.id, doc.data());
          if (friendship.involvesUser(normalizedUserId)) {
            merged[doc.id] = friendship;
          }
        }
      } catch (error) {
        if (!_isPermissionDenied(error)) {
          rethrow;
        }
      }
    }

    await Future.wait<void>([
      collectLegacy(buildLegacyQuery('userA')),
      collectLegacy(buildLegacyQuery('userB')),
      collectSchema(),
    ]);

    if (normalizedStatuses.length == 1 &&
        normalizedStatuses.contains('accepted')) {
      try {
        final userDoc = await _usersCollection.doc(normalizedUserId).get();
        final data = userDoc.data() ?? const <String, dynamic>{};
        final friendIds = _asStringList(data['friends']);
        for (final friendId in friendIds) {
          final sorted = FriendshipModel.sortedPair(normalizedUserId, friendId);
          final id = FriendshipModel.canonicalIdFor(normalizedUserId, friendId);
          merged.putIfAbsent(
            id,
            () => FriendshipModel(
              id: id,
              userA: sorted.userA,
              userB: sorted.userB,
              status: 'accepted',
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          );
        }
      } catch (error) {
        if (!_isPermissionDenied(error)) {
          rethrow;
        }
      }
    }

    final friendships = merged.values.toList(growable: false)
      ..sort((left, right) {
        final createdCompare = right.createdAt.compareTo(left.createdAt);
        if (createdCompare != 0) return createdCompare;
        return left.id.compareTo(right.id);
      });
    return friendships;
  }

  Future<void> _createNotification(
    String userId, {
    required String type,
    required String content,
    required String actorId,
  }) async {
    await _firestore.collection('notifications').add({
      'userId': userId,
      'actorId': actorId,
      'type': type,
      'content': content,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
