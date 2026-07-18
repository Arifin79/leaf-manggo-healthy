import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ModelStatus {
  final int totalClasses;
  final List<String> classes;
  final String? lastUpdated;

  ModelStatus({
    required this.totalClasses,
    required this.classes,
    this.lastUpdated,
  });

  factory ModelStatus.fromJson(Map<String, dynamic> json) {
    return ModelStatus(
      totalClasses: json['total_classes'] as int? ?? 0,
      classes: List<String>.from(json['classes'] as List? ?? []),
      lastUpdated: json['last_updated'] as String?,
    );
  }
}

/// Immediate acknowledgement from POST /add_class. Training itself runs in
/// a background thread on the server — this only confirms the photos were
/// received and training has started. Poll [ClassManagementService.getTrainingStatus]
/// for the actual outcome.
class AddClassResult {
  final bool isSuccess;
  final String message;
  final String? className;
  final int? totalImagesReceived;

  AddClassResult({
    required this.isSuccess,
    required this.message,
    this.className,
    this.totalImagesReceived,
  });

  factory AddClassResult.fromJson(Map<String, dynamic> json) {
    final success = json['is_success'] as bool? ?? false;
    return AddClassResult(
      isSuccess: success,
      message: success
          ? (json['message'] as String? ?? '')
          : (json['error_message'] as String? ?? 'Terjadi kesalahan yang tidak diketahui'),
      className: json['class_name'] as String?,
      totalImagesReceived: json['total_images_received'] as int?,
    );
  }

  factory AddClassResult.error(String message) {
    return AddClassResult(isSuccess: false, message: message);
  }
}

/// Final outcome embedded in /training_status once training finishes.
class TrainingResult {
  final String className;
  final double? accuracy;
  final int? totalClasses;
  final List<String> classes;
  final String? note;

  TrainingResult({
    required this.className,
    this.accuracy,
    this.totalClasses,
    this.classes = const [],
    this.note,
  });

  factory TrainingResult.fromJson(Map<String, dynamic> json) {
    return TrainingResult(
      className: json['class_name'] as String? ?? '',
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      totalClasses: json['total_classes'] as int?,
      classes: List<String>.from(json['classes'] as List? ?? []),
      note: json['note'] as String?,
    );
  }
}

/// Result of POST /remove_class.
class RemoveClassResult {
  final bool isSuccess;
  final String message;
  final int? totalClasses;
  final List<String> classes;
  final int? statusCode;

  RemoveClassResult({
    required this.isSuccess,
    required this.message,
    this.totalClasses,
    this.classes = const [],
    this.statusCode,
  });

  /// True when the server responded 404 — the class was never (or no
  /// longer) present in classes.json, e.g. because training failed or was
  /// interrupted before it got that far. There's nothing left server-side
  /// to clean up, so callers can safely treat this like a success.
  bool get notFoundOnServer => statusCode == 404;

  factory RemoveClassResult.fromJson(Map<String, dynamic> json, {int? statusCode}) {
    final success = json['is_success'] as bool? ?? false;
    return RemoveClassResult(
      isSuccess: success,
      message: success
          ? (json['message'] as String? ?? '')
          : (json['error_message'] as String? ?? 'Terjadi kesalahan yang tidak diketahui'),
      totalClasses: json['total_classes'] as int?,
      classes: List<String>.from(json['classes'] as List? ?? []),
      statusCode: statusCode,
    );
  }

  factory RemoveClassResult.error(String message) {
    return RemoveClassResult(isSuccess: false, message: message);
  }
}

/// GET /training_status response.
class TrainingStatus {
  final bool isTraining;
  final String? className;
  final String? currentStep;
  final double progress;
  final String? error;
  final TrainingResult? result;

  TrainingStatus({
    required this.isTraining,
    this.className,
    this.currentStep,
    this.progress = 0.0,
    this.error,
    this.result,
  });

  factory TrainingStatus.fromJson(Map<String, dynamic> json) {
    final resultJson = json['result'] as Map<String, dynamic>?;
    return TrainingStatus(
      isTraining: json['is_training'] as bool? ?? false,
      className: json['class_name'] as String?,
      currentStep: json['current_step'] as String?,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String?,
      result: resultJson != null ? TrainingResult.fromJson(resultJson) : null,
    );
  }
}

class ClassManagementService {
  final String baseUrl;
  final http.Client _client;

  static const int minPhotos = 20;
  static const int maxPhotos = 100;
  static const int maxPhotoSizeBytes = 10 * 1024 * 1024;
  static const int uploadBatchSize = 10;
  static const Duration trainingTimeout = Duration(minutes: 20);

  ClassManagementService({
    this.baseUrl = 'https://hadez.pythonanywhere.com',
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<ModelStatus> getModelStatus() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/model_status'))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return ModelStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Gagal memuat status model: ${response.statusCode}');
    } on SocketException {
      throw Exception('Tidak ada koneksi internet. Pastikan perangkat terhubung ke internet.');
    }
  }

  Future<TrainingStatus> getTrainingStatus() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/training_status'))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return TrainingStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Gagal memuat status training: ${response.statusCode}');
    } on SocketException {
      throw Exception('Tidak ada koneksi internet. Pastikan perangkat terhubung ke internet.');
    }
  }

  /// Removes a dynamically-added class from the model: classes.json entry,
  /// dataset_master.csv rows, its rf_addon_*.pkl, and stored training photos.
  /// The 6 original classes baked into rf_model.pkl are rejected server-side.
  Future<RemoveClassResult> removeClass(String className) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/remove_class'),
        body: {'class_name': className},
      ).timeout(const Duration(seconds: 30));

      try {
        return RemoveClassResult.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
          statusCode: response.statusCode,
        );
      } catch (_) {
        return RemoveClassResult.error('Gagal menghapus kelas: ${response.statusCode}');
      }
    } on SocketException {
      return RemoveClassResult.error('Tidak ada koneksi internet. Pastikan perangkat terhubung ke internet.');
    } catch (e) {
      return RemoveClassResult.error('Error: $e');
    }
  }

  Future<AddClassResult> uploadNewClass({
    required String className,
    required List<File> photos,
    required String description,
    required String symptoms,
    required String treatment,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/add_class'));
      request.fields['class_name'] = className;
      request.fields['description'] = description;
      request.fields['symptoms'] = symptoms;
      request.fields['treatment'] = treatment;

      // Attach files in batches to keep memory usage bounded while
      // building the single multipart request the API expects.
      for (var i = 0; i < photos.length; i += uploadBatchSize) {
        final batch = photos.skip(i).take(uploadBatchSize);
        for (final photo in batch) {
          request.files.add(await http.MultipartFile.fromPath('images', photo.path));
        }
      }

      final streamed = await _client.send(request).timeout(trainingTimeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        return AddClassResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      if (response.statusCode == 500) {
        return AddClassResult.error('Terjadi kesalahan di server. Silakan coba beberapa saat lagi.');
      }
      try {
        return AddClassResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } catch (_) {
        return AddClassResult.error('Gagal menambahkan kelas: ${response.statusCode}');
      }
    } on SocketException {
      return AddClassResult.error('Tidak ada koneksi internet. Pastikan perangkat terhubung ke internet.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return AddClassResult.error(
            'Proses training membutuhkan waktu lebih lama dari biasanya. Silakan cek kembali setelah beberapa menit.');
      }
      return AddClassResult.error('Error: $e');
    }
  }
}
