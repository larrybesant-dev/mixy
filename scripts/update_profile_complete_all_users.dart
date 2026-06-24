import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;
  final users = await firestore.collection('users').get();
  for (final doc in users.docs) {
    await firestore.collection('users').doc(doc.id).update({'profileComplete': true});
  }
}
