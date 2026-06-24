import 'package:flutter/material.dart';
import 'package:mixvy/core/pagination/pagination_controller.dart';

/// A reusable paginated list view widget
class PaginatedListView<T> extends StatefulWidget {
  final PaginationController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? loadingWidget;
  final Widget? emptyWidget;
  final Widget Function(String error)? errorBuilder;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const PaginatedListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.loadingWidget,
    this.emptyWidget,
    this.errorBuilder,
    this.scrollController,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);

    // Load initial data if empty
    if (widget.controller.items.isEmpty && !widget.controller.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.loadInitial();
      });
    }

    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onScroll() {
    if (_isLoadingMore || !widget.controller.hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final delta = maxScroll - currentScroll;

    // Load more when user is 200 pixels from bottom
    if (delta < 200 && !widget.controller.isLoading) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    await widget.controller.loadMore();
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show error if present
    if (widget.controller.error != null) {
      return widget.errorBuilder?.call(widget.controller.error!) ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error: ${widget.controller.error}',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => widget.controller.refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
    }

    // Show initial loading
    if (widget.controller.items.isEmpty && widget.controller.isLoading) {
      return widget.loadingWidget ??
          const Center(
            child: CircularProgressIndicator(),
          );
    }

    // Show empty state
    if (widget.controller.items.isEmpty) {
      return widget.emptyWidget ??
          const Center(
            child: Text(
              'No items found',
              style: TextStyle(color: Colors.white70),
            ),
          );
    }

    // Show list with items
    return RefreshIndicator(
      onRefresh: () => widget.controller.refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        itemCount: widget.controller.items.length +
            (widget.controller.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at bottom
          if (index == widget.controller.items.length) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: widget.controller.isLoading
                    ? const CircularProgressIndicator()
                    : TextButton.icon(
                        onPressed: _loadMore,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Load More'),
                      ),
              ),
            );
          }

          // Show item
          final item = widget.controller.items[index];
          return widget.itemBuilder(context, item, index);
        },
      ),
    );
  }
}

/// A simpler paginated grid view
class PaginatedGridView<T> extends StatefulWidget {
  final PaginationController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int crossAxisCount;
  final double childAspectRatio;
  final Widget? loadingWidget;
  final Widget? emptyWidget;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;

  const PaginatedGridView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
    this.loadingWidget,
    this.emptyWidget,
    this.scrollController,
    this.padding,
  });

  @override
  State<PaginatedGridView<T>> createState() => _PaginatedGridViewState<T>();
}

class _PaginatedGridViewState<T> extends State<PaginatedGridView<T>> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);

    if (widget.controller.items.isEmpty && !widget.controller.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.loadInitial();
      });
    }

    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!widget.controller.hasMore || widget.controller.isLoading) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll < 200) {
      widget.controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.items.isEmpty && widget.controller.isLoading) {
      return widget.loadingWidget ??
          const Center(child: CircularProgressIndicator());
    }

    if (widget.controller.items.isEmpty) {
      return widget.emptyWidget ??
          const Center(
              child: Text('No items found',
                  style: TextStyle(color: Colors.white70)));
    }

    return RefreshIndicator(
      onRefresh: () => widget.controller.refresh(),
      child: GridView.builder(
        controller: _scrollController,
        padding: widget.padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          childAspectRatio: widget.childAspectRatio,
        ),
        itemCount: widget.controller.items.length +
            (widget.controller.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == widget.controller.items.length) {
            return const Center(child: CircularProgressIndicator());
          }
          return widget.itemBuilder(
              context, widget.controller.items[index], index);
        },
      ),
    );
  }
}

