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

  Future<void> saveProfile({
    required String userId, 
    required Map<String, dynamic> userData, 
    required bool privacy, 
    required bool adultProfile
  }) async {
    // Ensure username is set (required for profile completion)
    final username = userData['username'] as String? ?? '';
    if (username.trim().isEmpty) {
      throw Exception('Username is required to save profile');
    }
    
    final updateData = {
      ...userData,
      'privacy': privacy,
      'adultProfile': adultProfile,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    
    await firestore.collection('users').doc(userId).set(updateData, SetOptions(merge: true));
  }
}
