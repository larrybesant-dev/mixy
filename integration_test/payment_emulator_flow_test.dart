import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mixvy/firebase_options.dart';
import 'package:mixvy/services/payment_api.dart';

const bool runEmulatorTests = bool.fromEnvironment(
  'RUN_FIREBASE_EMULATOR_TESTS',
  defaultValue: false,
);
const String emulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: 'localhost',
);
const int authPort = int.fromEnvironment(
  'FIREBASE_AUTH_EMULATOR_PORT',
  defaultValue: 9099,
);
const int firestorePort = int.fromEnvironment(
  'FIRESTORE_EMULATOR_PORT',
  defaultValue: 8080,
);
const int functionsPort = int.fromEnvironment(
  'FUNCTIONS_EMULATOR_PORT',
  defaultValue: 5001,
);

Future<void> _initializeFirebaseForEmulators() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  try {
    Firebase.app();
  } on FirebaseException {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, authPort);
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, firestorePort);
  FirebaseFunctions.instance.useFunctionsEmulator(emulatorHost, functionsPort);
}

Future<UserCredential> _createAndSeedUser({
  required String label,
  required double balance,
}) async {
  final email =
      'payment-$label-${DateTime.now().microsecondsSinceEpoch}@mixvy.dev';
  final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: 'P@ssword123!',
  );
  final uid = credential.user!.uid;
  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'uid': uid,
    'balance': balance,
    'email': email,
  }, SetOptions(merge: true));
  return credential;
}

Future<Map<String, dynamic>> _userDoc(String uid) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();
  return snapshot.data() ?? <String, dynamic>{};
}

void main() {
  setUpAll(() async {
    if (runEmulatorTests) {
      await _initializeFirebaseForEmulators();
    }
  });

  tearDown(() async {
    if (runEmulatorTests) {
      await FirebaseAuth.instance.signOut();
    }
  });

  testWidgets(
    'sendPayment updates balances and records a sent transaction via emulator',
    (tester) async {
      final sender = await _createAndSeedUser(label: 'sender', balance: 25);
      final senderId = sender.user!.uid;
      await FirebaseAuth.instance.signOut();

      final receiver = await _createAndSeedUser(label: 'receiver', balance: 4);
      final receiverId = receiver.user!.uid;
      await FirebaseAuth.instance.signOut();

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: sender.user!.email!,
        password: 'P@ssword123!',
      );

      await PaymentApi.sendPayment(receiverId, 5);

      final senderDoc = await _userDoc(senderId);
      final receiverDoc = await _userDoc(receiverId);
      expect(senderDoc['balance'], 20);
      expect(receiverDoc['balance'], 9);

      final transactions = await FirebaseFirestore.instance
          .collection('transactions')
          .where('senderId', isEqualTo: senderId)
          .get();
      expect(
        transactions.docs.any((doc) => doc.data()['status'] == 'sent'),
        isTrue,
      );
    },
    skip: !runEmulatorTests,
  );

  testWidgets(
    'requestPayment records a requested transaction via emulator',
    (tester) async {
      final requester = await _createAndSeedUser(
        label: 'requester',
        balance: 10,
      );
      final requesterId = requester.user!.uid;
      await FirebaseAuth.instance.signOut();

      final target = await _createAndSeedUser(label: 'target', balance: 3);
      final targetId = target.user!.uid;
      await FirebaseAuth.instance.signOut();

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: requester.user!.email!,
        password: 'P@ssword123!',
      );

      await PaymentApi.requestPayment(requesterId, targetId, 7);

      final transactions = await FirebaseFirestore.instance
          .collection('transactions')
          .where('senderId', isEqualTo: requesterId)
          .get();
      expect(
        transactions.docs.any(
          (doc) =>
              doc.data()['receiverId'] == targetId &&
              doc.data()['status'] == 'requested',
        ),
        isTrue,
      );
    },
    skip: !runEmulatorTests,
  );

  testWidgets(
    'notifySuccess records a completed transaction via emulator',
    (tester) async {
      final sender = await _createAndSeedUser(
        label: 'stripe-sender',
        balance: 50,
      );
      await FirebaseAuth.instance.signOut();

      final receiver = await _createAndSeedUser(
        label: 'stripe-receiver',
        balance: 2,
      );
      final receiverId = receiver.user!.uid;
      await FirebaseAuth.instance.signOut();

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: sender.user!.email!,
        password: 'P@ssword123!',
      );

      await PaymentApi.notifySuccess(
        recipientId: receiverId,
        amount: 11,
        paymentIntentId: 'pi_emulator_test',
      );

      final transactions = await FirebaseFirestore.instance
          .collection('transactions')
          .where('senderId', isEqualTo: sender.user!.uid)
          .get();
      expect(
        transactions.docs.any(
          (doc) =>
              doc.data()['receiverId'] == receiverId &&
              doc.data()['status'] == 'completed',
        ),
        isTrue,
      );
    },
    skip: !runEmulatorTests,
  );
}
