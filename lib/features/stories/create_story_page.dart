import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/design_constants.dart';
import '../../services/social/stories_service.dart';

class CreateStoryPage extends ConsumerStatefulWidget {
  const CreateStoryPage({super.key});

  @override
  ConsumerState<CreateStoryPage> createState() => _CreateStoryPageState();
}

class _CreateStoryPageState extends ConsumerState<CreateStoryPage> {
  File? _selectedFile;
  StoryMediaType _mediaType = StoryMediaType.image;
  final _captionController = TextEditingController();
  bool _isUploading = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  // ── Media picking ──────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (xfile != null && mounted) {
      setState(() {
        _selectedFile = File(xfile.path);
        _mediaType = StoryMediaType.image;
      });
    }
  }

  Future<void> _takePhoto() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1080,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (xfile != null && mounted) {
      setState(() {
        _selectedFile = File(xfile.path);
        _mediaType = StoryMediaType.image;
      });
    }
  }

  // ── Upload ─────────────────────────────────────────────────────────────────

  Future<void> _upload() async {
    final file = _selectedFile;
    if (file == null) return;

    setState(() => _isUploading = true);
    try {
      final id = await StoriesService.instance.createStory(
        file: file,
        mediaType: _mediaType,
        caption: _captionController.text.trim().isEmpty
            ? null
            : _captionController.text.trim(),
      );
      if (mounted) {
        if (id != null) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Story posted! It will expire in 24 hours.'),
              backgroundColor: Color(0xFF4A90FF),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to post story. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: DesignColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'New Story',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_selectedFile != null)
            TextButton(
              onPressed: _isUploading ? null : _upload,
              child: Text(
                _isUploading ? 'Posting…' : 'Post',
                style: TextStyle(
                  color: _isUploading ? DesignColors.textGray : DesignColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: _selectedFile == null
          ? _buildPickerScreen()
          : _buildEditorScreen(),
    );
  }

  // ── Picker screen (no file selected yet) ──────────────────────────────────

  Widget _buildPickerScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 72, color: DesignColors.textGray.withValues(alpha: 0.4)),
          const SizedBox(height: 24),
          const Text(
            'Share a moment',
            style: TextStyle(
              color: DesignColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your story disappears after 24 hours',
            style: TextStyle(color: DesignColors.textGray, fontSize: 14),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pickButton(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: _pickImage,
              ),
              const SizedBox(width: 20),
              _pickButton(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: _takePhoto,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pickButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: DesignColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignColors.accent.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: DesignColors.accent, size: 32),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: DesignColors.textGray,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ]),
      ),
    );
  }

  // ── Editor screen (file selected, add caption) ────────────────────────────

  Widget _buildEditorScreen() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.only(bottomLeft: Radius.circular(0)),
                child: Image.file(
                  _selectedFile!,
                  fit: BoxFit.contain,
                ),
              ),
              if (_isUploading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DesignColors.accent,
                        ),
                        SizedBox(height: 12),
                        Text('Posting story…',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Caption input
        Container(
          color: DesignColors.background,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _captionController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: 'Add a caption…',
                    hintStyle: TextStyle(
                        color: DesignColors.textGray.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: DesignColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _pickImage,
                icon: const Icon(Icons.change_circle_outlined,
                    color: DesignColors.textGray),
                tooltip: 'Change media',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
