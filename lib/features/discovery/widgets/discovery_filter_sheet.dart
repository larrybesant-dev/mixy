import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discovery_preferences.dart';
import '../providers/discovery_provider.dart';

class DiscoveryFilterSheet extends ConsumerStatefulWidget {
  final String userId;
  final DiscoveryPreferences preferences;
  final VoidCallback onApply;

  const DiscoveryFilterSheet({
    required this.userId,
    required this.preferences,
    required this.onApply,
    super.key,
  });

  @override
  ConsumerState<DiscoveryFilterSheet> createState() =>
      _DiscoveryFilterSheetState();
}

class _DiscoveryFilterSheetState extends ConsumerState<DiscoveryFilterSheet> {
  late int _minAge;
  late int _maxAge;
  late List<String> _selectedInterests;

  // Common interest tags (can be expanded)
  static const List<String> _availableInterests = [
    'Music',
    'Travel',
    'Sports',
    'Art',
    'Gaming',
    'Fitness',
    'Movies',
    'Reading',
    'Cooking',
    'Photography',
    'Dancing',
    'Hiking',
    'Yoga',
    'Meditation',
    'Nightlife',
    'Live Events',
  ];

  @override
  void initState() {
    super.initState();
    _minAge = widget.preferences.minAge;
    _maxAge = widget.preferences.maxAge;
    _selectedInterests = List.from(widget.preferences.interestTags);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Discovery Filters',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Age Range Section
                Text(
                  'Age Range',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Min Age'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<int>(
                              value: _minAge,
                              isExpanded: true,
                              underline: const SizedBox.shrink(),
                              items: List.generate(
                                83,
                                (i) => DropdownMenuItem(
                                  value: i + 18,
                                  child: Text('${i + 18}'),
                                ),
                              ),
                              onChanged: (val) {
                                if (val != null && val <= _maxAge) {
                                  setState(() => _minAge = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Max Age'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<int>(
                              value: _maxAge,
                              isExpanded: true,
                              underline: const SizedBox.shrink(),
                              items: List.generate(
                                83,
                                (i) => DropdownMenuItem(
                                  value: i + 18,
                                  child: Text('${i + 18}'),
                                ),
                              ),
                              onChanged: (val) {
                                if (val != null && val >= _minAge) {
                                  setState(() => _maxAge = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Display range
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Showing ages $_minAge - $_maxAge',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ),

                const SizedBox(height: 32),

                // Interests Section
                Text(
                  'Interests',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select interests to see people with shared passions (optional)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),

                // Interest chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableInterests.map((interest) {
                    final isSelected = _selectedInterests.contains(interest);
                    return FilterChip(
                      label: Text(interest),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedInterests.add(interest);
                          } else {
                            _selectedInterests.remove(interest);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _applyFilters(),
                        child: const Text('Apply Filters'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _applyFilters() async {
    final controller =
        ref.read(discoveryPreferencesControllerProvider.notifier);

    // Save age range
    await controller.updateAgeRange(widget.userId, _minAge, _maxAge);

    // Save interests
    await controller.updateInterestTags(widget.userId, _selectedInterests);

    if (mounted) {
      Navigator.pop(context);
      widget.onApply();
    }
  }
}
