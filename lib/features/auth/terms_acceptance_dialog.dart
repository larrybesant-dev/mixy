import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/infra/terms_service.dart';
import '../../core/utils/app_logger.dart';

/// Dialog for accepting Terms of Service and Privacy Policy
class TermsAcceptanceDialog extends ConsumerStatefulWidget {
  final VoidCallback onAccepted;
  final VoidCallback onRejected;

  const TermsAcceptanceDialog({
    super.key,
    required this.onAccepted,
    required this.onRejected,
  });

  @override
  ConsumerState<TermsAcceptanceDialog> createState() =>
      _TermsAcceptanceDialogState();
}

class _TermsAcceptanceDialogState extends ConsumerState<TermsAcceptanceDialog> {
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final termsService = TermsService();

    return PopScope(
      canPop: false, // Prevent dismissal by back button
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: FutureBuilder(
          future: Future.wait([
            termsService.getTermsOfService(),
            termsService.getPrivacyPolicy(),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading legal documents...'),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Error loading terms. Please try again.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Legal Requirements',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Before using MixMingle, please review and accept our legal documents.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),

                    // Terms acceptance section
                    _buildCheckboxRow(
                      label: 'I accept the Terms of Service',
                      value: _acceptedTerms,
                      onChanged: (value) =>
                          setState(() => _acceptedTerms = value ?? false),
                    ),

                    // Privacy acceptance section
                    _buildCheckboxRow(
                      label: 'I accept the Privacy Policy',
                      value: _acceptedPrivacy,
                      onChanged: (value) =>
                          setState(() => _acceptedPrivacy = value ?? false),
                    ),

                    const SizedBox(height: 20),

                    // Read documents button
                    TextButton(
                      onPressed: () =>
                          _showDocumentsDialog(context, termsService),
                      child: const Text('Read full documents'),
                    ),

                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  AppLogger.info('User rejected terms');
                                  widget.onRejected();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                          ),
                          child: const Text('Decline'),
                        ),
                        ElevatedButton(
                          onPressed:
                              (_acceptedTerms && _acceptedPrivacy && !_loading)
                                  ? () {
                                      setState(() => _loading = true);
                                      AppLogger.info('User accepted terms');
                                      widget.onAccepted();
                                    }
                                  : null,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Accept'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCheckboxRow({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showDocumentsDialog(BuildContext context, TermsService termsService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Legal Documents'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tab-like buttons to switch between documents
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Terms of Service'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Privacy Policy'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Document content would go here
              const Text(
                'Please review the full legal documents to ensure you understand our policies.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
