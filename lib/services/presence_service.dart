import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore/firestore_debug_tracing.dart';
import '../models/presence_model.dart';

class PresenceService {
  PresenceService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _ref(String userId) =>
      _firestore.collection('presence').doc(userId);

  Stream<PresenceModel> watchUserPresence(String userId) {
    return traceFirestoreStream<PresenceModel>(
      key: 'presence/$userId',
      query: 'presence/$userId',
      userId: userId,
      itemCount: (_) => 1,
      stream: _ref(userId).snapshots().map((doc) {
        final data = doc.data();
        if (data == null) {
          return PresenceModel(
            userId: userId,
            isOnline: false,
            online: false,
            status: UserStatus.offline,
          );
        }
        return PresenceModel.fromJson({'userId': userId, ...data});
      }),
    );
  }

  Stream<bool> userPresenceStream(String userId) =>
      watchUserPresence(userId).map((presence) => presence.isOnline == true);
}
