import 'package:cloud_firestore/cloud_firestore.dart';

class LibraryItemData {
  final String? id;
  final String title;
  final String originalName;
  final String status;
  final String type;
  final String description;
  final Map<String, String> partsAttacked;
  final String earlyPhase;
  final String chronicPhase;
  final List<String> technicalControl;
  final String chemicalControlInfo;
  final String chemicalDose;
  final String chemicalTime;
  final String spreadWarning;
  
  final String subtitle;
  final String shortDescription;

  final String? imageBase64;
  
  final String? adminNote;

  // true once the class is recognized by the classification model.
  // false while a newly submitted class is still being trained.
  final bool isActive;

  final String? addedBy;

  const LibraryItemData({
    this.id,
    required this.title,
    required this.originalName,
    required this.status,
    required this.type,
    required this.description,
    required this.partsAttacked,
    required this.earlyPhase,
    required this.chronicPhase,
    required this.technicalControl,
    required this.chemicalControlInfo,
    required this.chemicalDose,
    required this.chemicalTime,
    required this.spreadWarning,
    required this.subtitle,
    required this.shortDescription,
    this.imageBase64,
    this.adminNote,
    this.isActive = true,
    this.addedBy,
  });

  factory LibraryItemData.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return LibraryItemData(
      id: doc.id,
      title: data['title'] as String? ?? '',
      subtitle: data['subtitle'] as String? ?? '',
      shortDescription: data['shortDescription'] as String? ?? '',
      originalName: data['originalName'] as String? ?? '',
      status: data['status'] as String? ?? '',
      type: data['type'] as String? ?? '',
      description: data['description'] as String? ?? '',
      partsAttacked: Map<String, String>.from(data['partsAttacked'] as Map? ?? {}),
      earlyPhase: data['earlyPhase'] as String? ?? '',
      chronicPhase: data['chronicPhase'] as String? ?? '',
      technicalControl: List<String>.from(data['technicalControl'] as List? ?? []),
      chemicalControlInfo: data['chemicalControlInfo'] as String? ?? '',
      chemicalDose: data['chemicalDose'] as String? ?? '',
      chemicalTime: data['chemicalTime'] as String? ?? '',
      spreadWarning: data['spreadWarning'] as String? ?? '',
      imageBase64: data['imageBase64'] as String?,
      adminNote: data['adminNote'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      addedBy: data['addedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'subtitle': subtitle,
      'shortDescription': shortDescription,
      'originalName': originalName,
      'status': status,
      'type': type,
      'description': description,
      'partsAttacked': partsAttacked,
      'earlyPhase': earlyPhase,
      'chronicPhase': chronicPhase,
      'technicalControl': technicalControl,
      'chemicalControlInfo': chemicalControlInfo,
      'chemicalDose': chemicalDose,
      'chemicalTime': chemicalTime,
      'spreadWarning': spreadWarning,
      'imageBase64': imageBase64,
      'adminNote': adminNote,
      'isActive': isActive,
      'addedBy': addedBy,
    };
  }

  LibraryItemData copyWith({String? id, String? adminNote, bool? isActive, String? addedBy}) {
    return LibraryItemData(
      id: id ?? this.id,
      title: title,
      subtitle: subtitle,
      shortDescription: shortDescription,
      originalName: originalName,
      status: status,
      type: type,
      description: description,
      partsAttacked: partsAttacked,
      earlyPhase: earlyPhase,
      chronicPhase: chronicPhase,
      technicalControl: technicalControl,
      chemicalControlInfo: chemicalControlInfo,
      chemicalDose: chemicalDose,
      chemicalTime: chemicalTime,
      spreadWarning: spreadWarning,
      imageBase64: imageBase64,
      adminNote: adminNote ?? this.adminNote,
      isActive: isActive ?? this.isActive,
      addedBy: addedBy ?? this.addedBy,
    );
  }
}

