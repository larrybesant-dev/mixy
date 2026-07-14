import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/after_dark_provider.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../theme/after_dark_theme.dart';

enum _PinMode { setup, unlock }

/// PIN entry screen — handles both:
///  - First-time setup (/after-dark/pin-setup) — sets the PIN
///  - Later unlock (/after-dark/unlock) — verifies PIN
class AfterDarkPinScreen extends ConsumerStatefulWidget {
  // ignore: library_private_types_in_public_api
  final _PinMode mode;
  const AfterDarkPinScreen.setup({super.key}) : mode = _PinMode.setup;
  const AfterDarkPinScreen.unlock({super.key}) : mode = _PinMode.unlock;

  @override
  ConsumerState<AfterDarkPinScreen> createState() => _AfterDarkPinScreenState();
}

class _AfterDarkPinScreenState extends ConsumerState<AfterDarkPinScreen> {
  final List<String> _digits = [];
  String? _firstPin;
  String? _error;
  bool _loading = false;

  bool get _isSetup => widget.mode == _PinMode.setup;
  bool get _confirming => _isSetup && _firstPin != null;

  String get _title {
    if (_isSetup && !_confirming) return 'Create a PIN';
    if (_isSetup && _confirming) return 'Confirm PIN';
    return 'Enter PIN';
  }

  String get _subtitle {
    if (_isSetup && !_confirming) {
      return 'Set a 4-digit PIN to protect MixVy After Dark.';
    }
    if (_confirming) return 'Enter the same PIN again to confirm.';
    return 'Enter your 4-digit PIN to continue.';
  }

  void _onDigit(String d) {
    if (_digits.length >= 4) return;
    setState(() {
      _digits.add(d);
      _error = null;
    });
    if (_digits.length == 4) _onComplete();
  }

  void _onDelete() {
    if (_digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  Future<void> _onComplete() async {
    final pin = _digits.join();

    if (_isSetup) {
      if (_firstPin == null) {
        // Store first entry, reset for confirmation
        setState(() {
          _firstPin = pin;
          _digits.clear();
        });
        return;
      }
      // Confirming
      if (pin != _firstPin) {
        setState(() {
          _error = 'PINs do not match. Try again.';
          _digits.clear();
          _firstPin = null;
        });
        return;
      }
      // Confirmed — enable After Dark
      setState(() => _loading = true);
      await ref.read(afterDarkControllerProvider).enable(pin);
      if (!mounted) return;
      context.go('/after-dark');
    } else {
      // Unlock mode
      setState(() => _loading = true);
      final valid = await ref.read(afterDarkControllerProvider).unlock(pin);
      if (!mounted) return;
      if (valid) {
        context.go('/after-dark');
      } else {
        setState(() {
          _error = 'Incorrect PIN. Try again.';
          _digits.clear();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: afterDarkTheme,
      child: AppPageScaffold(
        backgroundColor: EmberDark.surface,
        safeArea: false,
        appBar: AppBar(
          backgroundColor: EmberDark.surface,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: EmberDark.onSurfaceVariant,
              size: 20,
            ),
            onPressed: () => context.go('/settings'),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Header
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: EmberDark.primary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _title,
                  style: const TextStyle(
                    color: EmberDark.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: EmberDark.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // PIN dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _digits.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? EmberDark.primary : Colors.transparent,
                        border: Border.all(
                          color: filled
                              ? EmberDark.primary
                              : EmberDark.outlineVariant,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: EmberDark.primary,
                      fontSize: 13,
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // Keypad
                if (_loading)
                  const CircularProgressIndicator(color: EmberDark.primary)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: _Keypad(onDigit: _onDigit, onDelete: _onDelete),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;

  const _Keypad({required this.onDigit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Row(
          children: row.map((k) {
            if (k.isEmpty) return Expanded(child: const SizedBox(height: 72));
            return Expanded(
              child: _KeyButton(
                label: k,
                onTap: () {
                  if (k == '⌫') {
                    onDelete();
                  } else {
                    onDigit(k);
                  }
                },
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _KeyButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDelete = label == '⌫';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        alignment: Alignment.center,
        child: isDelete
            ? const Icon(
                Icons.backspace_outlined,
                color: EmberDark.onSurfaceVariant,
                size: 22,
              )
            : Text(
                label,
                style: const TextStyle(
                  color: EmberDark.onSurface,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}



