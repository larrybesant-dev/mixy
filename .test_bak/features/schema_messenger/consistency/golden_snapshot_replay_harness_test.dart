import 'package:flutter_test/flutter_test.dart';

import 'package:mixvy/features/schema_messenger/consistency/consistency_template.dart';
import 'package:mixvy/features/schema_messenger/friends/parity/friend_parity_validator.dart';
import 'package:mixvy/features/schema_messenger/messages/messages_consistency_contract.dart';

class _ExpectedFriendParity {
  const _ExpectedFriendParity({
    required this.isComparable,
    required this.isMatch,
    required this.missingInSchema,
    required this.missingInLegacy,
    required this.statusMismatches,
  });

  final bool isComparable;
  final bool isMatch;
  final List<String> missingInSchema;
  final List<String> missingInLegacy;
  final List<String> statusMismatches;
}

class _ExpectedmessageParity {
  const _ExpectedmessageParity({
    required this.isComparable,
    required this.isMatch,
    required this.missingInSchema,
    required this.missingInLegacy,
    required this.unreadMismatches,
  });

  final bool isComparable;
  final bool isMatch;
  final List<String> missingInSchema;
  final List<String> missingInLegacy;
  final List<String> unreadMismatches;
}

class _GoldenSnapshotFrame {
  const _GoldenSnapshotFrame({
    required this.id,
    required this.friendSnapshot,
    required this.messageSnapshot,
    required this.expectedFriend,
    required this.expectedmessage,
  });

  final String id;
  final FriendParitySnapshot friendSnapshot;
  final MessageSnapshot messageSnapshot;
  final _ExpectedFriendParity expectedFriend;
  final _ExpectedmessageParity expectedmessage;
}

class _GateInput {
  const _GateInput({required this.id, required this.result});

  final String id;
  final _ParityResultAdapter result;
}

class _ParityResultAdapter implements ConsistencyParityResult {
  const _ParityResultAdapter({
    required this.isComparable,
    required this.isMatch,
    required this.signature,
  });

  @override
  final bool isComparable;

  @override
  final bool isMatch;

  @override
  final String signature;

  factory _ParityResultAdapter.fromFriend(FriendParityResult result) {
    return _ParityResultAdapter(
      isComparable: result.isComparable,
      isMatch: result.isMatch,
      signature: result.paritySignature,
    );
  }

  factory _ParityResultAdapter.frommessage(MessageParityResult result) {
    return _ParityResultAdapter(
      isComparable: result.isComparable,
      isMatch: result.isMatch,
      signature: result.signature,
    );
  }
}

