import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/providers.dart';

// ── Room Settings Panel ────────────────────────────────────────────────────
// Host-only bottom sheet for editing room metadata and applying bulk controls.

class RoomSettingsPanel extends ConsumerStatefulWidget {
  final String roomId;
  final Map<String, dynamic> roomData;

  const RoomSettingsPanel({
    super.key,
    required this.roomId,
    required this.roomData,
  });

  /// Show as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String roomId,
    required Map<String, dynamic> roomData,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomSettingsPanel(roomId: roomId, roomData: roomData),
    );
  }

  @override
  ConsumerState<RoomSettingsPanel> createState() => _RoomSettingsPanelState();
}

class _RoomSettingsPanelState extends ConsumerState<RoomSettingsPanel> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _coverCtrl;
  late bool _isPublic;
  bool _micLocked = false;
  bool _cameraLocked = false;
  bool _saving = false;
  double _maxParticipants = 50;
  String? _selectedCategory;

  static const _categories = ['Music', 'Dating', 'Talk', 'Gaming', 'Study', 'News'];
  static const _categoryIcons = {
    'Music': Icons.music_note,
    'Dating': Icons.favorite,
    'Talk': Icons.chat_bubble,
    'Gaming': Icons.sports_esports,
    'Study': Icons.school,
    'News': Icons.newspaper,
  };

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.roomData['name'] as String? ?? '');
    _descCtrl = TextEditingController(text: widget.roomData['description'] as String? ?? '');
    _coverCtrl = TextEditingController(text: widget.roomData['coverImageUrl'] as String? ?? '');
    _maxParticipants = (widget.roomData['maxParticipants'] as int?)?.toDouble() ?? 50.0;
    _maxParticipants = _maxParticipants.clamp(5.0, 200.0);
    _selectedCategory = widget.roomData['category'] as String?;
    _isPublic = widget.roomData['isPublic'] as bool? ?? true;
    _micLocked = widget.roomData['micLocked'] as bool? ?? false;
    _cameraLocked = widget.roomData['cameraLocked'] as bool? ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _coverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Room Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Room name
              _label('Room Name'),
              const SizedBox(height: 6),
              _field(
                controller: _nameCtrl,
                hint: 'Give your room a name',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),

              // Description
              _label('Description'),
              const SizedBox(height: 6),
              _field(
                controller: _descCtrl,
                hint: 'What is this room about?',
                maxLines: 3,
              ),
              const SizedBox(height: 14),

              // Cover image URL
              _label('Cover Image URL'),
              const SizedBox(height: 6),
              _field(
                controller: _coverCtrl,
                hint: 'https://...',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 14),

              // Category selector
              _label('Category'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final selected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = selected ? null : cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF4A90FF).withValues(alpha: 0.25)
                            : const Color(0xFF1E2D40),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF4A90FF)
                              : const Color(0xFF2D3A50),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _categoryIcons[cat]!,
                            size: 14,
                            color: selected
                                ? const Color(0xFF4A90FF)
                                : Colors.white54,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat,
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xFF4A90FF)
                                  : Colors.white70,
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Max participants slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _label('Max Participants'),
                  Text(
                    '${_maxParticipants.round()}',
                    style: const TextStyle(
                      color: Color(0xFF00E5CC),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF4A90FF),
                  inactiveTrackColor: const Color(0xFF2D3A50),
                  thumbColor: const Color(0xFF4A90FF),
                  overlayColor: const Color(0xFF4A90FF).withValues(alpha: 0.2),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                ),
                child: Slider(
                  min: 5,
                  max: 200,
                  divisions: 39,
                  value: _maxParticipants,
                  label: '${_maxParticipants.round()}',
                  onChanged: (v) => setState(() => _maxParticipants = v),
                ),
              ),
              const SizedBox(height: 18),

              // Public / Private toggle
              _settingRow(
                label: 'Public Room',
                subtitle: _isPublic
                    ? 'Anyone can discover and join'
                    : 'Invite-only',
                icon: _isPublic ? Icons.public : Icons.lock_outline,
                iconColor: _isPublic
                    ? const Color(0xFF00E5CC)
                    : const Color(0xFFFFAB00),
                child: Switch(
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                  activeThumbColor: const Color(0xFF00E5CC),
                ),
              ),

              // Lock mics
              _settingRow(
                label: 'Lock Microphones',
                subtitle: _micLocked
                    ? 'Participants cannot unmute'
                    : 'Participants can use mic',
                icon: _micLocked ? Icons.mic_off : Icons.mic,
                iconColor: _micLocked
                    ? const Color(0xFFFF4D8B)
                    : const Color(0xFF4A90FF),
                child: Switch(
                  value: _micLocked,
                  onChanged: (v) => setState(() => _micLocked = v),
                  activeThumbColor: const Color(0xFFFF4D8B),
                ),
              ),

              // Lock cameras
              _settingRow(
                label: 'Lock Cameras',
                subtitle: _cameraLocked
                    ? 'Participants cannot enable video'
                    : 'Participants can use camera',
                icon: _cameraLocked ? Icons.videocam_off : Icons.videocam,
                iconColor: _cameraLocked
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFF8B5CF6),
                child: Switch(
                  value: _cameraLocked,
                  onChanged: (v) => setState(() => _cameraLocked = v),
                  activeThumbColor: const Color(0xFFFF6B35),
                ),
              ),

              const SizedBox(height: 10),
              const Divider(color: Colors.white12),
              const SizedBox(height: 10),

              // Mute all button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF4D8B),
                    side: const BorderSide(color: Color(0xFFFF4D8B)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.volume_off),
                  label: const Text('Mute All Participants Now'),
                  onPressed: _muteAll,
                ),
              ),

              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final svc = ref.read(moderationServiceProvider);
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        if (_coverCtrl.text.trim().isNotEmpty)
          'coverImageUrl': _coverCtrl.text.trim(),
        'maxParticipants': _maxParticipants.round(),
        if (_selectedCategory != null) 'category': _selectedCategory,
        'isPublic': _isPublic,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Apply mic/camera locks via moderation service
      await svc.lockAllMics(roomId: widget.roomId, locked: _micLocked);
      await svc.lockAllCameras(roomId: widget.roomId, locked: _cameraLocked);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _muteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text('Mute Everyone',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will mute all participants immediately. They can unmute themselves unless mics are locked.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mute All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(moderationServiceProvider)
          .muteAllParticipants(roomId: widget.roomId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('All participants muted')));
      }
    }
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF1E2D40),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2D3A50)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2D3A50)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4A90FF)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _settingRow({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
