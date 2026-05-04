import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';

final roomFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return ref.watch(firestoreProvider);
});
