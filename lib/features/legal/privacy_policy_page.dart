import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: ${DateTime.now().toString().split(' ')[0]}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Introduction',
              'Mix & Mingle ("we," "our," or "us") respects your privacy and is committed to protecting your personal data. This privacy policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application and services.',
            ),
            _buildSection(
              '1. Information We Collect',
              'We collect information that you provide directly to us, including:\n\n'
                  'â€¢ Account Information: Email address, display name, profile photo, bio, location, interests, and date of birth\n'
                  'â€¢ User Content: Messages, event creations, photos, videos, and other content you share\n'
                  'â€¢ Communications: Your communications with us and other users\n'
                  'â€¢ Payment Information: When you subscribe to premium features (processed securely through our payment providers)',
            ),
            _buildSection(
              '2. Automatically Collected Information',
              'When you use our services, we automatically collect:\n\n'
                  'â€¢ Device Information: Device type, operating system, unique device identifiers\n'
                  'â€¢ Usage Data: App features used, events attended, interactions with other users\n'
                  'â€¢ Location Data: Approximate location (with your permission) for event recommendations\n'
                  'â€¢ Analytics: App performance, crashes, and usage patterns via Firebase Analytics',
            ),
            _buildSection(
              '3. How We Use Your Information',
              'We use your information to:\n\n'
                  'â€¢ Provide, maintain, and improve our services\n'
                  'â€¢ Create and manage your account\n'
                  'â€¢ Enable video chat and messaging features\n'
                  'â€¢ Recommend events and connect you with other users\n'
                  'â€¢ Process payments and manage subscriptions\n'
                  'â€¢ Send notifications about messages, events, and app updates\n'
                  'â€¢ Ensure safety and prevent fraud or abuse\n'
                  'â€¢ Comply with legal obligations\n'
                  'â€¢ Analyze usage to improve user experience',
            ),
            _buildSection(
              '4. Information Sharing',
              'We DO NOT sell your personal information. We may share your information:\n\n'
                  'â€¢ With Other Users: Profile information is visible to other users; messages are shared with recipients\n'
                  'â€¢ Service Providers: Firebase (Google), Agora (video chat), payment processors, analytics providers\n'
                  'â€¢ Legal Requirements: When required by law, court order, or to protect rights and safety\n'
                  'â€¢ Business Transfers: In connection with mergers, acquisitions, or asset sales',
            ),
            _buildSection(
              '5. Data Retention',
              'We retain your information for as long as your account is active or as needed to provide services. You can request deletion of your data at any time through Account Settings. Some information may be retained for legal compliance, fraud prevention, or legitimate business purposes.',
            ),
            _buildSection(
              '6. Your Rights (GDPR/CCPA)',
              'You have the right to:\n\n'
                  'â€¢ Access: Request a copy of your personal data\n'
                  'â€¢ Rectification: Correct inaccurate information\n'
                  'â€¢ Erasure: Request deletion of your data\n'
                  'â€¢ Data Portability: Receive your data in a machine-readable format\n'
                  'â€¢ Object: Object to processing of your data\n'
                  'â€¢ Withdraw Consent: Withdraw consent at any time\n\n'
                  'To exercise these rights, go to Account Settings or contact us at privacy@mixandmingle.com',
            ),
            _buildSection(
              '7. Security',
              'We implement appropriate technical and organizational measures to protect your data, including:\n\n'
                  'â€¢ Encryption of data in transit and at rest\n'
                  'â€¢ Regular security audits\n'
                  'â€¢ Access controls and authentication\n'
                  'â€¢ Secure data centers (Firebase/Google Cloud)\n\n'
                  'However, no method of transmission over the internet is 100% secure.',
            ),
            _buildSection(
              '8. Children\'s Privacy',
              'Our service is not intended for users under 18 years of age. We do not knowingly collect information from children. If you believe we have collected information from a child, please contact us immediately.',
            ),
            _buildSection(
              '9. International Data Transfers',
              'Your information may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place for international transfers, including Standard Contractual Clauses approved by the European Commission.',
            ),
            _buildSection(
              '10. Cookies and Tracking',
              'We use cookies and similar technologies for:\n\n'
                  'â€¢ Authentication and security\n'
                  'â€¢ Preferences and settings\n'
                  'â€¢ Analytics and performance monitoring\n\n'
                  'You can control cookies through your browser settings.',
            ),
            _buildSection(
              '11. Third-Party Services',
              'Our app integrates with:\n\n'
                  'â€¢ Firebase (Google): Authentication, database, storage, analytics\n'
                  'â€¢ Agora: Real-time video and audio communication\n'
                  'â€¢ Payment Processors: Stripe or similar for subscriptions\n\n'
                  'These services have their own privacy policies that govern their use of your information.',
            ),
            _buildSection(
              '12. Changes to This Policy',
              'We may update this privacy policy from time to time. We will notify you of significant changes by posting the new policy with an updated "Last updated" date. Continued use of the service after changes constitutes acceptance.',
            ),
            _buildSection(
              '13. Contact Us',
              'If you have questions about this privacy policy or our data practices, contact us at:\n\n'
                  'Email: privacy@mixandmingle.com\n'
                  'Address: [Your Company Address]\n',
            ),
            const SizedBox(height: 32),
            Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(color: Colors.grey.shade600),
                  children: [
                    const TextSpan(
                        text: 'By using Mix & Mingle, you agree to our\n'),
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.pushNamed(context, '/terms');
                        },
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
