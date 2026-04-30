import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/posts/screens/post_comments_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

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

    testWidgets('submits a comment and leaves parent post counter untouched',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PostCommentsScreen(
              postId: 'post-1',
              auth: auth,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No comments yet'), findsOneWidget);
      expect(find.text('Be the first to comment.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'First comment');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pumpAndSettle();

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
