import 'package:cloud_firestore/cloud_firestore.dart';
import '../presentation/models/library_item_data.dart';
import '../presentation/models/library_items_mock.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Reference to the 'diseases' collection
  CollectionReference<Map<String, dynamic>> get _diseasesRef =>
      _db.collection('diseases');

  /// Reference to the 'saved_classifications' collection
  CollectionReference<Map<String, dynamic>> get _savedClassificationsRef =>
      _db.collection('saved_classifications');

  // ────────────────────────────────────────────
  //  READ
  // ────────────────────────────────────────────

  /// Get all library items from Firestore
  Future<List<LibraryItemData>> getLibraryItems() async {
    final snapshot = await _diseasesRef.orderBy('title').get();
    return snapshot.docs
        .map((doc) => LibraryItemData.fromFirestore(doc))
        .toList();
  }

  /// Stream of all library items (real-time)
  Stream<List<LibraryItemData>> streamLibraryItems() {
    return _diseasesRef.orderBy('title').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => LibraryItemData.fromFirestore(doc))
            .toList());
  }

  /// Find a disease by its title (used for matching classification results)
  Future<LibraryItemData?> getLibraryItemByTitle(String title) async {
    final snapshot =
        await _diseasesRef.where('title', isEqualTo: title).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return LibraryItemData.fromFirestore(snapshot.docs.first);
  }

  // ────────────────────────────────────────────
  //  CREATE
  // ────────────────────────────────────────────

  /// Add a new disease to Firestore
  Future<void> addLibraryItem(LibraryItemData item) async {
    await _diseasesRef.add(item.toFirestore());
  }

  // ────────────────────────────────────────────
  //  UPDATE
  // ────────────────────────────────────────────

  /// Update an existing disease in Firestore
  Future<void> updateLibraryItem(String id, LibraryItemData item) async {
    await _diseasesRef.doc(id).update(item.toFirestore());
  }

  // ────────────────────────────────────────────
  //  DELETE
  // ────────────────────────────────────────────

  /// Delete a disease from Firestore
  Future<void> deleteLibraryItem(String id) async {
    await _diseasesRef.doc(id).delete();
  }

  // ────────────────────────────────────────────
  //  SAVED CLASSIFICATIONS
  // ────────────────────────────────────────────

  /// Stream of saved classifications
  Stream<List<Map<String, dynamic>>> streamSavedClassifications() {
    return _savedClassificationsRef
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Inject document ID for deletion
        return data;
      }).toList();
    });
  }

  /// Save a classification result
  Future<void> saveClassification(Map<String, dynamic> data) async {
    data['timestamp'] = FieldValue.serverTimestamp();
    await _savedClassificationsRef.add(data);
  }

  /// Delete a saved classification
  Future<void> deleteSavedClassification(String id) async {
    await _savedClassificationsRef.doc(id).delete();
  }


  // ────────────────────────────────────────────
  //  SEED
  // ────────────────────────────────────────────

  /// Seed initial data from mock list if Firestore is empty
  Future<void> seedInitialData() async {
    final snapshot = await _diseasesRef.limit(1).get();
    if (snapshot.docs.isNotEmpty) return; // Already seeded

    final batch = _db.batch();
    for (final item in libraryItemsMock) {
      final docRef = _diseasesRef.doc();
      batch.set(docRef, item.toFirestore());
    }
    await batch.commit();
  }
}
