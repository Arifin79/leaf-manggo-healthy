import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/class_management_service.dart';
import '../../data/firestore_service.dart';
import '../models/library_item_data.dart';

class ClassManagementProvider extends ChangeNotifier {
  final ClassManagementService _service = ClassManagementService();
  final FirestoreService _firestoreService = FirestoreService();

  static const Duration _pollInterval = Duration(seconds: 5);

  Timer? _pollTimer;
  String? _pendingFirestoreId;

  List<String> _activeClasses = [];
  List<String> get activeClasses => _activeClasses;

  bool _isLoadingStatus = false;
  bool get isLoadingStatus => _isLoadingStatus;

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  bool _isTraining = false;
  bool get isTraining => _isTraining;

  double _uploadProgress = 0.0;
  double get uploadProgress => _uploadProgress;

  String _currentStep = '';
  String get currentStep => _currentStep;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isSuccess = false;
  bool get isSuccess => _isSuccess;

  Future<void> fetchModelStatus() async {
    _isLoadingStatus = true;
    notifyListeners();
    try {
      final status = await _service.getModelStatus();
      _activeClasses = status.classes;
    } catch (_) {
      // Keep the last known list; badges will just fall back to "pending".
    } finally {
      _isLoadingStatus = false;
      notifyListeners();
    }
  }

  bool isClassActive(String title) {
    return _activeClasses.any((c) => c.toLowerCase() == title.toLowerCase());
  }

  /// Throws if the live /model_status check can't be reached — callers must
  /// NOT treat a failed check as "not a duplicate". Silently falling back to
  /// the local Firestore-only check let a class slip through as new when the
  /// network hiccuped, creating a permanently stuck duplicate entry (the
  /// server rejects training a class that already exists, and — if that
  /// name collides with one of the 6 original classes — also refuses to
  /// delete it, since it looks indistinguishable from the real, protected
  /// class).
  Future<bool> isDuplicateClassName(String name, List<LibraryItemData> existingItems) async {
    final normalized = name.trim().toLowerCase();
    if (existingItems.any((item) => item.title.trim().toLowerCase() == normalized)) {
      return true;
    }
    final status = await _service.getModelStatus();
    _activeClasses = status.classes;
    return status.classes.any((c) => c.trim().toLowerCase() == normalized);
  }

  String? _deleteErrorMessage;
  String? get deleteErrorMessage => _deleteErrorMessage;

  /// Removes a dynamically-trained class from the Flask model (classes.json,
  /// dataset_master.csv rows, rf_addon_*.pkl, stored training photos).
  /// Does NOT touch Firestore — callers should also delete the library item
  /// there. Returns true on success; the server rejects the 6 original
  /// classes baked into rf_model.pkl, surfacing an error instead.
  Future<bool> deleteDynamicClass(String className) async {
    _deleteErrorMessage = null;
    final result = await _service.removeClass(className);

    if (!result.isSuccess) {
      // A 404 means the class never made it into classes.json — most often
      // because its training failed or was interrupted before completion.
      // There's nothing server-side left to clean up, so let the caller
      // proceed with deleting the Firestore entry instead of leaving it
      // stuck forever.
      if (result.notFoundOnServer) {
        return true;
      }
      _deleteErrorMessage = result.message;
      notifyListeners();
      return false;
    }
    _activeClasses = result.classes;
    notifyListeners();
    return true;
  }

  /// Rolls back the optimistic pending Firestore entry created at the start
  /// of [submitNewClass] when the submission ends up failing (rejected by
  /// the server, training error, or an unrecognized outcome). Without this,
  /// a failed attempt left a permanent `isActive: false` "Sedang Diproses"
  /// ghost behind — most confusingly for a class name that collides with
  /// one of the 6 protected originals, since it could never be reconciled
  /// or deleted afterwards.
  Future<void> _deletePendingFirestoreEntry() async {
    final id = _pendingFirestoreId;
    if (id == null) return;
    _pendingFirestoreId = null;
    try {
      await _firestoreService.deleteLibraryItem(id);
    } catch (_) {
      // Best-effort cleanup — if this fails too, the admin can still
      // delete the stuck entry manually from the library list.
    }
  }

