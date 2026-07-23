import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import 'widgets/category_directory.dart';
import 'widgets/room_list_view.dart';

class RoomBrowserScreen extends ConsumerStatefulWidget {
  const RoomBrowserScreen({super.key, this.initialCategory});
  final String? initialCategory;

  @override
  ConsumerState<RoomBrowserScreen> createState() => _RoomBrowserScreenState();
}

class _RoomBrowserScreenState extends ConsumerState<RoomBrowserScreen> {
  static const List<({String label, String emoji, String? value})> _categories = [
    (label: 'All Rooms', emoji: '✨', value: null),
    (label: 'Music', emoji: '🎵', value: 'music'),
    (label: 'Talk', emoji: '💬', value: 'talk'),
    (label: 'Gaming', emoji: '🎮', value: 'gaming'),
    (label: 'Dance', emoji: '💃', value: 'dance'),
    (label: 'Dating', emoji: '💕', value: 'dating'),
    (label: 'Study', emoji: '📚', value: 'study'),
    (label: 'Art', emoji: '🎨', value: 'art'),
  ];

  String? _selectedCategory;
  bool _showGrid = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory;
      _showGrid = true;
    }
  }

  void _onSearchChanged() {
    final cleanQuery = _searchController.text.trim().toLowerCase();
    if (_searchQuery != cleanQuery) {
      setState(() => _searchQuery = cleanQuery);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      safeArea: false,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: _showGrid
            ? RoomListView(
                key: const ValueKey('room_list_view'),
                category: _selectedCategory,
                categoryLabel: _categoryLabel(_selectedCategory),
                searchQuery: _searchQuery,
                searchController: _searchController,
                onBack: () => setState(() {
                  _showGrid = false;
                  _selectedCategory = null;
                  _searchController.clear();
                }),
              )
            : CategoryDirectory(
                key: const ValueKey('category_directory_view'),
                categories: _categories,
                onCategorySelected: (cat) => setState(() {
                  _selectedCategory = cat;
                  _showGrid = true;
                }),
              ),
      ),
    );
  }

  String _categoryLabel(String? value) {
    if (value == null) return 'All Rooms';
    final cat = _categories.where((c) => c.value == value).firstOrNull;
    return cat != null ? '${cat.emoji}  ${cat.label}' : 'Rooms';
  }
}
