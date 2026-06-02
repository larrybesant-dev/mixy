import 'package:flutter/material.dart';

import '../../schema_messenger/friends/views/friends_schema_bridge_view.dart';

class FriendListScreen extends StatelessWidget {
  const FriendListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: _FriendsAppBar(),
      body: FriendsSchemaBridgeView(),
    );
  }
}

class _FriendsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _FriendsAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('Friends'));
  }
}
