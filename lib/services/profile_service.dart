import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
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
    // Phase 1: Try Function endpoint (bypasses browser extensions)
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://us-east1-mixvy-v2.cloudfunctions.net/getProfile?userId=$userId',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          return UserModel.fromJson({'id': userId, ...json});
        }
      }
    } catch (_) {
      // Function endpoint unavailable, fall through to Phase 2
    }

    // Phase 2: Fall back to direct Firestore
    try {
      final doc = await firestore.collection('users').doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromJson({'id': doc.id, ...doc.data()!});
    } catch (_) {
      // Firestore also unavailable
      return null;
    }
  }

  Future<void> saveProfile({
    required String userId, 
    required Map<String, dynamic> userData, 
    required bool privacy, 
    required bool adultProfile
  }) async {
    // Ensure username is always persisted for first-time profile bootstrap.
    final rawUsername = (userData['username'] as String? ?? '').trim();
    final safeFallbackUsername = 'user_${userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase().padRight(6, '0').substring(0, 6)}';
    final resolvedUsername = rawUsername.isNotEmpty ? rawUsername : safeFallbackUsername;
    userData['username'] = resolvedUsername;
    userData['displayName'] = (userData['displayName'] as String? ?? '').trim().isNotEmpty
        ? userData['displayName']
        : resolvedUsername;
    
    // Phase 1: Try Function endpoint with auth token
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final token = await currentUser.getIdToken();
        
        // Create ProfilePrivacyModel from bool
        final privacyModel = ProfilePrivacyModel(isPrivate: privacy);
        
        // Create AdultProfileModel from bool
        final adultModel = AdultProfileModel(
          userId: userId,
          enabled: adultProfile,
          adultConsentAccepted: userData['adultConsentAccepted'] as bool? ?? false,
        );

        final response = await http
            .post(
              Uri.parse(
                'https://us-east1-mixvy-v2.cloudfunctions.net/saveProfile',
              ),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'userData': userData,
                'privacy': privacyModel.toJson(),
                'adultProfile': adultModel.toJson(),
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['success'] == true) {
            return; // Function endpoint succeeded
          }
        }
      }
    } catch (_) {
      // Function endpoint unavailable, fall through to Phase 2
    }

    // Phase 2: Always write through SchemaMutationService boundary.
    final mutationService =
        schemaMutationService ?? SchemaMutationService(firestore: firestore);

    // Create ProfilePrivacyModel from bool
    final privacyModel = ProfilePrivacyModel(isPrivate: privacy);

    // Create AdultProfileModel from bool
    final adultModel = AdultProfileModel(
      userId: userId,
      enabled: adultProfile,
      adultConsentAccepted: userData['adultConsentAccepted'] as bool? ?? false,
    );

    await mutationService.updateProfilePublic(
      userId: userId,
      userData: userData,
      privacy: privacyModel,
      adultProfile: adultModel,
    );
  }
}
