// lib/features/profile/screens/report_user_page.dart
// Allows users to report another user to platform moderators.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mixvy/core/analytics/analytics_events.dart';
import 'package:mixvy/shared/widgets/club_background.dart';

class ReportUserPage extends StatefulWidget {
  final String userId;
  final String? displayName;

  const ReportUserPage({
    super.key,
    required this.userId,
    this.displayName,
  });

  @override
  State<ReportUserPage> createState() => _ReportUserPageState();
}

class _ReportUserPageState extends State<ReportUserPage> {
  static const _reportTypes = [
    'Spam or Scam',
    'Harassment or Bullying',
    'Inappropriate Content',
    'Fake Profile or Impersonation',
    'Hate Speech',
    'Suspected Minor (Under 18)',
    'Other',
  ];

  static const _suspectedMinorLabel = 'Suspected Minor (Under 18)';

  String? _selectedType;
  final _descController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a report type')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterId': uid,
        'reportedUserId': widget.userId,
        'type': _selectedType,
        'description': _descController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // If reporting a suspected minor, flag the reported user's admin record.
      if (_selectedType == _suspectedMinorLabel) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .set(
              {'adminFlags': {'suspectedMinor': true}},
              SetOptions(merge: true),
            );
        await FirebaseAnalytics.instance.logEvent(
          name: AnalyticsEvents.userReportedSuspectedMinor,
          parameters: {'reported_user_id': widget.userId},
        );
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. Thank you for keeping MixMingle safe.'),
            backgroundColor: Color(0xFF00C853),
          ),
        );
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.displayName ?? 'this user';
    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0F1A),
          foregroundColor: Colors.white,
          title: Text(
            'Report $name',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D8B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF4D8B).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: Color(0xFFFF4D8B), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your report is anonymous and will be reviewed by our moderation team.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ── Report Type ───────────────────────────────────────
              const Text(
                "What's the issue?",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ..._reportTypes.map((type) => _ReportTypeOption(
                    label: type,
                    selected: _selectedType == type,
                    onTap: () => setState(() => _selectedType = type),
                  )),
              const SizedBox(height: 24),
              // ── Additional Details ────────────────────────────────
              const Text(
                'Additional details (optional)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descController,
                maxLines: 4,
                maxLength: 500,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Describe what happened...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: const Color(0xFF1A1F2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF4D8B)),
                  ),
                  counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                ),
              ),
              const SizedBox(height: 28),
              // ── Submit ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D8B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: const Color(0xFFFF4D8B).withValues(alpha: 0.4),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Submit Report',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportTypeOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReportTypeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFF4D8B).withValues(alpha: 0.12)
              : const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFFFF4D8B)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? const Color(0xFFFF4D8B) : Colors.white38,
              size: 18,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFFFF4D8B) : Colors.white70,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