void main() {
  group('golden snapshot replay harness', () {
    test('deterministic parity outputs for canonical golden dataset', () {
      const contract = MessageConsistencyContract();

      final frames = <_GoldenSnapshotFrame>[
        _GoldenSnapshotFrame(
          id: 'cold_load',
          friendSnapshot: FriendParitySnapshot(
            legacyIdsOrdered: <String>[],
            schemaIdsOrdered: <String>[],
            legacyOnlineIds: <String>{},
            schemaOnlineIds: <String>{},
            legacyReady: false,
            schemaReady: false,
            schemaPresenceReady: false,
          ),
          messageSnapshot: MessageSnapshot(
            legacyConversationIds: <String>[],
            schemaConversationIds: <String>[],
            legacyUnreadByConversation: <String, int>{},
            schemaUnreadByConversation: <String, int>{},
            legacyReady: false,
            schemaReady: false,
          ),
          expectedFriend: _ExpectedFriendParity(
            isComparable: false,
            isMatch: true,
            missingInSchema: <String>[],
            missingInLegacy: <String>[],
            statusMismatches: <String>[],
          ),
          expectedmessage: _ExpectedmessageParity(
            isComparable: false,
            isMatch: true,
            missingInSchema: <String>[],
            missingInLegacy: <String>[],
            unreadMismatches: <String>[],
          ),
        ),
        _GoldenSnapshotFrame(
          id: 'stable_mismatch',
          friendSnapshot: FriendParitySnapshot(
            legacyIdsOrdered: <String>['u_a', 'u_b', 'u_c'],
            schemaIdsOrdered: <String>['u_a', 'u_c', 'u_d'],
            legacyOnlineIds: <String>{'u_a', 'u_c'},
            schemaOnlineIds: <String>{'u_a'},
            legacyReady: true,
            schemaReady: true,
            schemaPresenceReady: true,
          ),
          messageSnapshot: MessageSnapshot(
            legacyConversationIds: <String>['c_1', 'c_2', 'c_3'],
            schemaConversationIds: <String>['c_1', 'c_3', 'c_4'],
            legacyUnreadByConversation: <String, int>{
              'c_1': 1,
              'c_2': 0,
              'c_3': 1,
            },
            schemaUnreadByConversation: <String, int>{
              'c_1': 1,
              'c_3': 0,
              'c_4': 0,
            },
            legacyReady: true,
            schemaReady: true,
          ),
          expectedFriend: _ExpectedFriendParity(
            isComparable: true,
            isMatch: false,
            missingInSchema: <String>['u_b'],
            missingInLegacy: <String>['u_d'],
            statusMismatches: <String>['u_c'],
          ),
          expectedmessage: _ExpectedmessageParity(
            isComparable: true,
            isMatch: false,
            missingInSchema: <String>['c_2'],
            missingInLegacy: <String>['c_4'],
            unreadMismatches: <String>['c_3'],
          ),
        ),
        _GoldenSnapshotFrame(
          id: 'fully_restored',
          friendSnapshot: FriendParitySnapshot(
            legacyIdsOrdered: <String>['u_a', 'u_b'],
            schemaIdsOrdered: <String>['u_a', 'u_b'],
            legacyOnlineIds: <String>{'u_b'},
            schemaOnlineIds: <String>{'u_b'},
            legacyReady: true,
            schemaReady: true,
            schemaPresenceReady: true,
          ),
          messageSnapshot: MessageSnapshot(
            legacyConversationIds: <String>['c_1', 'c_2'],
            schemaConversationIds: <String>['c_1', 'c_2'],
            legacyUnreadByConversation: <String, int>{'c_1': 0, 'c_2': 1},
            schemaUnreadByConversation: <String, int>{'c_1': 0, 'c_2': 1},
            legacyReady: true,
            schemaReady: true,
          ),
          expectedFriend: _ExpectedFriendParity(
            isComparable: true,
            isMatch: true,
            missingInSchema: <String>[],
            missingInLegacy: <String>[],
            statusMismatches: <String>[],
          ),
          expectedmessage: _ExpectedmessageParity(
            isComparable: true,
            isMatch: true,
            missingInSchema: <String>[],
            missingInLegacy: <String>[],
            unreadMismatches: <String>[],
          ),
        ),
      ];

      for (final frame in frames) {
        final friendResult = evaluateFriendParity(frame.friendSnapshot);
        final messageResult = contract.evaluate(frame.messageSnapshot);

        expect(
          friendResult.isComparable,
          frame.expectedFriend.isComparable,
          reason: '${frame.id} friend comparability mismatch',
        );
        expect(
          friendResult.isMatch,
          frame.expectedFriend.isMatch,
          reason: '${frame.id} friend parity mismatch',
        );
        expect(
          friendResult.missingInSchema,
          frame.expectedFriend.missingInSchema,
          reason: '${frame.id} friend missingInSchema mismatch',
        );
        expect(
          friendResult.missingInLegacy,
          frame.expectedFriend.missingInLegacy,
          reason: '${frame.id} friend missingInLegacy mismatch',
        );
        expect(
          friendResult.statusMismatches,
          frame.expectedFriend.statusMismatches,
          reason: '${frame.id} friend status mismatch',
        );

        expect(
          messageResult.isComparable,
          frame.expectedmessage.isComparable,
          reason: '${frame.id} message comparability mismatch',
        );
        expect(
          messageResult.isMatch,
          frame.expectedmessage.isMatch,
          reason: '${frame.id} message parity mismatch',
        );
        expect(
          messageResult.missingInSchema,
          frame.expectedmessage.missingInSchema,
          reason: '${frame.id} message missingInSchema mismatch',
        );
        expect(
          messageResult.missingInLegacy,
          frame.expectedmessage.missingInLegacy,
          reason: '${frame.id} message missingInLegacy mismatch',
        );
        expect(
          messageResult.unreadMismatches,
          frame.expectedmessage.unreadMismatches,
          reason: '${frame.id} message unread mismatch',
        );
      }
    });

    test(
      'drift replay gate suppresses cold-load noise and emits only stable signals',
      () {
        const contract = MessageConsistencyContract();

        final replay = <_GateInput>[
          _GateInput(
            id: 'loading-1',
            result: _ParityResultAdapter.frommessage(
              contract.evaluate(
                MessageSnapshot(
                  legacyConversationIds: <String>[],
                  schemaConversationIds: <String>[],
                  legacyUnreadByConversation: <String, int>{},
                  schemaUnreadByConversation: <String, int>{},
                  legacyReady: false,
                  schemaReady: false,
                ),
              ),
            ),
          ),
          _GateInput(
            id: 'loading-2',
            result: _ParityResultAdapter.frommessage(
              contract.evaluate(
                MessageSnapshot(
                  legacyConversationIds: <String>[],
                  schemaConversationIds: <String>[],
                  legacyUnreadByConversation: <String, int>{},
                  schemaUnreadByConversation: <String, int>{},
                  legacyReady: false,
                  schemaReady: false,
                ),
              ),
            ),
          ),
          _GateInput(
            id: 'mismatch-1',
            result: _ParityResultAdapter.frommessage(
              contract.evaluate(
                MessageSnapshot(
                  legacyConversationIds: <String>['c_1', 'c_2'],
                  schemaConversationIds: <String>['c_1'],
                  legacyUnreadByConversation: <String, int>{'c_1': 1, 'c_2': 0},
                  schemaUnreadByConversation: <String, int>{'c_1': 0},
                  legacyReady: true,
                  schemaReady: true,
                ),
              ),
            ),
          ),
          _GateInput(
            id: 'mismatch-2-stable',
            result: _ParityResultAdapter.frommessage(
              contract.evaluate(
                MessageSnapshot(
                  legacyConversationIds: <String>['c_1', 'c_2'],
                  schemaConversationIds: <String>['c_1'],
                  legacyUnreadByConversation: <String, int>{'c_1': 1, 'c_2': 0},
                  schemaUnreadByConversation: <String, int>{'c_1': 0},
                  legacyReady: true,
                  schemaReady: true,
                ),
              ),
            ),
          ),
          _GateInput(
            id: 'restored',
            result: _ParityResultAdapter.frommessage(
              contract.evaluate(
                MessageSnapshot(
                  legacyConversationIds: <String>['c_1', 'c_2'],
                  schemaConversationIds: <String>['c_1', 'c_2'],
                  legacyUnreadByConversation: <String, int>{'c_1': 1, 'c_2': 0},
                  schemaUnreadByConversation: <String, int>{'c_1': 1, 'c_2': 0},
                  legacyReady: true,
                  schemaReady: true,
                ),
              ),
            ),
          ),
        ];

        var state = ConsistencyGateState.empty;
        var reactiveMismatchEmits = 0;
        var restoreEmits = 0;

        for (final step in replay) {
          final decision = evaluateConsistencyGate<_ParityResultAdapter>(
            result: step.result,
            state: state,
            stableMismatchThreshold: 2,
            isPeriodicReconcile: false,
          );
          state = decision.nextState;

          if (decision.emitReactiveMismatch) {
            reactiveMismatchEmits += 1;
          }
          if (decision.emitRestore) {
            restoreEmits += 1;
          }
        }

        expect(
          reactiveMismatchEmits,
          1,
          reason: 'Only one stable mismatch emission is allowed.',
        );
        expect(
          restoreEmits,
          1,
          reason: 'A single restore emission should follow recovery.',
        );
      },
    );

    test('friend replay is compatible with shared gate semantics', () {
      final sequence = <_ParityResultAdapter>[
        _ParityResultAdapter.fromFriend(
          evaluateFriendParity(
            const FriendParitySnapshot(
              legacyIdsOrdered: <String>[],
              schemaIdsOrdered: <String>[],
              legacyOnlineIds: <String>{},
              schemaOnlineIds: <String>{},
              legacyReady: false,
              schemaReady: false,
              schemaPresenceReady: false,
            ),
          ),
        ),
        _ParityResultAdapter.fromFriend(
          evaluateFriendParity(
            const FriendParitySnapshot(
              legacyIdsOrdered: <String>['u_1', 'u_2'],
              schemaIdsOrdered: <String>['u_1'],
              legacyOnlineIds: <String>{'u_2'},
              schemaOnlineIds: <String>{},
              legacyReady: true,
              schemaReady: true,
              schemaPresenceReady: true,
            ),
          ),
        ),
        _ParityResultAdapter.fromFriend(
          evaluateFriendParity(
            const FriendParitySnapshot(
              legacyIdsOrdered: <String>['u_1', 'u_2'],
              schemaIdsOrdered: <String>['u_1'],
              legacyOnlineIds: <String>{'u_2'},
              schemaOnlineIds: <String>{},
              legacyReady: true,
              schemaReady: true,
              schemaPresenceReady: true,
            ),
          ),
        ),
      ];

      var state = ConsistencyGateState.empty;
      var mismatchEmits = 0;

      for (final result in sequence) {
        final decision = evaluateConsistencyGate<_ParityResultAdapter>(
          result: result,
          state: state,
          stableMismatchThreshold: 2,
          isPeriodicReconcile: false,
        );
        state = decision.nextState;
        if (decision.emitReactiveMismatch) {
          mismatchEmits += 1;
        }
      }

      expect(
        mismatchEmits,
        1,
        reason:
            'Friends parity remains compatible with canonical gate semantics.',
      );
    });
  });
}



