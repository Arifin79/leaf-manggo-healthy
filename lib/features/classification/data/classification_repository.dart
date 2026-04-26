import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/classification_result.dart';


abstract class ClassificationRepository {
  Future<ClassificationResult> classifyLeaf(File image);
}

class ClassificationRepositoryImpl implements ClassificationRepository {
  final String baseUrl;
  final http.Client _client;

  ClassificationRepositoryImpl({
    this.baseUrl = 'https://filosus-corymbed-zella.ngrok-free.dev/predict',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<ClassificationResult> classifyLeaf(File imageFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path)
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