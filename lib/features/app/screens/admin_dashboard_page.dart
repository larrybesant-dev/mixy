import 'package:flutter/material.dart';
import 'package:mixmingle/shared/widgets/club_background.dart';
import 'package:mixmingle/shared/widgets/neon_button.dart';
import 'package:mixmingle/services/infra/firestore_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final FirestoreService _firestoreService = FirestoreService();
  int _userCount = 0;
  int _flaggedMessagesCount = 0;
  int _reportsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    // Get user count
    final users = await _firestoreService.getAllUsers();
    // Get flagged messages count
    final flaggedMessages = await _firestoreService.getFlaggedMessages();
    // Get reports count
    final reports = await _firestoreService.getUserReports();

    if (mounted) {
      setState(() {
        _userCount = users.length;
        _flaggedMessagesCount = flaggedMessages.length;
        _reportsCount = reports.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF1a1a2e),
      ),
      body: ClubBackground(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildStatCard(
                      'Total Users', _userCount.toString(), Colors.blue),
                  const SizedBox(width: 16),
                  _buildStatCard('Flagged Messages',
                      _flaggedMessagesCount.toString(), Colors.orange),
                  const SizedBox(width: 16),
                  _buildStatCard(
                      'User Reports', _reportsCount.toString(), Colors.red),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Moderation Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              NeonButton(
                  label: 'Review Flagged Messages',
                  onPressed: () {
                    // Navigate to flagged messages
                    Navigator.of(context).pushNamed('/admin/flagged-messages');
                  }),
              const SizedBox(height: 12),
              NeonButton(
                  label: 'Review User Reports',
                  onPressed: () {
                    // Navigate to user reports
                    Navigator.of(context).pushNamed('/admin/user-reports');
                  }),
              const SizedBox(height: 12),
              NeonButton(
                  label: 'Manage Users',
                  onPressed: () {
                    // Navigate to user management
                    Navigator.of(context).pushNamed('/admin/users');
                  }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: const Color(0xFF16213e),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
