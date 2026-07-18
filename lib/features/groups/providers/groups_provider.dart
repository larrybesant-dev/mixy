import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/services/groups_gateway.dart';
import '../models/group_model.dart';

// Get all groups
final groupsProvider = StreamProvider<List<Group>>((ref) {
  final gateway = ref.watch(groupsGatewayProvider);
  return gateway
      .groupsStream()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => Group.fromJson(doc.data(), doc.id))
            .toList(),
      );
});

// Get single group details
final groupDetailsProvider = StreamProvider.autoDispose.family<Group?, String>((
  ref,
  groupId,
) {
  final gateway = ref.watch(groupsGatewayProvider);
  return gateway
      .groupDetailsStream(groupId)
      .map((snapshot) {
        if (!snapshot.exists) return null;
        final data = snapshot.data();
        if (data == null) return null;
        return Group.fromJson(data, snapshot.id);
      });
});

// Get user's groups
final userGroupsProvider = StreamProvider.autoDispose
    .family<List<Group>, String>((ref, userId) {
      final gateway = ref.watch(groupsGatewayProvider);
      return gateway
          .userGroupsStream(userId)
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => Group.fromJson(doc.data(), doc.id))
                .toList(),
          );
    });

// Get posts in a group
final groupPostsProvider = StreamProvider.autoDispose
    .family<List<GroupPost>, String>((ref, groupId) {
      final gateway = ref.watch(groupsGatewayProvider);
      return gateway
          .groupPostsStream(groupId)
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => GroupPost.fromJson(doc.data(), doc.id))
                .toList(),
          );
    });

// Groups controller
class GroupsController {
  final GroupsGateway _gateway;

  GroupsController({required GroupsGateway gateway}) : _gateway = gateway;

  Future<void> createGroup({
    required String userId,
    required String name,
    required String description,
  }) async {
    await _gateway.createGroup(
      userId: userId,
      name: name,
      description: description,
    );
  }

  Future<void> joinGroup({
    required String groupId,
    required String userId,
  }) async {
    await _gateway.joinGroup(groupId: groupId, userId: userId);
  }

  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    await _gateway.leaveGroup(groupId: groupId, userId: userId);
  }

  Future<void> postToGroup({
    required String groupId,
    required String userId,
    required String username,
    required String? avatarUrl,
    required String content,
    required List<String> tags,
  }) async {
    await _gateway.postToGroup(
      groupId: groupId,
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
      content: content,
      tags: tags,
    );
  }

  Future<void> deleteGroup({required String groupId}) async {
    await _gateway.deleteGroup(groupId: groupId);
  }
}

final groupsControllerProvider = Provider<GroupsController>((ref) {
  return GroupsController(gateway: ref.watch(groupsGatewayProvider));
});




