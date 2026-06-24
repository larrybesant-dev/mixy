import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/providers/providers.dart';
import 'package:mixvy/shared/widgets/club_background.dart';
import 'package:mixvy/shared/widgets/neon_button.dart';

class MatchPreferencesPage extends ConsumerStatefulWidget {
  const MatchPreferencesPage({super.key});

  @override
  ConsumerState<MatchPreferencesPage> createState() =>
      _MatchPreferencesPageState();
}

class _MatchPreferencesPageState extends ConsumerState<MatchPreferencesPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Preferences
  int _minAge = 18;
  int _maxAge = 35;
  final List<String> _preferredGenders = [];
  final List<String> _interests = [];
  String _locationPreference = 'anywhere';
  int _maxDistance = 50; // in km

  final List<String> _availableGenders = [
    'Male',
    'Female',
    'Non-binary',
    'Other'
  ];
  final List<String> _availableInterests = [
    'Music',
    'Sports',
    'Travel',
    'Food',
    'Movies',
    'Books',
    'Gaming',
    'Art',
    'Photography',
    'Fitness',
    'Dancing',
    'Cooking',
    'Technology',
    'Nature',
    'Pets',
    'Fashion'
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentPreferences();
  }

  Future<void> _loadCurrentPreferences() async {
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      // Load existing preferences if available
      // For now, we'll use defaults
    }
  }

  Future<void> _savePreferences() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        final firestoreService = ref.read(firestoreServiceProvider);

        final preferences = {
          'matchPreferences': {
            'minAge': _minAge,
            'maxAge': _maxAge,
            'preferredGenders': _preferredGenders,
            'interests': _interests,
            'locationPreference': _locationPreference,
            'maxDistance': _maxDistance,
          },
        };

        await firestoreService.updateUserFields(user.id, preferences);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Preferences saved successfully!')),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save preferences: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set your preferences to find better matches',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Age Range
                  _buildSectionHeader('Age Range'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _minAge.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Min Age',
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            final age = int.tryParse(value);
                            if (age == null || age < 18) {
                              return 'Min 18';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            _minAge = int.tryParse(value) ?? 18;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: _maxAge.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Max Age',
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            final age = int.tryParse(value);
                            if (age == null || age > 100) {
                              return 'Max 100';
                            }
                            if (age <= _minAge) {
                              return 'Must be > min age';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            _maxAge = int.tryParse(value) ?? 35;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Preferred Genders
                  _buildSectionHeader('Preferred Genders'),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _availableGenders.map((gender) {
                      final isSelected = _preferredGenders.contains(gender);
                      return FilterChip(
                        label: Text(gender),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _preferredGenders.add(gender);
                            } else {
                              _preferredGenders.remove(gender);
                            }
                          });
                        },
                        backgroundColor: Colors.white10,
                        selectedColor:
                            const Color(0xFFFFD700).withValues(alpha: 0.3),
                        checkmarkColor: const Color(0xFFFFD700),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Interests
                  _buildSectionHeader('Shared Interests'),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _availableInterests.map((interest) {
                      final isSelected = _interests.contains(interest);
                      return FilterChip(
                        label: Text(interest),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _interests.add(interest);
                            } else {
                              _interests.remove(interest);
                            }
                          });
                        },
                        backgroundColor: Colors.white10,
                        selectedColor:
                            const Color(0xFFFFD700).withValues(alpha: 0.3),
                        checkmarkColor: const Color(0xFFFFD700),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Location Preference
                  _buildSectionHeader('Location'),
                  DropdownButtonFormField<String>(
                    initialValue: _locationPreference,
                    decoration: const InputDecoration(
                      labelText: 'Location Preference',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: Colors.grey[900],
                    items: const [
                      DropdownMenuItem(
                          value: 'anywhere', child: Text('Anywhere')),
                      DropdownMenuItem(
                          value: 'same_city', child: Text('Same City')),
                      DropdownMenuItem(
                          value: 'same_country', child: Text('Same Country')),
                    ],
                    onChanged: (value) {
                      setState(() => _locationPreference = value ?? 'anywhere');
                    },
                  ),
                  const SizedBox(height: 16),

                  // Max Distance (only show if location preference is same_city)
                  if (_locationPreference == 'same_city')
                    TextFormField(
                      initialValue: _maxDistance.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Max Distance (km)',
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final distance = int.tryParse(value);
                        if (distance == null || distance < 1) {
                          return 'Min 1 km';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        _maxDistance = int.tryParse(value) ?? 50;
                      },
                    ),

                  const SizedBox(height: 32),

                  // Save Button
                  NeonButton(
                    label: _isLoading ? 'Saving...' : 'Save Preferences',
                    onPressed: _isLoading ? () {} : () => _savePreferences(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFFD700),
        ),
      ),
    );
  }
}

