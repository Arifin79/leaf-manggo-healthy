import 'dart:io';
import 'package:image/image.dart' as img;

class LeafValidationResult {
  final bool isValid;
  final double leafPixelPercentage;
  final String? message;

  const LeafValidationResult({
    required this.isValid,
    required this.leafPixelPercentage,
    this.message,
  });
}

class _Hsv {
  final double h;
  final double s;
  final double v;

  const _Hsv(this.h, this.s, this.v);
}

/// Cheap client-side sanity check that a photo plausibly shows a leaf
/// before spending a round-trip on the Flask model: resizes to 100x100,
/// converts every pixel to HSV, and checks what fraction falls into a
/// leaf-like color bucket (green, brown/yellow, dark, or bright/powdery).
class LeafValidatorService {
  static const int _resizeDim = 100;
  static const double _minLeafPixelRatio = 0.40;

  Future<LeafValidationResult> validateLeafImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      return const LeafValidationResult(
        isValid: false,
        leafPixelPercentage: 0.0,
        message: 'Foto tidak terdeteksi sebagai daun mangga. '
            'Pastikan kamera mengarah ke daun dengan pencahayaan yang cukup.',
      );
    }

    final resized = img.copyResize(decoded, width: _resizeDim, height: _resizeDim);
    final totalPixels = resized.width * resized.height;

    var leafPixelCount = 0;
    for (final pixel in resized) {
      final hsv = _rgbToHsv(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());
      if (_isLeafColor(hsv)) leafPixelCount++;
    }

    final percentage = totalPixels == 0 ? 0.0 : leafPixelCount / totalPixels;
    final isValid = percentage >= _minLeafPixelRatio;

    return LeafValidationResult(
      isValid: isValid,
      leafPixelPercentage: percentage,
      message: isValid
          ? null
          : 'Foto tidak terdeteksi sebagai daun mangga. '
              'Pastikan kamera mengarah ke daun dengan pencahayaan yang cukup.',
    );
  }

  bool _isLeafColor(_Hsv hsv) {
    final h = hsv.h;
    final s = hsv.s;
    final v = hsv.v;

    // Hijau (daun sehat)
    if (h >= 35 && h <= 85 && s >= 30 && s <= 255 && v >= 30 && v <= 255) {
      return true;
    }
    // Cokelat/kuning (daun sakit)
    if (h >= 15 && h <= 35 && s >= 20 && s <= 255 && v >= 30 && v <= 255) {
      return true;
    }
    // Hitam/gelap (Sooty Mould) — apapun H dan S-nya
    if (v >= 0 && v <= 80) {
      return true;
    }
    // Putih/terang (Powdery Mildew)
    if (s >= 0 && s <= 40 && v >= 180 && v <= 255) {
      return true;
    }
    return false;
  }

  /// Manual RGB->HSV conversion, scaled to OpenCV's ranges (H: 0-179,
  /// S/V: 0-255) so the thresholds line up with how the Flask side would
  /// see the same pixel via cv2.cvtColor(..., COLOR_BGR2HSV).
  _Hsv _rgbToHsv(int r, int g, int b) {
    final rf = r / 255.0;
    final gf = g / 255.0;
    final bf = b / 255.0;

    final maxV = [rf, gf, bf].reduce((a, b) => a > b ? a : b);
    final minV = [rf, gf, bf].reduce((a, b) => a < b ? a : b);
    final delta = maxV - minV;

    double hue;
    if (delta == 0) {
      hue = 0;
    } else if (maxV == rf) {
      hue = 60 * (((gf - bf) / delta) % 6);
    } else if (maxV == gf) {
      hue = 60 * (((bf - rf) / delta) + 2);
    } else {
      hue = 60 * (((rf - gf) / delta) + 4);
    }
    if (hue < 0) hue += 360;

    final saturation = maxV > 0 ? delta / maxV : 0.0;
    final value = maxV;

    return _Hsv(hue / 2, saturation * 255, value * 255);
  }
}
