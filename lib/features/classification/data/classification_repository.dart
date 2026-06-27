import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../domain/classification_result.dart';


abstract class ClassificationRepository {
  Future<ClassificationResult> classifyLeaf(File image);
}

class ClassificationRepositoryImpl implements ClassificationRepository {
  final String baseUrl;
  final http.Client _client;

  ClassificationRepositoryImpl({
    this.baseUrl = 'https://hadez.pythonanywhere.com/predict',
    http.Client? client,
  }) : _client = client ?? http.Client();

  // Crop area yang sesuai dengan overlay frame (80% tengah) sebelum kirim ke backend
  Future<File> _cropToOverlayArea(File imageFile) async {
    final bytes  = await imageFile.readAsBytes();
    final origin = img.decodeImage(bytes);
    if (origin == null) return imageFile;

    final cropSize = (min(origin.width, origin.height) * 0.80).round();
    final x = (origin.width  - cropSize) ~/ 2;
    final y = (origin.height - cropSize) ~/ 2;
    final cropped = img.copyCrop(origin, x: x, y: y, width: cropSize, height: cropSize);

    final outPath = '${imageFile.parent.path}/overlay_crop.jpg';
    final outFile = File(outPath);
    await outFile.writeAsBytes(img.encodeJpg(cropped, quality: 85));
    return outFile;
  }

  @override
  Future<ClassificationResult> classifyLeaf(File imageFile) async {
    try {
      final cropped = await _cropToOverlayArea(imageFile);
      final request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      request.files.add(
        await http.MultipartFile.fromPath('image', cropped.path),
      );

      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ClassificationResult.fromJson(json);
      }
      return ClassificationResult.error(
          'Failed to classify image: ${response.statusCode}');
    } on SocketException {
      return ClassificationResult.error('No internet connection');
    } catch (e) {
      return ClassificationResult.error('Error: $e');
    }
  }
}
