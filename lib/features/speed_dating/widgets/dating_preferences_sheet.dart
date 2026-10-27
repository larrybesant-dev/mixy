import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/error_reporting.dart';
import '../models/dating_preferences.dart';
import '../providers/dating_preferences_provider.dart';

/// Opens the dating preferences sheet. Resolves to true when saved.
Future<bool> showDatingPreferencesSheet(
  BuildContext context, {
  required String userId,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DatingPreferencesSheet(userId: userId),
  );
  return saved ?? false;
}

class DatingPreferencesSheet extends ConsumerWidget {
  const DatingPreferencesSheet({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(datingPreferencesProvider(userId));
    return preferences.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const SizedBox(
        height: 200,
        child: Center(child: Text('Could not load your preferences.')),
      ),
      data: (initial) =>
          _DatingPreferencesForm(userId: userId, initial: initial),
    );
  }
}

class _DatingPreferencesForm extends ConsumerStatefulWidget {
  const _DatingPreferencesForm({required this.userId, required this.initial});

  final String userId;
  final DatingPreferences initial;

  @override
  ConsumerState<_DatingPreferencesForm> createState() =>
      _DatingPreferencesFormState();
}

class _DatingPreferencesFormState
    extends ConsumerState<_DatingPreferencesForm> {
  late Set<String> _lookingFor;
  late RangeValues _ageRange;
  double? _maxDistanceKm;
  late String _distanceUnit;
  String? _race;
  String? _sexuality;
  late Set<String> _preferredRaces;
  late Set<String> _preferredSexualities;
  DatingCoordinates? _coordinates;
  bool _saving = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _lookingFor = {...initial.lookingFor};
    _ageRange = RangeValues(
      initial.minAge.toDouble(),
      initial.maxAge.toDouble(),
    );
    _maxDistanceKm = initial.maxDistanceKm;
    _distanceUnit = initial.distanceUnit;
    _race = initial.race;
    _sexuality = initial.sexuality;
    _preferredRaces = {...initial.preferredRaces};
    _preferredSexualities = {...initial.preferredSexualities};
    _coordinates = initial.coordinates;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<DatingCoordinates?> _fetchLocation() async {
    setState(() => _locating = true);
    try {
      return await ref.read(datingLocationServiceProvider).currentCoordinates();
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _useMyLocation() async {
    DatingCoordinates? coordinates;
    try {
      coordinates = await _fetchLocation();
    } catch (error, stackTrace) {
      reportError(error, stackTrace);
      if (!mounted) return;
      _showMessage('Could not read your location. Try again.');
      return;
    }
    if (!mounted) return;
    if (coordinates == null) {
      _showMessage(
        'Location unavailable. Allow location access in your browser or device settings.',
      );
      return;
    }
    setState(() => _coordinates = coordinates);
    _showMessage('Location added. Save to apply it.');
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    var coordinates = _coordinates;
    // Distance is only enforced when both users have a location, so a
    // distance filter needs a location before it can be saved.
    if (_maxDistanceKm != null && coordinates == null) {
      coordinates = await _fetchLocation();
      if (!mounted) return;
      if (coordinates == null) {
        setState(() => _saving = false);
        _showMessage(
          'A distance filter needs your location. Allow location access or choose "Any distance".',
        );
        return;
      }
    }

    final preferences = DatingPreferences(
      lookingFor: datingGenderOptions
          .where(_lookingFor.contains)
          .toList(growable: false),
      minAge: _ageRange.start.round(),
      maxAge: _ageRange.end.round(),
      maxDistanceKm: _maxDistanceKm,
      distanceUnit: _distanceUnit,
      race: _race,
      sexuality: _sexuality,
      preferredRaces: datingRaceOptions
          .where(_preferredRaces.contains)
          .toList(growable: false),
      preferredSexualities: datingSexualityOptions
          .where(_preferredSexualities.contains)
          .toList(growable: false),
      coordinates: coordinates,
    );

    try {
      await ref
          .read(datingPreferencesStoreProvider)
          .save(widget.userId, preferences);
      ref.invalidate(datingPreferencesProvider(widget.userId));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      reportError(error, stackTrace);
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Could not save your preferences. Try again.');
    }
  }

  Future<void> _deletePreferences() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete dating preferences?'),
        content: const Text(
          'This removes your private filters and saved approximate location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(datingPreferencesStoreProvider).clear(widget.userId);
      ref.invalidate(datingPreferencesProvider(widget.userId));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      reportError(error, stackTrace);
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Could not delete your preferences. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _saving || _locating;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dating preferences', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Choose who you want to meet. These private settings are used only for matching and are never shown to other users.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            _sectionTitle(theme, "I'm looking for"),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in datingGenderOptions)
                  FilterChip(
                    label: Text(option),
                    selected: _lookingFor.contains(option),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _lookingFor.add(option);
                        } else {
                          _lookingFor.remove(option);
                        }
                      });
                    },
                  ),
              ],
            ),
            _hint(theme, 'Select none to see everyone.'),
            const SizedBox(height: 20),
            _sectionTitle(
              theme,
              'Age ${_ageRange.start.round()} to ${_ageRange.end.round()}',
            ),
            RangeSlider(
              values: _ageRange,
              min: datingMinAge.toDouble(),
              max: datingMaxAge.toDouble(),
              divisions: datingMaxAge - datingMinAge,
              labels: RangeLabels(
                '${_ageRange.start.round()}',
                '${_ageRange.end.round()}',
              ),
              onChanged: (values) => setState(() => _ageRange = values),
            ),
            const SizedBox(height: 12),
            _sectionTitle(theme, 'Distance'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: datingUnitKm, label: Text('km')),
                ButtonSegment(value: datingUnitMi, label: Text('miles')),
              ],
              selected: {_distanceUnit},
              onSelectionChanged: busy
                  ? null
                  : (selection) =>
                      setState(() => _distanceUnit = selection.first),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Any distance'),
                  selected: _maxDistanceKm == null,
                  onSelected: (_) => setState(() => _maxDistanceKm = null),
                ),
                for (final preset in datingDistancePresets)
                  ChoiceChip(
                    label: Text('Within $preset $_distanceUnit'),
                    selected: _maxDistanceKm != null &&
                        (_maxDistanceKm! -
                                    datingDistanceToKm(preset, _distanceUnit))
                                .abs() <
                            0.01,
                    onSelected: (_) => setState(
                      () => _maxDistanceKm =
                          datingDistanceToKm(preset, _distanceUnit),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : _useMyLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    _coordinates == null
                        ? 'Use my location'
                        : 'Update location',
                  ),
                ),
                const SizedBox(width: 12),
                if (_coordinates != null)
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                              _coordinates = null;
                              _maxDistanceKm = null;
                            }),
                    icon: const Icon(Icons.location_off_outlined),
                    label: const Text('Remove location'),
                  ),
              ],
            ),
            _hint(
              theme,
              'Distance uses your approximate location, rounded to about 1 km. It is never shown to other users.',
            ),
            const SizedBox(height: 20),
            _sectionTitle(theme, 'Private: race (used only for matching)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Prefer not to say'),
                  selected: _race == null,
                  onSelected: (_) => setState(() => _race = null),
                ),
                for (final option in datingRaceOptions)
                  ChoiceChip(
                    label: Text(option),
                    selected: _race == option,
                    onSelected: (_) => setState(() => _race = option),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _sectionTitle(theme, 'Private: sexuality (used only for matching)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Prefer not to say'),
                  selected: _sexuality == null,
                  onSelected: (_) => setState(() => _sexuality = null),
                ),
                for (final option in datingSexualityOptions)
                  ChoiceChip(
                    label: Text(option),
                    selected: _sexuality == option,
                    onSelected: (_) => setState(() => _sexuality = option),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle(theme, 'Open to races (optional)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in datingRaceOptions)
                  FilterChip(
                    label: Text(option),
                    selected: _preferredRaces.contains(option),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _preferredRaces.add(option);
                        } else {
                          _preferredRaces.remove(option);
                        }
                      });
                    },
                  ),
              ],
            ),
            _hint(theme, 'Select none to be open to everyone.'),
            const SizedBox(height: 16),
            _sectionTitle(theme, 'Open to sexualities (optional)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in datingSexualityOptions)
                  FilterChip(
                    label: Text(option),
                    selected: _preferredSexualities.contains(option),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _preferredSexualities.add(option);
                        } else {
                          _preferredSexualities.remove(option);
                        }
                      });
                    },
                  ),
              ],
            ),
            _hint(theme, 'Select none to be open to everyone.'),
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  onPressed: busy ? null : _deletePreferences,
                  child: const Text('Delete preferences'),
                ),
                const Spacer(),
                TextButton(
                  onPressed:
                      busy ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: busy ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: theme.textTheme.titleSmall),
    );
  }

  Widget _hint(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: theme.textTheme.bodySmall),
    );
  }
}
