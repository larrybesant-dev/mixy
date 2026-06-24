import 'package:flutter/material.dart';
import 'package:mixvy/shared/models/camera_state.dart';
import 'package:mixvy/shared/models/camera_quality.dart';
import 'package:mixvy/services/camera/camera_service.dart';

class CameraQualitySelector extends StatefulWidget {
  final String roomId;
  final CameraQuality initialQuality;
  final Function(CameraQuality) onQualityChanged;

  const CameraQualitySelector({
    super.key,
    required this.roomId,
    this.initialQuality = CameraQuality.high,
    required this.onQualityChanged,
  });

  @override
  State<CameraQualitySelector> createState() => _CameraQualitySelectorState();
}

class _CameraQualitySelectorState extends State<CameraQualitySelector> {
  late CameraQuality _selectedQuality;
  final _cameraService = CameraService();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedQuality = widget.initialQuality;
  }

  void _updateQuality(CameraQuality quality) async {
    setState(() => _isUpdating = true);

    try {
      await _cameraService.setCameraQuality(widget.roomId, quality);

      setState(() {
        _selectedQuality = quality;
        _isUpdating = false;
      });

      widget.onQualityChanged(quality);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quality set to: ${quality.name.toUpperCase()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Camera Quality',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_isUpdating)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Quality options
            ..._buildQualityOptions(),

            const SizedBox(height: 24),

            // Current quality stats
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: _buildQualityStats(),
            ),

            const SizedBox(height: 24),

            // Close button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildQualityOptions() {
    return CameraQuality.values.map((quality) {
      final settings = CameraQualitySettings.forQuality(quality);
      final isSelected = _selectedQuality == quality;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: RadioListTile<CameraQuality>(
          value: quality,
          // ignore: deprecated_member_use
          groupValue: _selectedQuality,
          // ignore: deprecated_member_use
          onChanged: _isUpdating
              ? null
              : (value) {
                  if (value != null) {
                    _updateQuality(value);
                  }
                },
          title: Text(settings.displayName),
          subtitle: Text(
            '${settings.fps}fps â€¢ ${settings.bitrate}kbps â€¢ ~${settings.bandwidth}MB/s',
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
          ),
          selected: isSelected,
          activeColor: Colors.blue,
        ),
      );
    }).toList();
  }

  Widget _buildQualityStats() {
    final settings = CameraQualitySettings.forQuality(_selectedQuality);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current: ${settings.displayName}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ðŸ“Š Resolution: ${settings.resolution}p\n'
          'âš¡ Bitrate: ${settings.bitrate} kbps\n'
          'ðŸŽ¬ Frame Rate: ${settings.fps} fps\n'
          'ðŸŒ Bandwidth: ~${settings.bandwidth} MB/s',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

