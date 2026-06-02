import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/models/user_model.dart';

class ProfileService {
  final FirebaseFirestore firestore;
  ProfileService({required this.firestore});

  Future<UserModel?> loadProfile(String userId) async {
    final doc = await firestore.collection('users').doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromJson({'id': doc.id, ...doc.data()!});
  }

  Future<void> saveProfile(
      {required String userId,
      required Map<String, dynamic> userData,
      required bool privacy,
      required bool adultProfile}) async {
    await firestore.collection('users').doc(userId).update({
      ...userData,
      'privacy': privacy,
      'adultProfile': adultProfile,
    });
  }
}
