import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mixmingle/shared/models/event.dart';
import 'package:mixmingle/shared/providers/events_controller.dart'
    hide eventProvider;
import 'package:mixmingle/shared/providers/event_dating_providers.dart'
    hide eventsServiceProvider, attendingEventsProvider;
import 'package:mixmingle/shared/widgets/club_background.dart';
import 'package:mixmingle/shared/widgets/async_value_view_enhanced.dart';
import 'package:mixmingle/shared/widgets/skeleton_loaders.dart';
import 'event_details_page.dart';
import 'create_event_page.dart';

class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({super.key});

  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Events'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'All Events'),
              Tab(text: 'My Events'),
              Tab(text: 'Attending'),
            ],
          ),
          actions: [
            Semantics(
              label: 'Search Events',
              button: true,
              child: IconButton(
                key: const Key('searchEventsButton'),
                icon: const Icon(Icons.search),
                onPressed: () => _showSearchDialog(context),
              ),
            ),
            Semantics(
              label: 'Filter Events',
              button: true,
              child: IconButton(
                key: const Key('filterEventsButton'),
                icon: const Icon(Icons.filter_list),
                onPressed: () => _showFilterDialog(context),
              ),
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAllEventsTab(),
            _buildMyEventsTab(),
            _buildAttendingEventsTab(),
          ],
        ),
        floatingActionButton: Semantics(
          label: 'Create Event',
          button: true,
          child: FloatingActionButton(
            key: const Key('createEventButton'),
            onPressed: () => _navigateToCreateEvent(context),
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  Widget _buildAllEventsTab() {
    final eventsAsync = ref.watch(allEventsProvider);
    final filteredEvents = ref.watch(filteredEventsProvider);

    return AsyncValueViewEnhanced<List<Event>>(
      value: eventsAsync,
      maxRetries: 3,
      skeleton: const SkeletonGrid(itemCount: 4, crossAxisCount: 2),
      screenName: 'EventsPage',
      providerName: 'allEventsProvider',
      onRetry: () => ref.invalidate(allEventsProvider),
      data: (events) => filteredEvents.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No events match your filters',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Try adjusting your filters',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredEvents.length,
              itemBuilder: (context, index) {
                final event = filteredEvents[index];
                return EventCard(
                  event: event,
                  onTap: () => _navigateToEventDetails(context, event),
                );
              },
            ),
    );
  }

  Widget _buildMyEventsTab() {
    final eventsAsync = ref.watch(myEventsProvider);

    return AsyncValueViewEnhanced(
      value: eventsAsync,
      maxRetries: 3,
      skeleton: const SkeletonList(itemCount: 4),
      screenName: 'EventsPage',
      providerName: 'myEventsProvider',
      onRetry: () => ref.invalidate(myEventsProvider),
      data: (events) => events.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'You haven\'t created any events yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to create your first event!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(myEventsProvider),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return EventCard(
                    event: event,
                    onTap: () => _navigateToEventDetails(context, event),
                    showEditButton: true,
                  );
                },
              ),
            ),
    );
  }

  Widget _buildAttendingEventsTab() {
    final eventsAsync = ref.watch(attendingEventsProvider);

    return AsyncValueViewEnhanced(
      value: eventsAsync,
      maxRetries: 3,
      skeleton: const SkeletonList(itemCount: 4),
      screenName: 'EventsPage',
      providerName: 'attendingEventsProvider',
      onRetry: () => ref.invalidate(attendingEventsProvider),
      data: (Object? eventsObj) {
        final events = eventsObj as List<Event>?;
        return (events == null || events.isEmpty)
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'You\'re not attending any events',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Browse events to find something interesting!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(attendingEventsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return EventCard(
                      event: event,
                      onTap: () => _navigateToEventDetails(context, event),
                    );
                  },
                ),
              );
      },
    );
  }

  void _navigateToEventDetails(BuildContext context, Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsPage(eventId: event.id),
      ),
    );
  }

  void _navigateToCreateEvent(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateEventPage(),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const EventSearchDialog(),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const EventFilterDialog(),
    );
  }
}

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  final bool showEditButton;

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.showEditButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isPast = event.endTime.isBefore(now);
    final isOngoing =
        event.startTime.isBefore(now) && event.endTime.isAfter(now);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (showEditButton)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.pushNamed(context, '/events/create');
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                event.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${DateFormat('MMM dd, HH:mm').format(event.startTime)} - ${DateFormat('HH:mm').format(event.endTime)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(isPast, isOngoing),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(isPast, isOngoing),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${event.attendees.length}/${event.maxCapacity} attending',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(bool isPast, bool isOngoing) {
    if (isPast) return Colors.grey;
    if (isOngoing) return Colors.green;
    return Colors.blue;
  }

  String _getStatusText(bool isPast, bool isOngoing) {
    if (isPast) return 'Past';
    if (isOngoing) return 'Ongoing';
    return 'Upcoming';
  }
}

