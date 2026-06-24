import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Generic pagination controller for Firestore queries
class PaginationController<T> extends ChangeNotifier {
  final Query Function() queryBuilder;
  final T Function(DocumentSnapshot doc) fromDocument;
  final int pageSize;

  final List<T> _items = [];
  final List<DocumentSnapshot> _documentSnapshots = [];

  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  DocumentSnapshot? _lastDocument;

  PaginationController({
    required this.queryBuilder,
    required this.fromDocument,
    this.pageSize = 20,
  });

  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  int get itemCount => _items.length;

  /// Load the first page
  Future<void> loadInitial() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _items.clear();
    _documentSnapshots.clear();
    _lastDocument = null;
    _hasMore = true;
    notifyListeners();

    try {
      final query = queryBuilder().limit(pageSize);
      final snapshot = await query.get();

      _items.addAll(
        snapshot.docs.map((doc) {
          _documentSnapshots.add(doc);
          return fromDocument(doc);
        }),
      );

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      _hasMore = snapshot.docs.length >= pageSize;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _hasMore = false;
      notifyListeners();
    }
  }

  /// Load the next page
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore || _lastDocument == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final query =
          queryBuilder().startAfterDocument(_lastDocument!).limit(pageSize);

      final snapshot = await query.get();

      _items.addAll(
        snapshot.docs.map((doc) {
          _documentSnapshots.add(doc);
          return fromDocument(doc);
        }),
      );

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      _hasMore = snapshot.docs.length >= pageSize;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh (reload from start)
  Future<void> refresh() async {
    await loadInitial();
  }

  /// Clear all data
  void clear() {
    _items.clear();
    _documentSnapshots.clear();
    _lastDocument = null;
    _hasMore = true;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}

/// Stream-based pagination controller for real-time updates
class StreamPaginationController<T> extends ChangeNotifier {
  final Query Function() queryBuilder;
  final T Function(DocumentSnapshot doc) fromDocument;
  final int pageSize;

  final List<T> _items = [];
  final bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  DocumentSnapshot? _lastDocument;

  StreamPaginationController({
    required this.queryBuilder,
    required this.fromDocument,
    this.pageSize = 20,
  });

  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Stream<List<T>> get stream {
    return queryBuilder().limit(pageSize).snapshots().map((snapshot) {
      _items.clear();
      _items.addAll(snapshot.docs.map(fromDocument));

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      _hasMore = snapshot.docs.length >= pageSize;
      notifyListeners();

      return _items;
    });
  }

  Stream<List<T>> loadMore() {
    if (_lastDocument == null) {
      return stream;
    }

    return queryBuilder()
        .startAfterDocument(_lastDocument!)
        .limit(pageSize)
        .snapshots()
        .map((snapshot) {
      final newItems = snapshot.docs.map(fromDocument).toList();
      _items.addAll(newItems);

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      _hasMore = snapshot.docs.length >= pageSize;
      notifyListeners();

      return _items;
    });
  }
}
