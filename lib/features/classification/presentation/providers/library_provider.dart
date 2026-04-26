import 'package:flutter/material.dart';
import '../../data/firestore_service.dart';
import '../models/library_item_data.dart';

class LibraryProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<LibraryItemData> _items = [];
  List<LibraryItemData> get items => _items;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Load all library items from Firestore
  Future<void> loadItems() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items = await _firestoreService.getLibraryItems();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memuat data: $e';
      notifyListeners();
    }
  }

  /// Find a library item by title (for matching classification results)
  LibraryItemData? findByTitle(String title) {
    try {
      return _items.firstWhere(
        (item) => item.title.toLowerCase() == title.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Find by title from Firestore directly (when items may not be loaded)
  Future<LibraryItemData?> findByTitleFromFirestore(String title) async {
    return await _firestoreService.getLibraryItemByTitle(title);
  }

  /// Add a new disease item
  Future<bool> addItem(LibraryItemData item) async {
    try {
      await _firestoreService.addLibraryItem(item);
      await loadItems(); // Refresh the list
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menambahkan data: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete a disease item
  Future<bool> deleteItem(String id) async {
    try {
      await _firestoreService.deleteLibraryItem(id);
      await loadItems(); // Refresh the list
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus data: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update a disease item
  Future<bool> updateItem(String id, LibraryItemData item) async {
    try {
      await _firestoreService.updateLibraryItem(id, item);
      await loadItems(); // Refresh the list
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui data: $e';
      notifyListeners();
      return false;
    }
  }
}