  void reset() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pendingFirestoreId = null;
    _isUploading = false;
    _isTraining = false;
    _uploadProgress = 0.0;
    _currentStep = '';
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();
  }

  /// [libraryData] carries the full library record (subtitle, symptoms per
  /// phase, technical/chemical control, etc.) to save to Firestore in one
  /// shot — no separate "Tambah Data Pustaka" pass needed afterwards.
  /// `libraryData.title` is used as the class name; `libraryData.isActive`/
  /// `addedBy`/`id` are overwritten internally and don't need to be set by
  /// the caller. Flask's /add_class only takes three required text fields
  /// (description/symptoms/treatment) which it validates as non-empty but
  /// never actually stores — they're derived here from the richer data
  /// instead of asking the admin to fill duplicate boxes for them.
  /// [existingId] lets this reuse a library entry that already exists in
  /// Firestore (e.g. an admin editing a never-trained item and adding
  /// photos to it) instead of always creating a new document.
  Future<bool> submitNewClass({
    required LibraryItemData libraryData,
    required List<File> photos,
    required String adminUid,
    String? existingId,
  }) async {
    final className = libraryData.title.trim();

    _isUploading = true;
    _isTraining = false;
    _isSuccess = false;
    _errorMessage = null;
    _currentStep = 'Mengunggah foto ke server';
    _uploadProgress = 0.1;
    notifyListeners();

    // Create (or update) a pending Firestore entry immediately so admins
    // can see the class is "in progress" from the library page while
    // training runs.
    String? pendingId;
    try {
      final pendingData = libraryData.copyWith(isActive: false, addedBy: adminUid);
      if (existingId != null) {
        await _firestoreService.updateLibraryItem(existingId, pendingData);
        pendingId = existingId;
      } else {
        pendingId = await _firestoreService.addLibraryItemAndGetId(pendingData);
      }
    } catch (e) {
      _isUploading = false;
      _errorMessage = 'Gagal menyimpan data awal: $e';
      notifyListeners();
      return false;
    }

    _pendingFirestoreId = pendingId;

    final symptoms = [libraryData.earlyPhase, libraryData.chronicPhase]
        .where((s) => s.trim().isNotEmpty)
        .join('\n');
    final treatment = [libraryData.technicalControl.join('\n'), libraryData.chemicalControlInfo]
        .where((s) => s.trim().isNotEmpty)
        .join('\n');

    // POST /add_class only acknowledges that photos were received and
    // training has started server-side (it runs in a background thread
    // there). The actual outcome has to be polled via /training_status.
    final ack = await _service.uploadNewClass(
      className: className,
      photos: photos,
      description: libraryData.description,
      symptoms: symptoms,
      treatment: treatment,
    );

    if (!ack.isSuccess) {
      await _deletePendingFirestoreEntry();
      _isUploading = false;
      _isTraining = false;
      _errorMessage = ack.message;
      notifyListeners();
      return false;
    }

    _isUploading = false;
    _isTraining = true;
    _currentStep = 'Mengekstraksi fitur gambar & melatih ulang model';
    _uploadProgress = 0.4;
    notifyListeners();

    return pollTrainingStatus();
  }

  /// Adds more sample photos to a class the model already recognizes and
  /// retrains its addon on the combined dataset — used from the edit form
  /// when an admin tops up an existing class's photo set instead of
  /// creating a brand-new one. No Firestore doc is created or rolled back
  /// here (unlike [submitNewClass]); the library entry already exists and
  /// callers save its metadata separately.
  Future<bool> submitRetrain({
    required String className,
    required List<File> newPhotos,
  }) async {
    _isUploading = true;
    _isTraining = false;
    _isSuccess = false;
    _errorMessage = null;
    _pendingFirestoreId = null;
    _currentStep = 'Mengunggah foto ke server';
    _uploadProgress = 0.1;
    notifyListeners();

    final ack = await _service.retrainClass(className: className, photos: newPhotos);

    if (!ack.isSuccess) {
      _isUploading = false;
      _isTraining = false;
      _errorMessage = ack.message;
      notifyListeners();
      return false;
    }

    _isUploading = false;
    _isTraining = true;
    _currentStep = 'Mengekstraksi fitur gambar & melatih ulang model';
    _uploadProgress = 0.4;
    notifyListeners();

    return pollTrainingStatus();
  }

  /// Polls GET /training_status every 5 seconds until the server reports
  /// `is_training == false`, updating [currentStep]/[uploadProgress] on
  /// every response. Completes with true on success, false on error.
  Future<bool> pollTrainingStatus() {
    _pollTimer?.cancel();
    final completer = Completer<bool>();

    Future<void> checkOnce() async {
      TrainingStatus status;
      try {
        status = await _service.getTrainingStatus();
      } catch (_) {
        // Transient network hiccup while polling — keep trying on the
        // next tick instead of failing the whole flow immediately.
        return;
      }

      _isTraining = status.isTraining;
      if (status.currentStep != null && status.currentStep!.isNotEmpty) {
        _currentStep = status.currentStep!;
      }
      // The server tracks its own progress scale (0.2 -> 0.6 -> 0.9 -> 1.0)
      // separate from the client's optimistic pre-poll value (0.1 -> 0.4).
      // Never let a poll response move the bar backwards — that's what made
      // it visibly jump back a step before continuing.
      if (status.progress > _uploadProgress) {
        _uploadProgress = status.progress;
      }
      notifyListeners();

      if (status.isTraining) return;

      _pollTimer?.cancel();
      _pollTimer = null;

      if (status.error != null) {
        await _deletePendingFirestoreEntry();
        _errorMessage = status.error;
        _isSuccess = false;
        notifyListeners();
        if (!completer.isCompleted) completer.complete(false);
        return;
      }

      if (status.result?.accuracy != null || status.result != null) {
        try {
          if (_pendingFirestoreId != null) {
            await _firestoreService.setLibraryItemActive(_pendingFirestoreId!, true);
          }
          if (status.result!.classes.isNotEmpty) {
            _activeClasses = status.result!.classes;
          }
        } catch (e) {
          _errorMessage = 'Model berhasil dilatih tapi gagal memperbarui data: $e';
          _isSuccess = false;
          notifyListeners();
          if (!completer.isCompleted) completer.complete(false);
          return;
        }

        _isSuccess = true;
        _currentStep = 'Selesai';
        _uploadProgress = 1.0;
        notifyListeners();
        if (!completer.isCompleted) completer.complete(true);
        return;
      }

      // Finished with neither an error nor a result — treat as unknown failure.
      await _deletePendingFirestoreEntry();
      _errorMessage = 'Training berhenti tanpa hasil yang jelas. Coba cek /training_status lagi.';
      _isSuccess = false;
      notifyListeners();
      if (!completer.isCompleted) completer.complete(false);
    }

    checkOnce();
    _pollTimer = Timer.periodic(_pollInterval, (_) => checkOnce());
    return completer.future;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
