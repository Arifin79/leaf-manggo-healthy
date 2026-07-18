import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

class ObjectValidationResult {
  final bool isLeaf;
  final List<String> detectedLabels;
  final String? message;

  const ObjectValidationResult({
    required this.isLeaf,
    required this.detectedLabels,
    this.message,
  });
}

/// Second-stage validation on top of the HSV color check: uses Google
/// ML Kit's on-device image labeling to reject photos that pass the color
/// heuristic by accident (e.g. a green wall, brown cardboard) but aren't
/// actually a plant/leaf.
class ObjectValidatorService {
  static const double _confidenceThreshold = 0.50;

  static const List<String> _plantKeywords = [
    'plant', 'leaf', 'tree', 'nature', 'vegetation',
    'flower', 'grass', 'botany', 'herb', 'foliage',
    'twig', 'branch', 'shrub', 'flora',
  ];

  static const String _invalidMessage =
      'Objek tidak dikenali sebagai daun tanaman. '
      'Arahkan kamera ke daun mangga secara langsung.';

  Future<ObjectValidationResult> validateIsLeaf(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final imageLabeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: _confidenceThreshold),
    );

    try {
      final labels = await imageLabeler.processImage(inputImage);

      final detectedLabels = labels
          .map((l) => '${l.label} (${(l.confidence * 100).toStringAsFixed(0)}%)')
          .toList();

      final isLeaf = labels.any((l) {
        final lower = l.label.toLowerCase();
        return _plantKeywords.any((keyword) => lower.contains(keyword));
      });

      return ObjectValidationResult(
        isLeaf: isLeaf,
        detectedLabels: detectedLabels,
        message: isLeaf ? null : _invalidMessage,
      );
    } finally {
      await imageLabeler.close();
    }
  }
}
