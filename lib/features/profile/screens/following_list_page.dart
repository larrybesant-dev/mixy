// lib/features/profile/screens/following_list_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FollowingListPage extends StatelessWidget {
  final String userId;
  const FollowingListPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final uid = userId.isNotEmpty
        ? userId
        : FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No data found.'));
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final following = List<String>.from(data['following'] ?? []);
          if (following.isEmpty) {
            return const Center(child: Text('Not following anyone yet.'));
          }
          return ListView.builder(
            itemCount: following.length,
            itemBuilder: (context, index) {
              final followedId = following[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(followedId)
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const ListTile(title: Text('Loading...'));
                  }
                  final user = userSnap.data!.data() as Map<String, dynamic>?;
                  final name =
                      user?['displayName'] ?? user?['username'] ?? followedId;
                  final avatar = user?['photoURL'] as String?;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          avatar != null ? NetworkImage(avatar) : null,
                      child: avatar == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(name.toString()),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
