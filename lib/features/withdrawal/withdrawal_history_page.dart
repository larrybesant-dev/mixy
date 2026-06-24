import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/shared/providers/auth_providers.dart';

class WithdrawalHistoryPage extends ConsumerWidget {
  const WithdrawalHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ðŸ”¥ Use Riverpod authStateProvider for reactive auth
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    // Handle auth loading state
    if (authState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Withdrawal History')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Handle unauthenticated state
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Withdrawal History')),
        body: const Center(child: Text('Not authenticated')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdrawal History'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('withdrawals')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No withdrawal history'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final status = data['status'] as String? ?? 'pending';
              final amount = data['amount'] as int? ?? 0;
              final email = data['email'] as String? ?? '';
              final createdAt = data['createdAt'] as Timestamp?;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    status == 'completed'
                        ? Icons.check_circle
                        : status == 'rejected'
                            ? Icons.cancel
                            : Icons.pending,
                    color: status == 'completed'
                        ? Colors.green
                        : status == 'rejected'
                            ? Colors.red
                            : Colors.orange,
                  ),
                  title: Text('\$$amount'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email: $email'),
                      Text('Status: ${status.toUpperCase()}'),
                      if (createdAt != null)
                        Text(
                            'Date: ${createdAt.toDate().toString().substring(0, 10)}'),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

