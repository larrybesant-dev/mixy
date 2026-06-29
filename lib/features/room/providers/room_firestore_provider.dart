import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';

final roomFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  final firestore = ref.watch(firestoreProvider);
  
  // Log Firestore access for debugging connection issues
  debugPrint('[RoomFirestore] Firestore instance accessed for room operations');
  
  return firestore;
});




