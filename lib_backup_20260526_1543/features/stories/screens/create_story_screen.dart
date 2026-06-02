import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/story_provider.dart';
import '../../../core/layout/app_layout.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/app_page_scaffold.dart';

enum _StoryType { text, photo, video }

class CreateStoryScreen extends ConsumerStatefulWidget {
  final String userId;
  final String username;
  final String? avatarUrl;

  const CreateStoryScreen({
    super.key,
    required this.userId,
    required this.username,
    this.avatarUrl,
  });

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  late TextEditingController _textController;
  bool _isPosting = false;
  bool _isUploadingMedia = false;
  String? _imageUrl;
  String? _videoUrl;
  _StoryType _type = _StoryType.text;
  double _uploadProgress = 0;
  StreamSubscription<TaskSnapshot>? _uploadProgressSub;

  static const int _maxPhotoBytes = 20 * 1024 * 1024;
  static const int _maxVideoBytes = 120 * 1024 * 1024;
  static const int _maxTextChars = 180;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _uploadProgressSub?.cancel();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _publishStory() async {
    final content = _textController.text.trim();
    if (content.isEmpty && _imageUrl == null && _videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add text, a photo, or a video to post a story.'),
        ),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      await ref.read(storyControllerProvider).createStory(
            userId: widget.userId,
            username: widget.username,
            userAvatarUrl: widget.avatarUrl,
            content: content,
            imageUrl: _imageUrl,
            videoUrl: _videoUrl,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story posted! Expires in 24 hours')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error posting story: $e')));
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
    final maxBytes =
        contentType.startsWith('video/') ? _maxVideoBytes : _maxPhotoBytes;
    if (bytes.lengthInBytes > maxBytes) {
      throw Exception(
        contentType.startsWith('video/')
            ? 'Video is too large. Choose one under 120MB.'
            : 'Photo is too large. Choose one under 20MB.',
      );
    }

    final path =
        'users/${widget.userId}/stories/$folder/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = FirebaseStorage.instance.ref(path);
    // UploadTask starts immediately; we await it below via task.timeout().
    final task = ref.putData(bytes, SettableMetadata(contentType: contentType));
    await _uploadProgressSub?.cancel();
    _uploadProgressSub = task.snapshotEvents.listen((snap) {
      if (snap.totalBytes > 0 && mounted) {
        setState(
          () => _uploadProgress = snap.bytesTransferred / snap.totalBytes,
        );
      }
    });
    await task.timeout(const Duration(seconds: 60));
    return await ref.getDownloadURL();
  }

  Future<void> _pickPhoto() async {
    if (_isUploadingMedia || _isPosting) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (file == null) return;

    setState(() {
      _isUploadingMedia = true;
      _uploadProgress = 0;
    });
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
        _videoUrl = null;
        _type = _StoryType.photo;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Photo upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _pickVideo() async {
    if (_isUploadingMedia || _isPosting) return;
    final picker = ImagePicker();
    final file = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 45),
    );
    if (file == null) return;

    setState(() {
      _isUploadingMedia = true;
      _uploadProgress = 0;
    });
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
        _imageUrl = null;
        _type = _StoryType.video;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Video upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPost = !_isPosting &&
        !_isUploadingMedia &&
        (_textController.text.trim().isNotEmpty ||
            _imageUrl != null ||
            _videoUrl != null);

    return AppPageScaffold(
      backgroundColor: VelvetNoir.surface,
      appBar: AppBar(
        backgroundColor: VelvetNoir.surfaceHigh,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: VelvetNoir.onSurface),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'New Story',
          style: TextStyle(
            color: VelvetNoir.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isPosting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: VelvetNoir.primary,
                    ),
                  )
                : TextButton(
                    onPressed: canPost ? _publishStory : null,
                    style: TextButton.styleFrom(
                      backgroundColor: canPost
                          ? VelvetNoir.primary
                          : VelvetNoir.surfaceBright,
                      foregroundColor: canPost
                          ? VelvetNoir.surface
                          : VelvetNoir.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Share',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Upload progress bar
          if (_isUploadingMedia)
            LinearProgressIndicator(
              value: _uploadProgress > 0 ? _uploadProgress : null,
              backgroundColor: VelvetNoir.surfaceHigh,
              color: VelvetNoir.primary,
              minHeight: 3,
            ),

          // Story preview
          _buildPreview(),

          // Type selector
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.pageHorizontalPadding,
              12,
              context.pageHorizontalPadding,
              4,
            ),
            child: Row(
              children: [
                _typeChip(_StoryType.text, Icons.text_fields, 'Text'),
                const SizedBox(width: 8),
                _typeChip(_StoryType.photo, Icons.image_outlined, 'Photo'),
                const SizedBox(width: 8),
                _typeChip(_StoryType.video, Icons.videocam_outlined, 'Video'),
              ],
            ),
          ),

          // Content area
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                context.pageHorizontalPadding,
                8,
                context.pageHorizontalPadding,
                24,
              ),
              child: _buildContentArea(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(_StoryType type, IconData icon, String label) {
    final selected = _type == type;
    return GestureDetector(
      onTap: () {
        setState(() => _type = type);
        if (type == _StoryType.photo) _pickPhoto();
        if (type == _StoryType.video) _pickVideo();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? VelvetNoir.primary : VelvetNoir.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? VelvetNoir.primary : VelvetNoir.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color:
                  selected ? VelvetNoir.surface : VelvetNoir.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    selected ? VelvetNoir.surface : VelvetNoir.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: const BoxDecoration(color: VelvetNoir.surfaceLow),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background: image or gradient
          if (_imageUrl != null)
            CachedNetworkImage(
              imageUrl: _imageUrl!,
              fit: BoxFit.cover,
              placeholder: (__, _) =>
                  const ColoredBox(color: VelvetNoir.surfaceHigh),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [VelvetNoir.primaryDim, Color(0xFF0D0A0C)],
                ),
              ),
            ),

          // Video indicator overlay
          if (_videoUrl != null)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_fill, size: 56, color: Colors.white70),
                  SizedBox(height: 8),
                  Text(
                    'Video ready',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Text overlay (shown for text type, or as overlay on image)
          if (_type == _StoryType.text ||
              (_imageUrl != null && _textController.text.trim().isNotEmpty))
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _textController.text.isEmpty
                      ? 'Your text here…'
                      : _textController.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

          // Remove media button
          if (_imageUrl != null || _videoUrl != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => setState(() {
                  _imageUrl = null;
                  _videoUrl = null;
                  _type = _StoryType.text;
                }),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),

          // Uploading overlay
          if (_isUploadingMedia)
            Container(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: _uploadProgress > 0 ? _uploadProgress : null,
                      color: VelvetNoir.primary,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Uploading…',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContentArea() {
    final charCount = _textController.text.length;
    final remaining = _maxTextChars - charCount;

    if (_type == _StoryType.photo && _imageUrl == null) {
      return _mediaPicker(
        icon: Icons.add_photo_alternate_outlined,
        label: 'Tap to add a photo',
        onTap: _pickPhoto,
      );
    }

    if (_type == _StoryType.video && _videoUrl == null) {
      return _mediaPicker(
        icon: Icons.video_call_outlined,
        label: 'Tap to add a video  (max 45 s)',
        onTap: _pickVideo,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text field
        DecoratedBox(
          decoration: BoxDecoration(
            color: VelvetNoir.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: VelvetNoir.outlineVariant),
          ),
          child: TextField(
            controller: _textController,
            style: const TextStyle(color: VelvetNoir.onSurface, fontSize: 15),
            maxLines: _type == _StoryType.text ? 6 : 3,
            maxLength: _maxTextChars,
            decoration: InputDecoration(
              hintText: _type == _StoryType.text
                  ? 'Share what\'s on your mind… (24 h only)'
                  : 'Add a caption…',
              hintStyle: const TextStyle(
                color: VelvetNoir.onSurfaceVariant,
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // Character counter
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '$remaining',
                style: TextStyle(
                  fontSize: 12,
                  color: remaining < 20
                      ? VelvetNoir.error
                      : VelvetNoir.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Change media button (for photo/video types)
        if (_type != _StoryType.text) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: VelvetNoir.onSurfaceVariant,
              side: const BorderSide(color: VelvetNoir.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _isUploadingMedia
                ? null
                : (_type == _StoryType.photo ? _pickPhoto : _pickVideo),
            icon: Icon(
              _type == _StoryType.photo ? Icons.swap_horiz : Icons.swap_horiz,
              size: 18,
            ),
            label: Text(
              _type == _StoryType.photo ? 'Change photo' : 'Change video',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  Widget _mediaPicker({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: VelvetNoir.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: VelvetNoir.outlineVariant,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: VelvetNoir.primary),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: VelvetNoir.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
