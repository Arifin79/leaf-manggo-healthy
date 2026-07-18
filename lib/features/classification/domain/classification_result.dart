class ClassificationResult {
  final String category;
  final double confidence;
  final bool isSuccsess;
  final String? errorMessage;

  const ClassificationResult({
    required this.category,
    required this.confidence,
    required this.isSuccsess,
    this.errorMessage,
  });

  factory ClassificationResult.fromJson(Map<String, dynamic> json) {
    return ClassificationResult(
      category: json['category'] as String? ?? 'Unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      isSuccsess: (json['is_success'] as bool?) ?? false,
      errorMessage: json['error_message'] as String?,
    );
  }

  factory ClassificationResult.error(String message) {
    return ClassificationResult(
      category: '',
      confidence: 0.0,
      isSuccsess: false,
      errorMessage: message,
    );
  }
  int get confidencePercent => (confidence * 100).round();
}