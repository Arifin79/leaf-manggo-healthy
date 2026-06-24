import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/classification_repository.dart';
import '../../domain/classification_result.dart';
import '../models/library_item_data.dart';

enum ClassificationState { initial, imageSelected, loading, success, error }

class ClassificationProvider extends ChangeNotifier {
  final ClassificationRepository _repository;

  ClassificationProvider({ClassificationRepository? repository})
      : _repository = repository ?? ClassificationRepositoryImpl();

  ClassificationState _state = ClassificationState.initial;
  File?                 _selectedImage;
  ClassificationResult? _result;
  String?               _errorMessage;
  LibraryItemData?      _matchedLibraryItem;

  ClassificationState   get state             => _state;
  File?                 get selectedImage      => _selectedImage;
  ClassificationResult? get result             => _result;
  String?               get errorMessage       => _errorMessage;
  LibraryItemData?      get matchedLibraryItem => _matchedLibraryItem;

  void onImageSelected(File file) {
    _selectedImage = file;
    _result        = null;
    _errorMessage  = null;
    _matchedLibraryItem = null;
    _state         = ClassificationState.imageSelected;
    notifyListeners();
  }

  Future<void> classifyImage() async {
    if (_selectedImage == null) return;
    _state = ClassificationState.loading;
    notifyListeners();

    final result = await _repository.classifyLeaf(_selectedImage!);

    if (result.isSuccsess) {
      _result = result;
      _state  = ClassificationState.success;
    } else {
      _errorMessage = result.errorMessage;
      _state        = ClassificationState.error;
    }
    notifyListeners();
  }

  void setMatchedLibraryItem(LibraryItemData? item) {
    _matchedLibraryItem = item;
    notifyListeners();
  }

  void resetAll() {
    _selectedImage = null;
    _result        = null;
    _errorMessage  = null;
    _matchedLibraryItem = null;
    _state         = ClassificationState.initial;
    notifyListeners();
  }
}