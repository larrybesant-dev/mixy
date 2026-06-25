import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import '../../../models/user_model.dart';

final userProvider = FutureProvider.family<UserModel?, String>((
  ref,
  userId,
) async {
  final firestore = ref.watch(firestoreProvider);
  final doc = await firestore.collection('users').doc(userId).get();
  if (!doc.exists) return null;
  final data = doc.data();
  if (data == null) return null;
  return UserModel.fromJson({...data, 'id': doc.id});
});




