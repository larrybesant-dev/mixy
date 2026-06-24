// lib/features/control_center/providers/control_center_providers.dart
//
// Riverpod providers for the Platform Control Center.
// Access control is enforced by Firestore rules and the superadmin custom claim.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/services/role_service.dart';
import 'package:mixvy/features/control_center/services/audit_log_service.dart';
import 'package:mixvy/services/events/reporting_service.dart';

// ── Role guards ───────────────────────────────────────────────────────────────

/// True when the current user has at least the `admin` role.
final isAdminProvider = StreamProvider.autoDispose<bool>((ref) {
  return RoleService().currentUserRoleStream().map(
        (role) => role == UserRole.admin || role == UserRole.superadmin,
      );
});

/// True when the current user has the `superadmin` role.
final isSuperAdminProvider = StreamProvider.autoDispose<bool>((ref) {
  return RoleService()
      .currentUserRoleStream()
      .map((role) => role == UserRole.superadmin);
});

// ── Users management ─────────────────────────────────────────────────────────

final _firestore = FirebaseFirestore.instance;

/// Streams all user documents ordered by join date (newest first).
final allUsersProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return _firestore
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList());
});

// ── Rooms management ─────────────────────────────────────────────────────────

/// Streams all currently live room documents.
final allLiveRoomsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return _firestore
      .collection('rooms')
      .where('isLive', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList());
});

// ── Reports management ───────────────────────────────────────────────────────

/// Streams all pending (unresolved) reports.
final pendingReportsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return _firestore
      .collection('reports')
      .where('status', isEqualTo: ReportStatus.pending.name)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList());
});

// ── Audit log ────────────────────────────────────────────────────────────────

/// Streams the 50 most recent audit log entries.
final auditLogProvider =
    StreamProvider.autoDispose<List<AuditLogEntry>>((ref) {
  return AuditLogService.instance.watchRecentActions();
});

// ── Analytics ────────────────────────────────────────────────────────────────

/// Streams the platform analytics summary document.
final platformAnalyticsProvider =
    StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  return _firestore
      .collection('analytics')
      .doc('summary')
      .snapshots()
      .map((doc) =>
          doc.exists ? (doc.data() ?? {}) : <String, dynamic>{});
});

