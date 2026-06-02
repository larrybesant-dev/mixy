import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/app_page_scaffold.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

enum BetaItemStatus { untested, pass, fail, partial }

extension BetaItemStatusLabel on BetaItemStatus {
  String get label {
    switch (this) {
      case BetaItemStatus.untested:
        return 'Untested';
      case BetaItemStatus.pass:
        return '✓ Pass';
      case BetaItemStatus.fail:
        return '✗ Fail';
      case BetaItemStatus.partial:
        return '⚠ Partial';
    }
  }

  Color color(ColorScheme cs) {
    switch (this) {
      case BetaItemStatus.untested:
        return cs.onSurfaceVariant;
      case BetaItemStatus.pass:
        return Colors.green;
      case BetaItemStatus.fail:
        return cs.error;
      case BetaItemStatus.partial:
        return Colors.orange;
    }
  }
}

class _CheckItem {
  final String label;
  BetaItemStatus status;
  String note;

  _CheckItem(this.label)
      : status = BetaItemStatus.untested,
        note = '';
}

class _Section {
  final String title;
  final List<_CheckItem> items;

  _Section(this.title, List<String> labels)
      : items = labels.map(_CheckItem.new).toList();
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class BetaFeedbackScreen extends ConsumerStatefulWidget {
  const BetaFeedbackScreen({super.key});

  @override
  ConsumerState<BetaFeedbackScreen> createState() => _BetaFeedbackScreenState();
}

class _BetaFeedbackScreenState extends ConsumerState<BetaFeedbackScreen> {
  bool _submitting = false;
  String? _submitError;
  bool _submitted = false;

  final List<_Section> _sections = [
    _Section('Account & Profile', [
      'Sign up',
      'Login / Logout',
      'Password reset',
      'Profile setup',
      'Privacy settings',
      'Delete account',
    ]),
    _Section('Home Feed', [
      'See posts from friends',
      'Like / react to posts',
      'Comment & reply',
      'Share post',
      'Suggested friends',
      'Suggested rooms',
      'Infinite scroll',
      'Error & loading states',
    ]),
    _Section('Friends & Social', [
      'Send friend request',
      'Accept / reject request',
      'View friend list',
      'Invite friend to room',
      'Search friends',
      'Block / report user',
      'Friend activity',
    ]),
    _Section('Messaging', [
      '1:1 chat',
      'Group chat',
      'Read receipts',
      'Typing indicator',
      'Search conversation',
      'Delete message',
      'Notifications',
    ]),
    _Section('Live Rooms', [
      'Create room',
      'Join / leave room',
      'Multi-user video grid',
      'Chat window & auto-scroll',
      'Host controls',
      'Raise hand / mic request',
      'Room discovery',
      'Error handling & reconnect',
    ]),
    _Section('Speed Dating', [
      'Join session',
      'Auto-matching',
      'Rotation timer',
      'End-of-session options',
      'Error handling',
    ]),
    _Section('Notifications', [
      'Friend activity alerts',
      'Room invite alerts',
      'Push notifications (device)',
      'In-app notification feed',
      'Settings toggle per type',
    ]),
    _Section('Settings & Privacy', [
      'Account settings',
      'Privacy settings',
      'Video / audio permissions',
      'Block & report users',
      'Dark / light mode',
    ]),
    _Section('Video & Audio', [
      'Mute / unmute',
      'Camera on / off',
      'Spotlights / pin user',
      'Connection error recovery',
    ]),
    _Section('Performance & Reliability', [
      'App load time',
      'Video latency',
      'Cross-platform sync',
      'Reconnection logic',
    ]),
  ];

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final payload = _sections.map((section) {
        return {
          'title': section.title,
          'items': section.items.map((item) {
            return {
              'label': item.label,
              'status': item.status.name,
              'note': item.note,
            };
          }).toList(),
        };
      }).toList();

      await FirebaseFunctions.instance.httpsCallable('submitBetaFeedback').call(
        {'sections': payload},
      );

      if (mounted) setState(() => _submitted = true);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _submitError = e.message ?? e.code);
      }
    } catch (e) {
      if (mounted) setState(() => _submitError = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_submitted) {
      return AppPageScaffold(
        appBar: AppBar(title: const Text('Beta Feedback')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
              SizedBox(height: 16),
              Text(
                'Feedback submitted!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text('Thank you for testing MixVy. 🙏'),
            ],
          ),
        ),
      );
    }

    return AppPageScaffold(
      appBar: AppBar(title: const Text('Beta Feedback')),
      body: Column(
        children: [
          // Instructions banner
          Container(
            width: double.infinity,
            color: theme.colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'Mark each feature: ✓ Pass · ✗ Fail · ⚠ Partial · (blank) Untested. '
              'Add a note for anything broken or unexpected.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _sections.length,
              itemBuilder: (context, si) {
                final section = _sections[si];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                      child: Text(
                        section.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    ...section.items.map(
                      (item) => _CheckItemTile(
                        item: item,
                        onChanged: () => setState(() {}),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_submitError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _submitError!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit feedback'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-item tile
// ---------------------------------------------------------------------------

class _CheckItemTile extends StatefulWidget {
  final _CheckItem item;
  final VoidCallback onChanged;

  const _CheckItemTile({required this.item, required this.onChanged});

  @override
  State<_CheckItemTile> createState() => _CheckItemTileState();
}

class _CheckItemTileState extends State<_CheckItemTile> {
  bool _expanded = false;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _noteController.text = widget.item.note;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final status = widget.item.status;

    return Column(
      children: [
        ListTile(
          dense: true,
          title: Text(widget.item.label),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusButton(
                label: '✓',
                active: status == BetaItemStatus.pass,
                activeColor: Colors.green,
                onTap: () {
                  widget.item.status = status == BetaItemStatus.pass
                      ? BetaItemStatus.untested
                      : BetaItemStatus.pass;
                  widget.onChanged();
                },
              ),
              const SizedBox(width: 4),
              _StatusButton(
                label: '✗',
                active: status == BetaItemStatus.fail,
                activeColor: cs.error,
                onTap: () {
                  widget.item.status = status == BetaItemStatus.fail
                      ? BetaItemStatus.untested
                      : BetaItemStatus.fail;
                  widget.onChanged();
                },
              ),
              const SizedBox(width: 4),
              _StatusButton(
                label: '⚠',
                active: status == BetaItemStatus.partial,
                activeColor: Colors.orange,
                onTap: () {
                  widget.item.status = status == BetaItemStatus.partial
                      ? BetaItemStatus.untested
                      : BetaItemStatus.partial;
                  widget.onChanged();
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: _expanded ? 'Hide note' : 'Add note',
                icon: Icon(
                  _expanded ? Icons.notes : Icons.edit_note_outlined,
                  size: 18,
                  color: widget.item.note.isNotEmpty
                      ? cs.primary
                      : cs.onSurfaceVariant,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Describe the issue…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                widget.item.note = value;
                widget.onChanged();
              },
            ),
          ),
        const Divider(height: 1, indent: 16),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          border: Border.all(
            color: active
                ? activeColor
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: active
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
