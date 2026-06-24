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

  LibraryItemData? findByTitle(String title) {
    try {
      return _items.firstWhere(
        (item) => item.title.toLowerCase() == title.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<LibraryItemData?> findByTitleFromFirestore(String title) async {
    return await _firestoreService.getLibraryItemByTitle(title);
  }

  Future<bool> addItem(LibraryItemData item) async {
    try {
      await _firestoreService.addLibraryItem(item);
      await loadItems(); 
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menambahkan data: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteItem(String id) async {
    try {
      await _firestoreService.deleteLibraryItem(id);
      await loadItems(); 
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus data: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateItem(String id, LibraryItemData item) async {
    try {
      await _firestoreService.updateLibraryItem(id, item);
      await loadItems(); 
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui data: $e';
      notifyListeners();
      return false;
    }
  }
}
