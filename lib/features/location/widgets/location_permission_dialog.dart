import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/location_providers.dart';

/// Dialog widget for requesting location permission
class LocationPermissionDialog extends ConsumerStatefulWidget {
  final VoidCallback? onPermissionGranted;
  final VoidCallback? onPermissionDenied;

  const LocationPermissionDialog({
    super.key,
    this.onPermissionGranted,
    this.onPermissionDenied,
  });

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => LocationPermissionDialog(
        onPermissionGranted: () => Navigator.pop(context, true),
        onPermissionDenied: () => Navigator.pop(context, false),
      ),
    );
  }

  @override
  ConsumerState<LocationPermissionDialog> createState() =>
      _LocationPermissionDialogState();
}

class _LocationPermissionDialogState
    extends ConsumerState<LocationPermissionDialog> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enable Location Services'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MixVy uses your location to discover nearby events and users.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your location data is:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildPermissionBenefit('🎯 Discover nearby social events'),
          _buildPermissionBenefit('👥 Find users in your area'),
          _buildPermissionBenefit('🔒 Private and encrypted'),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  Navigator.pop(context, false);
                  widget.onPermissionDenied?.call();
                },
          child: const Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _requestPermission,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enable Location'),
        ),
      ],
    );
  }

  Widget _buildPermissionBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final hasPermission = await ref
          .read(requestLocationPermissionProvider.future)
          .then((value) => value);

      if (hasPermission) {
        if (mounted) {
          Navigator.pop(context, true);
          widget.onPermissionGranted?.call();
        }
      } else {
        setState(() {
          _errorMessage =
              'Location permission was denied. Please enable it in app settings.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error requesting location: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Bottom sheet for location permission
class LocationPermissionBottomSheet extends ConsumerStatefulWidget {
  final VoidCallback? onPermissionGranted;
  final VoidCallback? onPermissionDenied;

  const LocationPermissionBottomSheet({
    super.key,
    this.onPermissionGranted,
    this.onPermissionDenied,
  });

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationPermissionBottomSheet(
        onPermissionGranted: () => Navigator.pop(context, true),
        onPermissionDenied: () => Navigator.pop(context, false),
      ),
    );
  }

  @override
  ConsumerState<LocationPermissionBottomSheet> createState() =>
      _LocationPermissionBottomSheetState();
}

class _LocationPermissionBottomSheetState
    extends ConsumerState<LocationPermissionBottomSheet> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.location_on, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Share Your Location',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Discover nearby events and connect with users in your area.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _requestPermission,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.location_on),
                label: const Text('Enable Location'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        Navigator.pop(context, false);
                        widget.onPermissionDenied?.call();
                      },
                child: const Text('Maybe Later'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final hasPermission = await ref
          .read(requestLocationPermissionProvider.future)
          .then((value) => value);

      if (hasPermission) {
        if (mounted) {
          Navigator.pop(context, true);
          widget.onPermissionGranted?.call();
        }
      } else {
        setState(() {
          _errorMessage =
              'Location permission was denied. Please enable it in app settings.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error requesting location: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
