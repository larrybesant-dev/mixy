import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mixmingle/shared/models/event.dart';
import 'package:mixmingle/shared/providers/events_controller.dart';
import 'package:mixmingle/shared/providers/providers.dart';
import 'package:mixmingle/shared/widgets/club_background.dart';
import 'package:mixmingle/shared/validation.dart';

class CreateEventPage extends ConsumerStatefulWidget {
  const CreateEventPage({super.key});

  @override
  ConsumerState<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends ConsumerState<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxCapacityController = TextEditingController();

  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  String _category = 'Social';
  bool _isPublic = true;
  bool _isLoading = false;

  final List<String> _categories = [
    'Social',
    'Networking',
    'Sports',
    'Music',
    'Food',
    'Art',
    'Technology',
    'Speed Dating',
    'Party',
    'Workshop',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxCapacityController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      if (mounted) {
        setState(() => _startDate = picked);
      }
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  bool _validateForm() {
    if (_formKey.currentState?.validate() ?? false) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill in all required fields.')),
    );
    return false;
  }

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);
    try {
      final event = Event(
        id: const Uuid().v4(),
        title: ValidationHelpers.sanitizeInput(_titleController.text),
        description:
            ValidationHelpers.sanitizeInput(_descriptionController.text),
        location: ValidationHelpers.sanitizeInput(_locationController.text),
        category: _category,
        isPublic: _isPublic,
        maxCapacity: int.tryParse(_maxCapacityController.text) ?? 0,
        startTime: DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
          _startTime?.hour ?? 0,
          _startTime?.minute ?? 0,
        ),
        endTime: DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          _endTime?.hour ?? 0,
          _endTime?.minute ?? 0,
        ),
        hostId: ref.read(currentUserProvider).value?.id ?? '',
        attendees: [],
        latitude: 0.0,
        longitude: 0.0,
        imageUrl: '',
        createdAt: DateTime.now(),
      );

      await ref.read(eventsServiceProvider).createEvent(event);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully!')),
        );
        _navigateToHome(context);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firebase error: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image picker not implemented yet')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Create Event'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(12),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'Add Event Image',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                const Text(
                  'Event Details',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Event Title',
                      border: OutlineInputBorder(),
                      hintText: 'Enter event title',
                    ),
                    maxLength: ValidationConstants.eventTitleMaxLength,
                    validator: (value) =>
                        ValidationHelpers.validateLengthRequired(
                      value,
                      ValidationConstants.eventTitleMinLength,
                      ValidationConstants.eventTitleMaxLength,
                      'Event title',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      hintText: 'Describe your event',
                    ),
                    maxLines: 3,
                    maxLength: ValidationConstants.eventDescriptionMaxLength,
                    validator: (value) =>
                        ValidationHelpers.validateLengthRequired(
                      value,
                      ValidationConstants.eventDescriptionMinLength,
                      ValidationConstants.eventDescriptionMaxLength,
                      'Description',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _category = value!),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Date & Time',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Start Time'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DateTimePicker(
                        label: 'Date',
                        value: _startDate != null
                            ? DateFormat('MMM dd, yyyy').format(_startDate!)
                            : null,
                        onTap: _selectStartDate,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DateTimePicker(
                        label: 'Time',
                        value: _startTime?.format(context),
                        onTap: _selectStartTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('End Time'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DateTimePicker(
                        label: 'Date',
                        value: _endDate != null
                            ? DateFormat('MMM dd, yyyy').format(_endDate!)
                            : null,
                        onTap: _selectEndDate,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DateTimePicker(
                        label: 'Time',
                        value: _endTime?.format(context),
                        onTap: _selectEndTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                const Text(
                  'Location & Capacity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(),
                      hintText: 'Enter event location',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Event location is required';
                      }
                      return null;
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextFormField(
                    controller: _maxCapacityController,
                    decoration: const InputDecoration(
                      labelText: 'Maximum Attendees',
                      border: OutlineInputBorder(),
                      hintText: '50',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final maxCapacity = int.tryParse(value ?? '');
                      if (maxCapacity == null || maxCapacity < 1) {
                        return 'Please enter a valid number of attendees';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Public Event'),
                  subtitle: const Text('Anyone can see and join this event'),
                  value: _isPublic,
                  onChanged: (value) => setState(() => _isPublic = value),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Create Event'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DateTimePicker extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const DateTimePicker({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
        ),
        child: Text(value ?? 'Select $label'),
      ),
    );
  }
}
