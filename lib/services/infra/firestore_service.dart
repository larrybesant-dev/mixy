import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/user.dart';
import '../../shared/models/room.dart';
import '../../shared/models/message.dart';
import '../../shared/models/notification.dart' as notif;
import '../../shared/models/tip.dart';
import '../../shared/models/media_item.dart';
import '../../shared/models/privacy_settings.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Users
  Future<void> createUser(User user) async {
    await _firestore.collection('users').doc(user.id).set(user.toMap());
  }

  Stream<User?> getUserStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        return User.fromMap(doc.data()!);
      }
      return null;
    });
  }

  Future<User?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return User.fromMap(doc.data()!);
    }
    return null;
  }

  Future<void> updateUser(User user) async {
    await _firestore.collection('users').doc(user.id).update(user.toMap());
  }

  Stream<List<User>> getUsersStream() {
    return _firestore.collection('users').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => User.fromMap(doc.data())).toList());
  }

  Future<bool> isUsernameTaken(String username) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.trim().toLowerCase())
        .limit(1)
        .get();

    return querySnapshot.docs.isNotEmpty;
  }

  // Rooms
  Stream<List<Room>> getRoomsStream() {
    return _firestore.collection('rooms').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Room.fromDocument(doc)).toList());
  }

  Future<void> createRoom(Room room) async {
    await _firestore.collection('rooms').add(room.toMap());
  }

  Stream<Room?> getRoomStream(String roomId) {
    return _firestore.collection('rooms').doc(roomId).snapshots().map((doc) {
      if (doc.exists) {
        return Room.fromDocument(doc);
      }
      return null;
    });
  }

  Future<void> joinRoom(String roomId, String userId) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'participantIds': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'participantIds': FieldValue.arrayRemove([userId]),
    });
  }

  Stream<List<Room>> getUserRoomsStream(String userId) {
    return _firestore
        .collection('rooms')
        .where('hostId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Room.fromDocument(doc)).toList());
  }

  Stream<List<Map<String, dynamic>>> getUserActivityStream(String userId) {
    // For now, return the user's recentActivity from their profile
    // In a real app, this would be a separate collection of posts/activities
    return getUserStream(userId).map((user) {
      if (user != null) {
        return user.recentActivity;
      }
      return [];
    });
  }

  // Messages
  Stream<List<Message>> getMessagesStream(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromMap(doc.data())).toList());
  }

  Future<void> sendMessage(String roomId, Message message) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .add(message.toMap());
  }

  // Notifications
  Stream<List<notif.Notification>> getNotificationsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => notif.Notification.fromMap(doc.data()))
            .toList());
  }

  Future<void> createNotification(notif.Notification notification) async {
    await _firestore
        .collection('users')
        .doc(notification.userId)
        .collection('notifications')
        .add(notification.toMap());
  }

  // Tips
  Future<void> sendTip(Tip tip) async {
    await _firestore.collection('tips').add(tip.toMap());
  }

  Stream<List<Tip>> getUserTipsStream(String userId) {
    return _firestore
        .collection('tips')
        .where('receiverId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Tip.fromMap(doc.data())).toList());
  }

  // Media
  Future<void> uploadMedia(MediaItem media) async {
    await _firestore.collection('media').add(media.toMap());
  }

  Stream<List<MediaItem>> getUserMediaStream(String userId) {
    return _firestore
        .collection('media')
        .where('userId', isEqualTo: userId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MediaItem.fromMap(doc.data())).toList());
  }

  // Privacy Settings
  Future<void> createPrivacySettings(PrivacySettings settings) async {
    await _firestore
        .collection('users')
        .doc(settings.userId)
        .collection('settings')
        .doc('privacy')
        .set(settings.toMap());
  }

  Stream<PrivacySettings?> getPrivacySettingsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('privacy')
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return PrivacySettings.fromMap(userId, doc.data()!);
      }
      return null;
    });
  }

  Future<void> updatePrivacySettings(PrivacySettings settings) async {
    await _firestore
        .collection('users')
        .doc(settings.userId)
        .collection('settings')
        .doc('privacy')
        .update(settings.toMap());
  }

  // Speed Dating (stub methods for future implementation)
  Future<dynamic> createSpeedDatingSession(String userId) async {
    final sessionId = _firestore.collection('speedDatingSessions').doc().id;
    await _firestore.collection('speedDatingSessions').doc(sessionId).set({
      'hostId': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    return {'id': sessionId, 'hostId': userId, 'status': 'pending'};
  }

  Future<dynamic> findSpeedDatingPartner(String userId) async {
    // Stub implementation
    return null;
  }

  Future<dynamic> startSpeedDatingSession(String sessionId) async {
    // Stub implementation
    return {};
  }

  Future<dynamic> getActiveSpeedDatingSession(String userId) async {
    // Stub implementation
    return null;
  }

  Stream<dynamic> getSpeedDatingSessionStream(String sessionId) {
    // Stub implementation
    return const Stream.empty();
  }

  Future<void> updateSpeedDatingDecision(
      String sessionId, String userId, dynamic decision) async {
    // Stub implementation
  }

  Future<void> cancelSpeedDatingSession(String sessionId) async {
    // Stub implementation
  }

  // DISABLED FOR V1: SpeedDatingMatch type not available
  /*
  Stream<List<SpeedDatingMatch>> getSpeedDatingMatchesStream(String userId) {
    return _firestore
        .collection('speedDatingMatches')
        .where('isActive', isEqualTo: true)
        .where('userId1', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => SpeedDatingMatch.fromMap(doc.data())).toList());
  }
  */

  // Admin methods
  Future<List<User>> getAllUsers() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs.map((doc) => User.fromMap(doc.data())).toList();
  }

  Future<List<Message>> getFlaggedMessages() async {
    final snapshot = await _firestore
        .collection('messages')
        .where('isFlagged', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) => Message.fromMap(doc.data())).toList();
  }

  Future<List<Map<String, dynamic>>> getUserReports() async {
    final snapshot = await _firestore.collection('reports').get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> updateUserFields(
      String userId, Map<String, dynamic> fields) async {
    await _firestore.collection('users').doc(userId).update(fields);
  }

  // TEMP STUBS: Notification methods (not yet implemented)
  Future<void> sendFriendOnlineNotification(
    String recipientUserId,
    String friendUserId,
    String friendName,
  ) async {
    // TODO: Implement friend online notification
  }

  Future<void> sendFriendOfflineNotification(
    String recipientUserId,
    String friendUserId,
    String friendName,
  ) async {
    // TODO: Implement friend offline notification
  }

  Future<void> sendRoomInvitation(
    String invitedByUserId,
    String invitedByName,
    String recipientUserId,
    String roomId,
    String roomName,
  ) async {
    // TODO: Implement room invitation notification
  }
}
