import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/room/services/room_analytics_service.dart';

/// Analytics & Statistics Dashboard Widget
///
/// Features:
/// - Room statistics overview
/// - Top users by engagement
/// - Recent activity feed
/// - Usage trends
class AnalyticsDashboardWidget extends ConsumerWidget {
  final String roomId;
  final VoidCallback? onClose;

  const AnalyticsDashboardWidget({
    super.key,
    required this.roomId,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(roomStatisticsProvider(roomId));
    final topUsersAsync = ref.watch(topUsersInRoomProvider(roomId));
    final activityAsync = ref.watch(recentActivityProvider(roomId));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics, color: Color(0xFFFF4C4C), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Analytics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onClose,
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Room Statistics Overview
            statsAsync.when(
              data: (stats) {
                if (stats == null) {
                  return const SizedBox.shrink();
                }
                return _buildStatisticsSection(stats);
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFFFF4C4C),
                  ),
                ),
              ),
              error: (error, __) => Text(
                'Error loading statistics',
                style: TextStyle(color: Colors.red[300]),
              ),
            ),
            const SizedBox(height: 24),

            // Top Users Section
            const Text(
              'Top Users by Engagement',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            topUsersAsync.when(
              data: (users) {
                if (users.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No user engagement data yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  );
                }

                return Column(
                  children: users.asMap().entries.map((entry) {
                    final index = entry.key;
                    final user = entry.value;
                    return _buildUserEngagementTile(index + 1, user);
                  }).toList(),
                );
              },
              loading: () => const SizedBox(
                height: 40,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF4C4C),
                      ),
                    ),
                  ),
                ),
              ),
              error: (error, __) => Text(
                'Error loading users',
                style: TextStyle(color: Colors.red[300], fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Recent Activity Section
            const Text(
              'Recent Activity',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            activityAsync.when(
              data: (activities) {
                if (activities.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No recent activity',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  );
                }

                return Column(
                  children: activities
                      .take(10)
                      .map((activity) => _buildActivityItem(activity))
                      .toList(),
                );
              },
              loading: () => const SizedBox(
                height: 40,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF4C4C),
                      ),
                    ),
                  ),
                ),
              ),
              error: (error, __) => Text(
                'Error loading activity',
                style: TextStyle(color: Colors.red[300], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(RoomStatistics stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Room Overview',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStatCard(
              'Total Visitors',
              stats.totalVisitors.toString(),
              Icons.people,
            ),
            _buildStatCard(
              'Peak Users',
              stats.peakConcurrentUsers.toString(),
              Icons.trending_up,
            ),
            _buildStatCard(
              'Total Messages',
              stats.totalMessagesCount.toString(),
              Icons.chat,
            ),
            _buildStatCard(
              'Recordings',
              stats.totalRecordingsCount.toString(),
              Icons.videocam,
            ),
            _buildStatCard(
              'Avg Session',
              _formatDuration(stats.averageSessionDuration),
              Icons.timer,
            ),
            _buildStatCard(
              'Rating',
              '${stats.averageUserRating.toStringAsFixed(1)}â­',
              Icons.star,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFF4C4C).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFFF4C4C), size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFF4C4C),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserEngagementTile(int rank, UserEngagement user) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFFF4C4C),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${user.totalSessions} sessions â€¢ ${_formatDuration(user.totalTimeInRoom)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4C4C).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${user.userRating.toStringAsFixed(1)}â­',
                style: const TextStyle(
                  color: Color(0xFFFF4C4C),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final type = activity['type'] as String?;
    final timestamp = activity['timestamp'] as DateTime?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              _getActivityIcon(type),
              color: _getActivityColor(type),
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _getActivityText(type),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              timestamp != null ? _formatActivityTime(timestamp) : '---',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon(String? type) {
    switch (type) {
      case 'user_join':
        return Icons.login;
      case 'user_leave':
        return Icons.logout;
      case 'message_sent':
        return Icons.chat;
      case 'recording_created':
        return Icons.videocam;
      default:
        return Icons.info;
    }
  }

  Color _getActivityColor(String? type) {
    switch (type) {
      case 'user_join':
        return Colors.green;
      case 'user_leave':
        return Colors.orange;
      case 'message_sent':
        return Colors.blue;
      case 'recording_created':
        return const Color(0xFFFF4C4C);
      default:
        return Colors.grey;
    }
  }

  String _getActivityText(String? type) {
    switch (type) {
      case 'user_join':
        return 'User joined';
      case 'user_leave':
        return 'User left';
      case 'message_sent':
        return 'Message sent';
      case 'recording_created':
        return 'Recording created';
      default:
        return 'Activity';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _formatActivityTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

