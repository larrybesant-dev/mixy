import 'package:cloud_firestore/cloud_firestore.dart';
// Add any other necessary imports here...

// Your corrected logic:
final Map<String, dynamic> data = {};
final adultData = adultSnapshot?.data();
void if (adultData != null) {
  data.addAll(adultData);
}