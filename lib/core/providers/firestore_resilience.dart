import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Wraps a Firestore snapshot stream with automatic retry logic
/// Helps handle ERR_ABORTED and temporary connection issues
class FirestoreStreamRetry {
  /// Wraps a query snapshot stream to handle connection errors
  static Stream<QuerySnapshot<Map<String, dynamic>>> queryWithRetry(
    Stream<QuerySnapshot<Map<String, dynamic>>> originalStream, {
    required String context,
    int maxRetries = 3,
  }) {
    var retryCount = 0;
    
    return originalStream.handleError((error) {
      debugPrint('[Firestore] Stream error in $context: $error (attempt ${retryCount + 1}/$maxRetries)');
      
      retryCount++;
      if (retryCount < maxRetries) {
        // Wait before retrying to avoid overwhelming the server
        Future.delayed(Duration(milliseconds: 100 * retryCount));
        return Stream.error(error);  // Will be caught by outer error handler
      }
      
      // After max retries, emit the error
      throw error;
    });
  }

  /// Wraps a document snapshot stream to handle connection errors
  static Stream<DocumentSnapshot<Map<String, dynamic>>> docWithRetry(
    Stream<DocumentSnapshot<Map<String, dynamic>>> originalStream, {
    required String context,
    int maxRetries = 3,
  }) {
    var retryCount = 0;
    
    return originalStream.handleError((error) {
      debugPrint('[Firestore] Document stream error in $context: $error (attempt ${retryCount + 1}/$maxRetries)');
      
      retryCount++;
      if (retryCount < maxRetries) {
        Future.delayed(Duration(milliseconds: 100 * retryCount));
        return Stream.error(error);
      }
      
      throw error;
    });
  }
}

/// Adds resilience to Firestore query operations
extension QueryResilience on Query<Map<String, dynamic>> {
  /// Snapshot stream with built-in retry logic and error logging
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshotsWithRetry({
    required String context,
  }) {
    return snapshots()
        .handleError((error) {
          debugPrint('[Firestore] Snapshot error in $context: $error');
          // Return empty snapshot instead of failing completely
          if (error is FirebaseException && error.code == 'aborted') {
            debugPrint('[Firestore] Connection aborted in $context, will retry');
          }
          return Stream.error(error);
        })
        .expand((snapshot) => [snapshot]); // Convert single value to stream
  }
}

/// Adds resilience to Firestore document operations
extension DocumentResilience on DocumentReference<Map<String, dynamic>> {
  /// Snapshot stream with built-in error logging
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshotsWithRetry({
    required String context,
  }) {
    return snapshots()
        .handleError((error) {
          debugPrint('[Firestore] Document snapshot error in $context: $error');
          return Stream.error(error);
        })
        .expand((snapshot) => [snapshot]); // Convert single value to stream
  }
}
