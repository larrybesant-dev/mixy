import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import '../models/feedback_model.dart';
import '../providers/feedback_provider.dart';

class FeedbackModal extends ConsumerStatefulWidget {
  const FeedbackModal({super.key});

  @override
  ConsumerState<FeedbackModal> createState() => _FeedbackModalState();
}

class _FeedbackModalState extends ConsumerState<FeedbackModal> {
  final _formKey = GlobalKey<FormState>();
  String _category = 'Bug';
  String _description = '';
  Uint8List? _screenshotBytes;
  bool _checklistExpanded = false;
  // Removed _submitting, use FeedbackState.isLoading

  final List<String> _categories = [
    'Bug',
    'UI Issue',
    'Performance Issue',
    'Confusing Flow',
    'Feature Request',
    'Other',
  ];

  final List<String> _checklist = [
    'App loads without errors',
    'Login works',
    'Profile edits save',
    'Discovery cards load',
    'Like/Pass works',
    'Matches appear',
    'Chat opens and messages send',
    'Navigation works',
    'No broken images',
    'No layout issues',
    'No confusing screens',
    'No slow transitions',
  ];

  Future<void> _pickScreenshot() async {
    if (kIsWeb) {
      final input = web.HTMLInputElement();
      input.type = 'file';
      input.accept = 'image/*';
      input.click();
      input.onChange.listen((event) {
        final files = input.files;
        if (files != null && files.length > 0) {
          final file = files.item(0);
          if (file != null) {
            final reader = web.FileReader();
            reader.readAsDataURL(file);
            reader.onLoadEnd.listen((event) {
              setState(() {
                final dataUrl = reader.result as String;
                // Extract base64 part and decode to bytes
                final base64String = dataUrl.split(',').last;
                _screenshotBytes = base64Decode(base64String);
              });
            });
          }
        }
      });
    }
    // For mobile, use image_picker (not implemented here for brevity)
  }

  Map<String, String> _getMetadata() {
    final user = FirebaseAuth.instance.currentUser;
    final browser = kIsWeb ? 'Web' : Theme.of(context).platform.toString();
    final os = Theme.of(context).platform.toString();
    final screen = '${MediaQuery.of(context).size.width}x${MediaQuery.of(context).size.height}';
    final userId = user?.uid ?? 'unknown';
    const appVersion = 'web-beta-1.0';
    final timestamp = Timestamp.now();
    return {
      'browser': browser,
      'os': os,
      'screen': screen,
      'userId': userId,
      'appVersion': appVersion,
      'timestamp': timestamp.toDate().toIso8601String(),
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final meta = _getMetadata();
    String? screenshotUrl;
    if (_screenshotBytes != null) {
      screenshotUrl = await ref.read(feedbackControllerProvider.notifier).uploadScreenshot(
        userId: meta['userId']!,
        timestamp: meta['timestamp']!,
        bytes: _screenshotBytes!,
      );
    }
    final feedback = FeedbackModel(
      category: _category,
      description: _description,
      browser: meta['browser']!,
      os: meta['os']!,
      screen: meta['screen']!,
      userId: meta['userId']!,
      appVersion: meta['appVersion']!,
      screenshotUrl: screenshotUrl,
      timestamp: Timestamp.now(),
    );
    await ref.read(feedbackControllerProvider.notifier).submitFeedback(feedback: feedback);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks! Your feedback was sent.'),),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExpansionPanelList(
                expansionCallback: (i, expanded) {
                  setState(() => _checklistExpanded = !_checklistExpanded);
                },
                children: [
                  ExpansionPanel(
                    headerBuilder: (context, isOpen) => const ListTile(
                      title: Text('Beta Tester Checklist'),
                    ),
                    body: Column(
                      children: _checklist
                          .map((item) => ListTile(
                                leading: const Icon(Icons.check_circle_outline),
                                title: Text(item),
                              ))
                          .toList(),
                    ),
                    isExpanded: _checklistExpanded,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: _categories
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _category = val ?? 'Bug'),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                onChanged: (val) => _description = val,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Upload Screenshot'),
                onPressed: _pickScreenshot,
              ),
              if (_screenshotBytes != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.memory(_screenshotBytes!, height: 120),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: ref.watch(feedbackControllerProvider).isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: ref.watch(feedbackControllerProvider).isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Submit Feedback'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
