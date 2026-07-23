import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mixvy/core/layout/app_layout.dart';
import 'package:mixvy/features/auth/providers/admin_provider.dart';
import 'package:mixvy/features/payments/admin_entitlement_providers.dart';
import 'package:mixvy/shared/widgets/app_page_scaffold.dart';

class AdminEntitlementViewerScreen extends ConsumerStatefulWidget {
  const AdminEntitlementViewerScreen({super.key});

  @override
  ConsumerState<AdminEntitlementViewerScreen> createState() =>
      _AdminEntitlementViewerScreenState();
}

class _AdminEntitlementViewerScreenState
    extends ConsumerState<AdminEntitlementViewerScreen> {
  final TextEditingController _lookupController = TextEditingController();

  bool _lookupInProgress = false;
  bool _actionInProgress = false;
  String? _lookupError;
  String? _actionMessage;
  String? _resolvedUserId;

  @override
  void dispose() {
    _lookupController.dispose();
    super.dispose();
  }

  Future<void> _resolveUser() async {
    final rawInput = _lookupController.text.trim();
    if (rawInput.isEmpty) {
      setState(() {
        _lookupError = 'Enter an exact user ID or email address.';
        _resolvedUserId = null;
      });
      return;
    }

    setState(() {
      _lookupInProgress = true;
      _lookupError = null;
      _actionMessage = null;
    });

    try {
      final userId = await ref.read(entitlementLookupProvider(rawInput).future);

      if (!mounted) return;
      setState(() {
        _resolvedUserId = userId;
        _lookupError = userId == null ? 'No user matched "$rawInput".' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lookupError = 'Lookup failed: $error';
        _resolvedUserId = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _lookupInProgress = false;
        });
      }
    }
  }

  Future<void> _setVipState({
    required String userId,
    required bool active,
  }) async {
    setState(() {
      _actionInProgress = true;
      _actionMessage = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'adminSetEntitlement',
      );
      await callable.call<Map<String, dynamic>>({
        'userId': userId,
        'active': active,
        'reason': active ? 'support_grant' : 'support_revoke',
      });
      if (!mounted) return;
      setState(() {
        _actionMessage = active
            ? 'VIP granted successfully.'
            : 'VIP revoked successfully.';
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _actionMessage = error.message ?? 'Entitlement update failed.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actionMessage = 'Entitlement update failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;

    return AppPageScaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0B),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Entitlement Support',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFFD4AF37),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: !isAdmin
          ? const _AdminAccessRequired()
          : ListView(
              padding: EdgeInsets.fromLTRB(
                context.pageHorizontalPadding,
                24,
                context.pageHorizontalPadding,
                40,
              ),
              children: [
                _SupportHeaderCard(),
                const SizedBox(height: 16),
                _LookupCard(
                  controller: _lookupController,
                  lookupInProgress: _lookupInProgress,
                  lookupError: _lookupError,
                  onLookup: _resolveUser,
                ),
                if (_actionMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _actionMessage!,
                    style: GoogleFonts.raleway(
                      color: _actionMessage!.contains('failed')
                          ? Colors.red.shade300
                          : const Color(0xFFF7EDE2),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (_resolvedUserId != null) ...[
                  const SizedBox(height: 20),
                  _ResolvedUserPanel(
                    userId: _resolvedUserId!,
                    actionInProgress: _actionInProgress,
                    onGrantVip: () =>
                        _setVipState(userId: _resolvedUserId!, active: true),
                    onRevokeVip: () =>
                        _setVipState(userId: _resolvedUserId!, active: false),
                  ),
                ],
              ],
            ),
    );
  }
}

class _SupportHeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1200), Color(0xFF0B0B0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x22D4AF37)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Billing truth surface',
            style: GoogleFonts.playfairDisplay(
              color: const Color(0xFFD4AF37),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Look up a user by exact UID or email, inspect current entitlement state, and review the latest entitlement events before changing anything.',
            style: GoogleFonts.raleway(
              color: const Color(0xFFF7EDE2).withValues(alpha: 0.75),
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _LookupCard extends StatelessWidget {
  const _LookupCard({
    required this.controller,
    required this.lookupInProgress,
    required this.lookupError,
    required this.onLookup,
  });

  final TextEditingController controller;
  final bool lookupInProgress;
  final String? lookupError;
  final VoidCallback onLookup;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22D4AF37)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lookup user',
            style: GoogleFonts.raleway(
              color: const Color(0xFFF7EDE2),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            style: GoogleFonts.raleway(color: const Color(0xFFF7EDE2)),
            decoration: InputDecoration(
              hintText: 'uid_123 or user@example.com',
              hintStyle: GoogleFonts.raleway(
                color: const Color(0xFFF7EDE2).withValues(alpha: 0.35),
              ),
              filled: true,
              fillColor: const Color(0xFF0F0F0F),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onSubmitted: (_) => onLookup(),
          ),
          if (lookupError != null) ...[
            const SizedBox(height: 10),
            Text(
              lookupError!,
              style: GoogleFonts.raleway(
                color: Colors.red.shade300,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: lookupInProgress ? null : onLookup,
            child: Text(lookupInProgress ? 'Checking...' : 'Resolve user'),
          ),
        ],
      ),
    );
  }
}

class _ResolvedUserPanel extends ConsumerWidget {
  const _ResolvedUserPanel({
    required this.userId,
    required this.actionInProgress,
    required this.onGrantVip,
    required this.onRevokeVip,
  });

  final String userId;
  final bool actionInProgress;
  final VoidCallback onGrantVip;
  final VoidCallback onRevokeVip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDocAsync = ref.watch(entitlementUserDocProvider(userId));
    final eventsAsync = ref.watch(entitlementEventsProvider(userId));

    return Column(
      children: [
        userDocAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (__, _) => const SizedBox.shrink(),
          data: (data) {
            final entitlements = data?['entitlements'] as Map<String, dynamic>?;
            final vip = entitlements?['vip'] as Map<String, dynamic>?;
            final isActive = vip?['active'] == true;
            final email = (data?['email'] as String?)?.trim();
            final username = (data?['username'] as String?)?.trim();
            final reason =
                (vip?['reason'] as String?) ??
                (vip?['revokeReason'] as String?);
            final source = vip?['source'] as String?;

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isActive
                      ? const Color(0x44D4AF37)
                      : const Color(0x33781E2B),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          username?.isNotEmpty == true ? username! : userId,
                          style: GoogleFonts.playfairDisplay(
                            color: const Color(0xFFF7EDE2),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _StatusChip(active: isActive),
                    ],
                  ),
                  if (email?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      email!,
                      style: GoogleFonts.raleway(
                        color: const Color(0xFFF7EDE2).withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _InfoRow(label: 'User ID', value: userId),
                  _InfoRow(label: 'Source', value: source ?? 'unknown'),
                  _InfoRow(label: 'Reason', value: reason ?? 'n/a'),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton(
                        onPressed: actionInProgress ? null : onGrantVip,
                        child: Text(
                          actionInProgress ? 'Working...' : 'Grant VIP',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: actionInProgress ? null : onRevokeVip,
                        child: const Text('Revoke VIP'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        eventsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (__, _) => const SizedBox.shrink(),
          data: (eventDocs) {
            final docs = [...eventDocs]
              ..sort((a, b) {
                final aData = a.data();
                final bData = b.data();
                final aMillis = _timestampMillis(aData['createdAt']);
                final bMillis = _timestampMillis(bData['createdAt']);
                return bMillis.compareTo(aMillis);
              });

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x22D4AF37)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent entitlement events',
                    style: GoogleFonts.raleway(
                      color: const Color(0xFFF7EDE2),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (docs.isEmpty)
                    Text(
                      'No entitlement events found for this user.',
                      style: GoogleFonts.raleway(
                        color: const Color(0xFFF7EDE2).withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    )
                  else
                    ...docs.map((doc) {
                      final data = doc.data();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _EventTile(data: data),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0x22D4AF37) : const Color(0x33781E2B),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? const Color(0x55D4AF37) : const Color(0x55781E2B),
        ),
      ),
      child: Text(
        active ? 'VIP ACTIVE' : 'VIP INACTIVE',
        style: GoogleFonts.raleway(
          color: active ? const Color(0xFFD4AF37) : const Color(0xFFF7EDE2),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.raleway(
            color: const Color(0xFFF7EDE2),
            fontSize: 13,
            height: 1.5,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final createdAt = _formatTimestamp(data['createdAt']);
    final type = (data['type'] as String?) ?? 'unknown';
    final source = (data['source'] as String?) ?? 'unknown';
    final paymentStatus = data['paymentStatus'] as String?;
    final reason = data['reason'] as String?;
    final sessionId = data['sessionId'] as String?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type,
            style: GoogleFonts.raleway(
              color: const Color(0xFFD4AF37),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$createdAt • source=$source',
            style: GoogleFonts.raleway(
              color: const Color(0xFFF7EDE2).withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          if (paymentStatus != null || reason != null || sessionId != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (paymentStatus != null) 'payment=$paymentStatus',
                if (reason != null && reason.isNotEmpty) 'reason=$reason',
                if (sessionId != null && sessionId.isNotEmpty)
                  'session=$sessionId',
              ].join(' • '),
              style: GoogleFonts.raleway(
                color: const Color(0xFFF7EDE2).withValues(alpha: 0.82),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminAccessRequired extends StatelessWidget {
  const _AdminAccessRequired();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.pageHorizontalPadding),
        child: Text(
          'Admin access required.',
          style: GoogleFonts.raleway(
            color: const Color(0xFFF7EDE2),
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

int _timestampMillis(dynamic value) {
  if (value is Timestamp) return value.toDate().millisecondsSinceEpoch;
  if (value is DateTime) return value.millisecondsSinceEpoch;
  return 0;
}

String _formatTimestamp(dynamic value) {
  if (value is Timestamp) {
    final date = value.toDate();
    return '${date.toLocal()}'.split('.').first;
  }
  if (value is DateTime) {
    return '${value.toLocal()}'.split('.').first;
  }
  return 'unknown time';
}



