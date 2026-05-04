import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/schema_migration_flags.dart';
import '../models/adult_profile_model.dart';
import '../models/profile_privacy_model.dart';
import 'schema_mutation_service.dart';

class ProfileBundle {
  const ProfileBundle({
    required this.userData,
    required this.privacy,
    required this.adultProfile,
  });

  final Map<String, dynamic> userData;
  final ProfilePrivacyModel privacy;
  final AdultProfileModel adultProfile;
}

class ProfileService {
  ProfileService({
    FirebaseFirestore? firestore,
    SchemaMutationService? mutationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _mutationService =
           mutationService ?? SchemaMutationService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final SchemaMutationService _mutationService;

  Future<ProfileBundle> loadProfile(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final profilePublicRef = _firestore
        .collection('profile_public')
        .doc(userId);
    final preferencesRef = _firestore.collection('preferences').doc(userId);
    final verificationRef = _firestore.collection('verification').doc(userId);
    final privacyRef = userRef.collection('privacy').doc('settings');
    final adultRef = userRef.collection('adult_profile').doc('details');

    final results = await Future.wait([
      userRef.get(),
      profilePublicRef.get(),
      preferencesRef.get(),
      verificationRef.get(),
      privacyRef.get(),
      adultRef.get(),
    ]);

    final userSnapshot = results[0];
    final profilePublicSnapshot = results[1];
    final preferencesSnapshot = results[2];
    final verificationSnapshot = results[3];
    final privacySnapshot = results[4];
    final adultSnapshot = results[5];

    final mergedUserData = _mergeProfileReadModel(
      usersData: userSnapshot.data(),
      profilePublicData: profilePublicSnapshot.data(),
      preferencesData: preferencesSnapshot.data(),
      verificationData: verificationSnapshot.data(),
    );

    return ProfileBundle(
      userData: mergedUserData,
      privacy: ProfilePrivacyModel.fromJson(privacySnapshot.data()),
      adultProfile: AdultProfileModel.fromJson({
        'userId': userId,
        ...?adultSnapshot.data(),
      }),
    );
  }

  Future<void> saveProfile({
    required String userId,
    required Map<String, dynamic> userData,
    required ProfilePrivacyModel privacy,
    required AdultProfileModel adultProfile,
  }) async {
    await _mutationService.updateProfilePublic(
      userId: userId,
      userData: userData,
      privacy: privacy,
      adultProfile: adultProfile,
    );
  }

  Map<String, dynamic> _mergeProfileReadModel({
    required Map<String, dynamic>? usersData,
    required Map<String, dynamic>? profilePublicData,
    required Map<String, dynamic>? preferencesData,
    required Map<String, dynamic>? verificationData,
  }) {
    final users = usersData ?? const <String, dynamic>{};
    final profile = profilePublicData ?? const <String, dynamic>{};
    final preferences = preferencesData ?? const <String, dynamic>{};
    final verification = verificationData ?? const <String, dynamic>{};

    if (!SchemaMigrationFlags.enableUsersShadowMerge) {
      return <String, dynamic>{
        ...profile,
        ...preferences,
        ...verification,
        // Identity always comes from users, even when shadow merge is off.
        'id': users['id'],
        'username': users['username'],
        'usernameLower': users['usernameLower'],
        'email': users['email'],
        'createdAt': users['createdAt'],
      };
    }

    // Source-of-truth hierarchy during migration:
    // users(identity baseline) -> profile_public -> preferences -> verification.
    return <String, dynamic>{
      ...users,
      ...profile,
      ...preferences,
      ...verification,
    };
  }
}
