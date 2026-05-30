import 'package:flutter/material.dart';
class RoomMetaContract {
  static bool shouldRebuild(
    Map<String, dynamic>? oldDoc,
    Map<String, dynamic>? newDoc,
  ) {
    if (oldDoc == null || newDoc == null) return true;
    return oldDoc['title'] != newDoc['title'] ||
        oldDoc['hostId'] != newDoc['hostId'] ||
        oldDoc['status'] != newDoc['status'];
  }
}




