import 'package:cloud_firestore/cloud_firestore.dart';

/// Terms and legal agreements management
class TermsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String termsVersion = '1.0.0';
  static const String privacyVersion = '1.0.0';

  /// Get current terms of service
  Future<String> getTermsOfService() async {
    try {
      final doc =
          await _firestore.collection('legal').doc('terms_of_service').get();
      return doc['content'] ?? _defaultTermsOfService();
    } catch (e) {
      return _defaultTermsOfService();
    }
  }

  /// Get current privacy policy
  Future<String> getPrivacyPolicy() async {
    try {
      final doc =
          await _firestore.collection('legal').doc('privacy_policy').get();
      return doc['content'] ?? _defaultPrivacyPolicy();
    } catch (e) {
      return _defaultPrivacyPolicy();
    }
  }

  /// Record user's acceptance of terms
  Future<void> recordTermsAcceptance(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'accepted_terms_version': termsVersion,
        'accepted_privacy_version': privacyVersion,
        'accepted_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to record terms acceptance: $e');
    }
  }

  /// Check if user has accepted current terms
  Future<bool> hasAcceptedCurrentTerms(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final acceptedVersion = doc['accepted_terms_version'] as String?;
      return acceptedVersion == termsVersion;
    } catch (e) {
      return false;
    }
  }

  static String _defaultTermsOfService() {
    return '''
MixMingle Terms of Service
Last Updated: January 31, 2026

1. ACCEPTANCE OF TERMS
By accessing and using MixMingle ("the Service"), you accept and agree to be bound by the terms and provision of this agreement.

2. USE LICENSE
Permission is granted to temporarily download one copy of the materials (including information and software) on MixMingle for personal, non-commercial transitory viewing only. This is the grant of a license, not a transfer of title.

3. DISCLAIMER OF WARRANTIES
The materials on MixMingle's web site are provided on an 'as is' basis. MixMingle makes no warranties, expressed or implied, and hereby disclaims and negates all other warranties including, without limitation, implied warranties or conditions of merchantability, fitness for a particular purpose, or non-infringement of intellectual property or other violation of rights.

4. LIMITATIONS OF LIABILITY
In no event shall MixMingle or its suppliers be liable for any damages (including, without limitation, damages for loss of data or profit, or due to business interruption) arising out of the use or inability to use the materials on MixMingle's Internet site.

5. ACCURACY OF MATERIALS
The materials appearing on MixMingle's web site could include technical, typographical, or photographic errors. MixMingle does not warrant that any of the materials on its web site are accurate, complete, or current. MixMingle may make changes to the materials contained on its web site at any time without notice.

6. MODIFICATIONS
MixMingle may revise these terms of service for its web site at any time without notice. By using this web site, you are agreeing to be bound by the then current version of these terms of service.

7. GOVERNING LAW
These terms and conditions are governed by and construed in accordance with the laws of [Your Jurisdiction] and you irrevocably submit to the exclusive jurisdiction of the courts located in that location.

8. USER CONDUCT
Users agree not to:
- Post content that is abusive, harassing, or defamatory
- Attempt to impersonate any person or entity
- Post sexually explicit material or child sexual abuse material
- Spam or flood the service
- Attempt to gain unauthorized access to the service
- Use the service for any illegal purpose

9. CONTENT REMOVAL
MixMingle reserves the right to remove any content that violates these terms at any time without notice.

10. ACCOUNT SUSPENSION
MixMingle reserves the right to suspend or terminate accounts that violate these terms of service.
    ''';
  }

  static String _defaultPrivacyPolicy() {
    return '''
MixMingle Privacy Policy
Last Updated: January 31, 2026

1. INFORMATION WE COLLECT
We collect information you provide directly to us, such as when you create an account, update your profile, or communicate with other users.

2. HOW WE USE INFORMATION
We use the information we collect to:
- Provide, maintain, and improve our services
- Send you technical notices and support messages
- Respond to your comments, questions, and requests
- Monitor and analyze trends and usage of our services
- Detect and prevent fraudulent transactions and other illegal activities

3. SHARING OF INFORMATION
We do not sell, trade, or rent your personal information to third parties. We may share information with:
- Service providers who assist us in operating our website and conducting our business
- Law enforcement when required by law
- Other parties with your consent

4. DATA SECURITY
We implement appropriate technical and organizational measures designed to protect personal information against unauthorized access, alteration, disclosure, or destruction.

5. YOUR PRIVACY RIGHTS
You have the right to:
- Access your personal information
- Correct inaccurate information
- Request deletion of your information
- Opt-out of marketing communications

6. CHANGES TO THIS POLICY
We may update this privacy policy from time to time. We encourage you to review this policy periodically for changes.

7. CONTACT US
If you have questions about this privacy policy, please contact us at privacy@mixmingle.app
    ''';
  }
}
