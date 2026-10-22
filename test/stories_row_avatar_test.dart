import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/stories/providers/story_provider.dart';
import 'package:mixvy/features/stories/widgets/stories_row.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';

const _uid = 'viewer-uid';

Widget _buildRow(UserModel? me) {
  return ProviderScope(
    overrides: [
      userProvider.overrideWith((ref) => me),
      followingIdsProvider.overrideWith(
        (ref, userId) => Stream.value(const <String>[]),
      ),
      followingStoriesProvider.overrideWith(
        (ref, params) => Stream.value(const <Story>[]),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(body: StoriesRow()),
    ),
  );
}

UserModel _user({String? avatarUrl}) => UserModel(
  id: _uid,
  email: 'viewer@example.com',
  username: 'viewer',
  avatarUrl: avatarUrl,
  createdAt: DateTime(2024),
);

void main() {
  testWidgets('own story bubble uses the signed-in user avatar when no story exists',
      (tester) async {
    await tester.pumpWidget(
      _buildRow(_user(avatarUrl: 'https://example.com/me.jpg')),
    );
    await tester.pump();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://example.com/me.jpg');
    expect(find.text('Your Story'), findsOneWidget);
  });

  testWidgets('own story bubble shows the default icon when the user has no avatar',
      (tester) async {
    await tester.pumpWidget(_buildRow(_user()));
    await tester.pump();

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
