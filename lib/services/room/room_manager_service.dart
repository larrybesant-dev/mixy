import 'package:cloud_firestore/cloud_firestore.dart';

class RoomManagerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> muteUser(String roomId, String uid) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(uid)
        .update({'muted': true});
  }

  Future<void> unmuteUser(String roomId, String uid) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(uid)
        .update({'muted': false});
  }

  Future<void> removeUser(String roomId, String uid) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(uid)
        .delete();
  }

  Future<void> lockRoom(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).update({'locked': true});
  }

  Future<void> unlockRoom(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).update({'locked': false});
  }

  Future<void> endRoom(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).update({'ended': true});
  }

  Future<void> promoteCoHost(String roomId, String uid) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(uid)
        .update({'role': 'cohost'});
  }

  Future<void> demoteCoHost(String roomId, String uid) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(uid)
        .update({'role': 'participant'});
  }

  // New methods for room management
  Future<void> promoteToSpeaker(String roomId, String uid) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(uid)
        .update({'role': 'speaker'});
  }

  Future<void> demoteToListener(String roomId, String uid) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(uid)
        .update({'role': 'listener'});
  }

  Future<void> makeModerator(String roomId, String uid) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(uid)
        .update({'role': 'moderator'});
  }

  Future<void> removeModerator(String roomId, String uid) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(uid)
        .update({'role': 'participant'});
  }

  Future<void> approveRaisedHand(String roomId, String uid) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(uid)
        .update({'handRaised': false, 'approved': true});
  }

  Future<void> declineRaisedHand(String roomId, String uid) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(uid)
        .update({'handRaised': false, 'approved': false});
  }

  Future<void> requestToSpeak(String roomId, String uid) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(uid)
        .update({'handRaised': true});
  }

  Future<void> createRoom(String roomId, Map<String, dynamic> roomData) async {
    await _firestore.collection('rooms').doc(roomId).set(roomData);
  }

  Stream<dynamic> getRoomStream(String roomId) {
    return _firestore.collection('rooms').doc(roomId).snapshots();
  }

  Stream<dynamic> getLiveRoomsStream() {
    return _firestore
        .collection('rooms')
        .where('ended', isEqualTo: false)
        .snapshots();
  }
}