class EventSearchDialog extends ConsumerStatefulWidget {
  const EventSearchDialog({super.key});

  @override
  ConsumerState<EventSearchDialog> createState() => _EventSearchDialogState();
}

class _EventSearchDialogState extends ConsumerState<EventSearchDialog> {
  final _searchController = TextEditingController();
  final List<String> _categories = [
    'Social',
    'Networking',
    'Sports',
    'Music',
    'Food',
    'Art',
    'Technology'
  ];
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    final currentSearch = ref.read(eventSearchProvider);
    _searchController.text = currentSearch.query;
    _selectedCategory = currentSearch.category;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search Events'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search by title or description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All Categories'),
              ),
              ..._categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }),
            ],
            onChanged: (value) => setState(() => _selectedCategory = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Clear search
            final searchNotifier = ref.read(eventSearchProvider.notifier);
            searchNotifier.clearSearch();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Search cleared')),
            );
          },
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Apply search
            final searchNotifier = ref.read(eventSearchProvider.notifier);
            searchNotifier.setQuery(_searchController.text.trim());
            searchNotifier.setCategory(_selectedCategory);

            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Search applied successfully')),
            );
          },
          child: const Text('Search'),
        ),
      ],
    );
  }
}

class EventFilterDialog extends ConsumerStatefulWidget {
  const EventFilterDialog({super.key});

  @override
  ConsumerState<EventFilterDialog> createState() => _EventFilterDialogState();
}

class _EventFilterDialogState extends ConsumerState<EventFilterDialog> {
  late bool _upcomingOnly;
  late bool _nearbyOnly;
  late double _radiusKm;

  @override
  void initState() {
    super.initState();
    final currentFilters = ref.read(eventFiltersProvider);
    _upcomingOnly = currentFilters.upcomingOnly;
    _nearbyOnly = currentFilters.nearbyOnly;
    _radiusKm = currentFilters.radiusKm;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Events'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Upcoming events only'),
            value: _upcomingOnly,
            onChanged: (value) => setState(() => _upcomingOnly = value),
          ),
          SwitchListTile(
            title: const Text('Nearby events only'),
            value: _nearbyOnly,
            onChanged: (value) => setState(() => _nearbyOnly = value),
          ),
          if (_nearbyOnly)
            Slider(
              value: _radiusKm,
              min: 1,
              max: 100,
              divisions: 99,
              label: '${_radiusKm.round()} km',
              onChanged: (value) => setState(() => _radiusKm = value),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Apply filters
            final filtersNotifier = ref.read(eventFiltersProvider.notifier);
            filtersNotifier.setUpcomingOnly(_upcomingOnly);
            filtersNotifier.setNearbyOnly(_nearbyOnly);
            filtersNotifier.setRadiusKm(_radiusKm);

            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Filters applied successfully')),
            );
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
