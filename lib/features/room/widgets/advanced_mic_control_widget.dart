import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/room/services/advanced_mic_service.dart';

/// Advanced Microphone Control Widget
///
/// Displays a comprehensive microphone control panel with:
/// - Volume slider
/// - Echo cancellation toggle
/// - Noise suppression toggle
/// - Auto gain control toggle
/// - Sound mode selector
class AdvancedMicControlWidget extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const AdvancedMicControlWidget({
    super.key,
    this.onClose,
  });

  @override
  ConsumerState<AdvancedMicControlWidget> createState() =>
      _AdvancedMicControlWidgetState();
}

class _AdvancedMicControlWidgetState
    extends ConsumerState<AdvancedMicControlWidget> {
  @override
  Widget build(BuildContext context) {
    final micState = ref.watch(advancedMicServiceProvider);
    final micNotifier = ref.read(advancedMicServiceProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.mic, color: Color(0xFFFF4C4C), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Microphone Control',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Volume Control
            _buildVolumeControl(context, micState, micNotifier),
            const SizedBox(height: 24),

            // Sound Mode Selector
            _buildSoundModeSelector(context, micState, micNotifier),
            const SizedBox(height: 24),

            // Enhancement Toggles
            _buildEnhancementToggles(context, micState, micNotifier),
            const SizedBox(height: 20),

            // Reset Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  micNotifier.reset();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Microphone settings reset to default'),
                      duration: Duration(milliseconds: 1500),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Reset to Default',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeControl(
    BuildContext context,
    AdvancedMicServiceState state,
    AdvancedMicServiceNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Volume Level',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4C4C).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${state.volumeLevel.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Color(0xFFFF4C4C),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            activeTrackColor: const Color(0xFFFF4C4C),
            inactiveTrackColor: Colors.grey[600],
            thumbColor: const Color(0xFFFF4C4C),
          ),
          child: Slider(
            value: state.volumeLevel,
            min: 0,
            max: 100,
            onChanged: (value) {
              notifier.setVolumeLevel(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSoundModeSelector(
    BuildContext context,
    AdvancedMicServiceState state,
    AdvancedMicServiceNotifier notifier,
  ) {
    const modes = [
      {'label': 'Default', 'value': 0},
      {'label': 'Enhanced', 'value': 1},
      {'label': 'Speech', 'value': 2},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sound Mode',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: modes.map((mode) {
            final isSelected = state.soundMode == mode['value'];
            return InkWell(
              onTap: () {
                notifier.setSoundMode(mode['value'] as int);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color:
                      isSelected ? const Color(0xFFFF4C4C) : Colors.grey[700],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFF4C4C)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(
                  mode['label'] as String,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[300],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEnhancementToggles(
    BuildContext context,
    AdvancedMicServiceState state,
    AdvancedMicServiceNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Audio Enhancements',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildToggleTile(
          icon: Icons.waves,
          label: 'Echo Cancellation',
          value: state.echoCancellationEnabled,
          onChanged: (_) {
            notifier.toggleEchoCancellation();
          },
        ),
        const SizedBox(height: 12),
        _buildToggleTile(
          icon: Icons.filter_alt,
          label: 'Noise Suppression',
          value: state.noiseSuppressionEnabled,
          onChanged: (_) {
            notifier.toggleNoiseSuppression();
          },
        ),
        const SizedBox(height: 12),
        _buildToggleTile(
          icon: Icons.volume_up,
          label: 'Auto Gain Control',
          value: state.autoGainControlEnabled,
          onChanged: (_) {
            notifier.toggleAutoGainControl();
          },
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String label,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFF4C4C), size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFFFF4C4C),
            inactiveThumbColor: Colors.grey[600],
            inactiveTrackColor: Colors.grey[700],
          ),
        ],
      ),
    );
  }
}

