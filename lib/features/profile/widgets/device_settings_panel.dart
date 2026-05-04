import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../services/device_prefs_service.dart';
import '../../../services/web_device_enum_stub.dart'
    if (dart.library.html) '../../../services/web_device_enum_web.dart'
    as device_enum;

/// A panel (usable as a card or inside a bottom sheet) that lets the user
/// enumerate their browser's cameras and microphones, select preferred devices,
/// and persist the choice via [DevicePrefsService].
///
/// On non-web platforms the device list will always be empty and a
/// "Not available on this platform" message is shown.
class DeviceSettingsPanel extends StatefulWidget {
  const DeviceSettingsPanel({super.key});

  @override
  State<DeviceSettingsPanel> createState() => _DeviceSettingsPanelState();
}

class _DeviceSettingsPanelState extends State<DeviceSettingsPanel> {
  final _prefs = DevicePrefsService();

  List<device_enum.MediaDeviceInfo> _cameras = const [];
  List<device_enum.MediaDeviceInfo> _mics = const [];
  String? _selectedCameraId;
  String? _selectedMicId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final devices = await device_enum.enumerateMediaDevices();
      final savedCam = await _prefs.getPreferredCameraId();
      final savedMic = await _prefs.getPreferredMicId();
      if (!mounted) return;
      setState(() {
        _cameras = devices.where((d) => d.kind == 'videoinput').toList();
        _mics = devices.where((d) => d.kind == 'audioinput').toList();
        _selectedCameraId =
            (savedCam != null && _cameras.any((c) => c.deviceId == savedCam))
            ? savedCam
            : (_cameras.isNotEmpty ? _cameras.first.deviceId : null);
        _selectedMicId =
            (savedMic != null && _mics.any((m) => m.deviceId == savedMic))
            ? savedMic
            : (_mics.isNotEmpty ? _mics.first.deviceId : null);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not read devices: $e';
        _loading = false;
      });
    }
  }

  Future<void> _onCameraChanged(String? id) async {
    if (id == null) return;
    setState(() => _selectedCameraId = id);
    await _prefs.setPreferredCameraId(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera preference saved. Takes effect on next room join.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _onMicChanged(String? id) async {
    if (id == null) return;
    setState(() => _selectedMicId = id);
    await _prefs.setPreferredMicId(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Microphone preference saved. Takes effect on next room join.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isWeb = kIsWeb;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.devices_outlined, color: scheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Camera & Microphone',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Select which camera and mic to use in live rooms.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        if (!isWeb)
          _InfoTile(
            icon: Icons.info_outline,
            message: 'Device selection is only available in the web browser.',
            color: scheme.secondary,
          )
        else if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          _InfoTile(
            icon: Icons.warning_amber_outlined,
            message: _error!,
            color: scheme.error,
          )
        else if (_cameras.isEmpty && _mics.isEmpty)
          _InfoTile(
            icon: Icons.perm_device_info_outlined,
            message:
                'No devices found. Allow camera/mic access in your browser settings, then refresh.',
            color: scheme.secondary,
          )
        else ...[
          if (_cameras.isNotEmpty) ...[
            _DeviceDropdown(
              label: 'Camera',
              icon: Icons.videocam_outlined,
              devices: _cameras,
              selectedId: _selectedCameraId,
              onChanged: _onCameraChanged,
            ),
            const SizedBox(height: 12),
          ],
          if (_mics.isNotEmpty) ...[
            _DeviceDropdown(
              label: 'Microphone',
              icon: Icons.mic_outlined,
              devices: _mics,
              selectedId: _selectedMicId,
              onChanged: _onMicChanged,
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh device list'),
          ),
        ],
      ],
    );
  }
}

class _DeviceDropdown extends StatelessWidget {
  const _DeviceDropdown({
    required this.label,
    required this.icon,
    required this.devices,
    required this.selectedId,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final List<device_enum.MediaDeviceInfo> devices;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: scheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      isExpanded: true,
      items: devices
          .map(
            (d) => DropdownMenuItem<String>(
              value: d.deviceId,
              child: Text(
                d.label.isNotEmpty
                    ? d.label
                    : 'Device ${d.deviceId.substring(0, 6)}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
