import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/models/profile_privacy_model.dart';
import 'package:mixvy/models/adult_profile_model.dart';
import 'schema_mutation_service.dart';

class ProfileService {
  final FirebaseFirestore firestore;
  final SchemaMutationService? schemaMutationService;
  final http.Client? httpClient;
  final FirebaseAuth? auth;

  ProfileService({
    required this.firestore,
    this.schemaMutationService,
    this.httpClient,
    this.auth,
  });

  Future<UserModel?> loadProfile(String userId) async {
    // Phase 1: Try Function endpoint (bypasses browser extensions)
    try {
      final uri = Uri.parse(
        'https://us-east1-mixvy-v2.cloudfunctions.net/getProfile',
      ).replace(queryParameters: {
        'userId': userId,
        'cacheBust': DateTime.now().microsecondsSinceEpoch.toString(),
      });
      final response = await (httpClient?.get(uri) ?? http.get(uri))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['success'] == true) {
          return UserModel.fromJson({'id': userId, ...json});
        }
      }
      developer.log(
        'Profile endpoint unavailable; reading Firestore (${response.statusCode})',
        name: 'ProfileService',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Profile endpoint failed; reading Firestore',
        name: 'ProfileService',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Phase 2: Fall back to direct Firestore
    final documents = await Future.wait([
      firestore.collection('users').doc(userId).get(),
      firestore.collection('profile_public').doc(userId).get(),
      firestore.collection('preferences').doc(userId).get(),
    ]);
    final identity = documents[0].data();
    if (identity == null) return null;
    return UserModel.fromJson({
      ...identity,
      ...?documents[1].data(),
      ...?documents[2].data(),
      'id': userId,
    });
  }

  Future<void> saveProfile(
      {required String userId,
      required Map<String, dynamic> userData,
      required bool privacy,
      required bool adultProfile}) async {
    // Ensure username is always persisted for first-time profile bootstrap.
    final rawUsername = (userData['username'] as String? ?? '').trim();
    final safeFallbackUsername =
        'user_${userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase().padRight(6, '0').substring(0, 6)}';
    final resolvedUsername =
        rawUsername.isNotEmpty ? rawUsername : safeFallbackUsername;
    userData['username'] = resolvedUsername;
    userData['displayName'] =
        (userData['displayName'] as String? ?? '').trim().isNotEmpty
            ? userData['displayName']
            : resolvedUsername;

    // Phase 1: Try Function endpoint with auth token
    try {
      final currentUser = (auth ?? FirebaseAuth.instance).currentUser;
      if (currentUser != null) {
        final token = await currentUser.getIdToken();

        // Create ProfilePrivacyModel from bool
        final privacyModel = ProfilePrivacyModel(isPrivate: privacy);

        // Create AdultProfileModel from bool
        final adultModel = AdultProfileModel(
          userId: userId,
          enabled: adultProfile,
          adultConsentAccepted:
              userData['adultConsentAccepted'] as bool? ?? false,
        );

        final uri = Uri.parse(
          'https://us-east1-mixvy-v2.cloudfunctions.net/saveProfile',
        );
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        };
        final body = jsonEncode({
          'userData': userData,
          'privacy': privacyModel.toJson(),
          'adultProfile': adultModel.toJson(),
        });
        final response = await (httpClient?.post(
              uri,
              headers: headers,
              body: body,
            ) ??
            http.post(uri, headers: headers, body: body))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          if (json['success'] == true) {
            return; // Function endpoint succeeded
          }
        }
        developer.log(
          'Profile save endpoint unavailable; using schema writer (${response.statusCode})',
          name: 'ProfileService',
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Profile save endpoint failed; using schema writer',
        name: 'ProfileService',
        error: error,
        stackTrace: stackTrace,
      );
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
