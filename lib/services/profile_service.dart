import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/models/profile_privacy_model.dart';
import 'package:mixvy/models/adult_profile_model.dart';
import 'schema_mutation_service.dart';

class ProfileService {
  final FirebaseFirestore firestore;
  final SchemaMutationService? schemaMutationService;
  
  ProfileService({
    required this.firestore,
    this.schemaMutationService,
  });

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
    
    // Route through SchemaMutationService if available
    if (schemaMutationService != null) {
      await schemaMutationService!.updateProfilePublic(
        userId: userId,
        userData: userData,
        privacy: ProfilePrivacyModel.fromJson(privacy as Map<String, dynamic>),
        adultProfile: AdultProfileModel.fromJson(adultProfile as Map<String, dynamic>),
      );
    } else {
      // Fallback for backward compatibility
      final updateData = {
        ...userData,
        'privacy': privacy,
        'adultProfile': adultProfile,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await firestore.collection('users').doc(userId).set(updateData, SetOptions(merge: true));
    }
  }
}
