import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/classification_repository.dart';
import '../../data/leaf_validator_service.dart';
import '../../data/object_validator_service.dart';
import '../../domain/classification_result.dart';
import '../models/library_item_data.dart';

enum ClassificationState { initial, imageSelected, loading, success, error, invalidImage }

class ClassificationProvider extends ChangeNotifier {
  final ClassificationRepository _repository;
  final LeafValidatorService _leafValidator;
  final ObjectValidatorService _objectValidator;

  ClassificationProvider({
    ClassificationRepository? repository,
    LeafValidatorService? leafValidator,
    ObjectValidatorService? objectValidator,
  })  : _repository = repository ?? ClassificationRepositoryImpl(),
        _leafValidator = leafValidator ?? LeafValidatorService(),
        _objectValidator = objectValidator ?? ObjectValidatorService();

  ClassificationState _state = ClassificationState.initial;
  File?                 _selectedImage;
  ClassificationResult? _result;
  String?               _errorMessage;
  LibraryItemData?      _matchedLibraryItem;
  String                _loadingMessage = '';
  double?               _leafPixelPercentage;

  ClassificationState   get state                => _state;
  File?                 get selectedImage         => _selectedImage;
  ClassificationResult? get result                => _result;
  String?               get errorMessage          => _errorMessage;
  LibraryItemData?      get matchedLibraryItem    => _matchedLibraryItem;
  String                get loadingMessage        => _loadingMessage;
  double?               get leafPixelPercentage   => _leafPixelPercentage;

  void onImageSelected(File file) {
    _selectedImage = file;
    _result        = null;
    _errorMessage  = null;
    _matchedLibraryItem = null;
    _leafPixelPercentage = null;
    _state         = ClassificationState.imageSelected;
    notifyListeners();
  }

  Future<void> classifyImage() async {
    if (_selectedImage == null) return;
    _state = ClassificationState.loading;
    _loadingMessage = 'Memeriksa warna gambar...';
    _errorMessage = null;
    notifyListeners();

    // Step 1: HSV color heuristic.
    final colorValidation = await _leafValidator.validateLeafImage(_selectedImage!);
    _leafPixelPercentage = colorValidation.leafPixelPercentage;

    if (!colorValidation.isValid) {
      _state = ClassificationState.invalidImage;
      _errorMessage = colorValidation.message;
      _loadingMessage = '';
      notifyListeners();
      return;
    }

    // Step 2: ML Kit object/scene labeling.
    _loadingMessage = 'Memvalidasi objek...';
    notifyListeners();

    final objectValidation = await _objectValidator.validateIsLeaf(_selectedImage!);

    if (!objectValidation.isLeaf) {
      _state = ClassificationState.invalidImage;
      _errorMessage = objectValidation.message;
      _loadingMessage = '';
      notifyListeners();
      return;
    }

    // Step 3: send to the Flask model.
    _loadingMessage = 'Menganalisis penyakit...';
    notifyListeners();

    final result = await _repository.classifyLeaf(_selectedImage!);

    if (result.isSuccsess) {
      _result = result;
      _state  = ClassificationState.success;
    } else {
      _errorMessage = result.errorMessage;
      _state        = ClassificationState.error;
    }
    _loadingMessage = '';
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
    _leafPixelPercentage = null;
    _loadingMessage = '';
    _state         = ClassificationState.initial;
    notifyListeners();
  }
}