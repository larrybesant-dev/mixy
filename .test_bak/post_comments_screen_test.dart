import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/providers/firebase_providers.dart' as core_firebase;
import 'package:mixvy/core/streams/stream_lifecycle_manager.dart';
import 'package:mixvy/features/posts/screens/post_comments_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}
class _MockUser extends Mock implements User {}

/// Local fake to allow streams to flow regardless of route in tests.
class _FakeLifecycleManager extends ChangeNotifier implements StreamLifecycleManager {
  @override String get currentRoutePath => '/';
  @override void updateRoute(String routePath) {}
  @override bool isRouteActive(List<String> routePrefixes) => true;
  @override Stream<T> bind<T>({required String key, required Stream<T> Function() create, List<String> routePrefixes = const <String>[]}) => create();
  @override String buildDedupeKey({required String domain, String? userId, String? route, String? queryHash}) => '';
}

void main() {
  group('PostCommentsScreen', () {
    late FakeFirebaseFirestore firestore;
    late _MockFirebaseAuth auth;
    late _MockUser user;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      auth = _MockFirebaseAuth();
      user = _MockUser();

      when(() => user.uid).thenReturn('user-2');
      when(() => user.displayName).thenReturn('Commenter');
      when(() => user.photoURL).thenReturn(null);
      when(() => auth.currentUser).thenReturn(user);

      await firestore.collection('posts').doc('post-1').set({
        'authorId': 'author-1',
        'authorName': 'Author',
        'text': 'Original post',
        'createdAt': Timestamp.fromDate(DateTime(2026, 4, 9)),
        'commentCount': 0,
        'likeCount': 0,
        'likes': const <String>[],
      });
    });

    testWidgets('submits a comment and leaves parent post counter untouched', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            core_firebase.firestoreProvider.overrideWithValue(firestore),
            streamLifecycleManagerProvider.overrideWith((ref) => _FakeLifecycleManager()),
          ],
          child: MaterialApp(
            home: PostCommentsScreen(postId: 'post-1', auth: auth))));

      // Initial load: pump multiple times to handle stream setup and loading states
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'First comment');
      await tester.tap(find.byIcon(Icons.send));
      
      // Allow the async submit and the Firestore snapshot to propagate
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // Indeterminate progress indicators cause pumpAndSettle to timeout, 
      // so we use timed pumps or pump until the widget is found.
      int count = 0;
      while (find.text('First comment').evaluate().isEmpty && count < 10) {
        await tester.pump(const Duration(milliseconds: 100));
        count++;
      }

      expect(find.text('First comment'), findsOneWidget);

      final comments = await firestore
          .collection('posts')
          .doc('post-1')
          .collection('comments')
          .get();
      expect(comments.docs, hasLength(1));
      expect(comments.docs.first.data()['authorId'], 'user-2');
      expect(comments.docs.first.data()['authorName'], 'Commenter');

      final postSnap = await firestore.collection('posts').doc('post-1').get();
      expect(postSnap.data()?['commentCount'], 0);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text ?? '', isEmpty);
    });
  });
}










