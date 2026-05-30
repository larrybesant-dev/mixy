import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../widgets/safe_network_avatar.dart';

import '../../../core/layout/app_layout.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../shared/widgets/app_page_scaffold.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final String userId;
  final String username;
  final String? avatarUrl;

  const CreatePostScreen({
    super.key,
    required this.userId,
    required this.username,
    this.avatarUrl,
  });

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  late TextEditingController _contentController;
  late TextEditingController _tagsController;
  bool _isPosting = false;
  bool _isUploadingMedia = false;
  String? _imageUrl;
  String? _videoUrl;

  static const int _maxPhotoBytes = 20 * 1024 * 1024;
  static const int _maxVideoBytes = 120 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
    _tagsController = TextEditingController();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _publishPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post cannot be empty')));
      return;
    }

    setState(() => _isPosting = true);

    try {
      final tags = _tagsController.text.isEmpty
          ? <String>[]
          : _tagsController.text
                .split(',')
                .map((tag) => tag.trim().toLowerCase())
                .toList();

      await ref.read(firestoreProvider).collection('posts').add({
        'authorId': widget.userId,
        'authorName': widget.username,
        'authorAvatarUrl': widget.avatarUrl,
        'content': content,
        'imageUrl': _imageUrl,
        'videoUrl': _videoUrl,
        'tags': tags,
        'hashtags': tags,
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'commentCount': 0,
        'shareCount': 0,
        'likes': [],
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post published!')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error publishing post: $e')));
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  Future<String> _uploadToStorage({
    required XFile file,
    required String folder,
    required String extension,
    required String contentType,
  }) async {
    final bytes = await file.readAsBytes().timeout(const Duration(seconds: 20));
    final maxBytes = contentType.startsWith('video/')
        ? _maxVideoBytes
        : _maxPhotoBytes;
    if (bytes.lengthInBytes > maxBytes) {
      throw Exception(
        contentType.startsWith('video/')
            ? 'Video is too large. Choose one under 120MB.'
            : 'Photo is too large. Choose one under 20MB.',
      );
    }

    final path =
        'users/${widget.userId}/posts/$folder/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = FirebaseStorage.instance.ref(path);
    await ref
        .putData(bytes, SettableMetadata(contentType: contentType))
        .timeout(const Duration(seconds: 60));
    return ref.getDownloadURL();
  }

  Future<void> _pickPhoto() async {
    if (_isUploadingMedia || _isPosting) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (file == null) return;

    setState(() => _isUploadingMedia = true);
    try {
      final imageUrl = await _uploadToStorage(
        file: file,
        folder: 'images',
        extension: 'jpg',
        contentType: 'image/jpeg',
      );
      if (!mounted) return;
      setState(() {
        _imageUrl = imageUrl;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post photo uploaded.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Photo upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
    }
  }

  Future<void> _pickVideo() async {
    if (_isUploadingMedia || _isPosting) return;
    final picker = ImagePicker();
    final file = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    if (file == null) return;

    setState(() => _isUploadingMedia = true);
    try {
      final videoUrl = await _uploadToStorage(
        file: file,
        folder: 'videos',
        extension: 'mp4',
        contentType: 'video/mp4',
      );
      if (!mounted) return;
      setState(() {
        _videoUrl = videoUrl;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post video uploaded.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Video upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ElevatedButton(
                      onPressed: _isUploadingMedia ? null : _publishPost,
                      child: const Text('Post'),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.pageHorizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SafeNetworkAvatar(
                  radius: 20,
                  avatarUrl: widget.avatarUrl,
                  fallbackText: widget.username.isNotEmpty
                      ? widget.username[0].toUpperCase()
                      : '?',
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.username,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Public',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                border: InputBorder.none,
              ),
              maxLines: null,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (comma-separated)',
                hintText: 'e.g., flutter, coding, mobile',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            if (_isUploadingMedia)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            if (_imageUrl != null || _videoUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_imageUrl != null)
                      const Chip(
                        avatar: Icon(Icons.image, size: 16),
                        label: Text('Photo attached'),
                      ),
                    if (_videoUrl != null)
                      const Chip(
                        avatar: Icon(Icons.videocam, size: 16),
                        label: Text('Video attached'),
                      ),
                    TextButton.icon(
                      onPressed: _isUploadingMedia
                          ? null
                          : () => setState(() {
                              _imageUrl = null;
                              _videoUrl = null;
                            }),
                      icon: const Icon(Icons.clear),
                      label: const Text('Remove media'),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  tooltip: 'Add photo',
                  onPressed: (_isUploadingMedia || _isPosting)
                      ? null
                      : _pickPhoto,
                ),
                IconButton(
                  icon: const Icon(Icons.video_camera_back),
                  tooltip: 'Add video',
                  onPressed: (_isUploadingMedia || _isPosting)
                      ? null
                      : _pickVideo,
                ),
                // Emoji picker intentionally hidden until implemented.
                // IconButton(
                //   icon: const Icon(Icons.emoji_emotions),
                //   onPressed: null,
                // ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



