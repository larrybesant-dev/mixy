import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/core/pagination/pagination_controller.dart';
import 'package:mixvy/shared/models/event.dart';
import 'package:mixvy/shared/widgets/paginated_list_view.dart';

/// Example implementation of paginated events page
class EventsListPaginatedPage extends ConsumerStatefulWidget {
  const EventsListPaginatedPage({super.key});

  @override
  ConsumerState<EventsListPaginatedPage> createState() =>
      _EventsListPaginatedPageState();
}

class _EventsListPaginatedPageState
    extends ConsumerState<EventsListPaginatedPage> {
  late PaginationController<Event> _controller;

  @override
  void initState() {
    super.initState();

    // Initialize pagination controller with Firestore fetch
    _controller = PaginationController<Event>(
      pageSize: 30,
      queryBuilder: () {
        return FirebaseFirestore.instance
            .collection('events')
            .where('startTime', isGreaterThan: DateTime.now())
            .orderBy('startTime', descending: false);
      },
      fromDocument: (doc) => Event.fromMap(doc.data() as Map<String, dynamic>),
    );

    // Load initial page
    _controller.loadInitial();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              // Show calendar view
            },
          ),
        ],
      ),
      body: PaginatedListView<Event>(
        controller: _controller,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, event, index) {
          return _EventCard(event: event);
        },
        emptyWidget: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No upcoming events',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Navigate to event details
          // Navigator.pushNamed(context, '/event/${event.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event title
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),

              // Event date/time
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    _formatDateTime(event.startTime),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),

              ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 16, color: Colors.white70),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.location,
                        style: const TextStyle(color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Participants count
              if (event.attendees.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.people, size: 16, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      '${event.attendees.length} attendees',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays == 0) {
      return 'Today at ${_formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow at ${_formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${_getDayName(dateTime.weekday)} at ${_formatTime(dateTime)}';
    } else {
      return '${dateTime.month}/${dateTime.day} at ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}

