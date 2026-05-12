import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore/firestore_debug_tracing.dart';
import '../core/streams/stream_lifecycle_manager.dart';
import '../models/presence_model.dart';

class PresenceService {
  PresenceService({
    FirebaseFirestore? firestore,
    StreamLifecycleManager? streamLifecycleManager,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _streamLifecycleManager = streamLifecycleManager;

  final FirebaseFirestore _firestore;
  final StreamLifecycleManager? _streamLifecycleManager;

  DocumentReference<Map<String, dynamic>> _ref(String userId) =>
      _firestore.collection('presence').doc(userId);

  Stream<PresenceModel> watchUserPresence(String userId) {
    final snapshots = _ref(userId).snapshots();
    final managed = _streamLifecycleManager != null
        ? _streamLifecycleManager.bind<DocumentSnapshot<Map<String, dynamic>>>(
            key: 'presence/$userId',
            create: () => snapshots,
          )
        : snapshots;

    return traceFirestoreStream<PresenceModel>(
      key: 'presence/$userId',
      query: 'presence/$userId',
      userId: userId,
      itemCount: (_) => 1,
      stream: managed.map((doc) {
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
