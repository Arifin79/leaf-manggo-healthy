import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../providers/classification_provider.dart';
import '../providers/library_provider.dart';
import 'result_page.dart';

class _CropOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cropSize = size.width * 0.80;
    final left   = (size.width  - cropSize) / 2;
    final top    = (size.height - cropSize) / 2;
    final cropRect = Rect.fromLTWH(left, top, cropSize, cropSize);

    // gelap di luar kotak
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.52);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    // border kotak
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRect(cropRect, border);

    // sudut marker
    const cornerLen = 22.0;
    final corner = Paint()
      ..color = AppTheme.primaryBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final corners = [
      [Offset(left, top + cornerLen), Offset(left, top), Offset(left + cornerLen, top)],
      [Offset(left + cropSize - cornerLen, top), Offset(left + cropSize, top), Offset(left + cropSize, top + cornerLen)],
      [Offset(left, top + cropSize - cornerLen), Offset(left, top + cropSize), Offset(left + cornerLen, top + cropSize)],
      [Offset(left + cropSize - cornerLen, top + cropSize), Offset(left + cropSize, top + cropSize), Offset(left + cropSize, top + cropSize - cornerLen)],
    ];
    for (final pts in corners) {
      final p = Path()..moveTo(pts[0].dx, pts[0].dy)..lineTo(pts[1].dx, pts[1].dy)..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(p, corner);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ImagePreviewPage extends StatelessWidget {
  const ImagePreviewPage({super.key});

  Future<void> _replaceImage(BuildContext context) async {
    final source = await _showSourceSheet(context);
    if (source == null || !context.mounted) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );

    if (picked != null && context.mounted) {
      context.read<ClassificationProvider>().onImageSelected(File(picked.path));
    }
  }

  Future<ImageSource?> _showSourceSheet(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppTheme.primaryBlue),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppTheme.primaryBlue),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _classifyImage(BuildContext context) async {
    final provider = context.read<ClassificationProvider>();
    await provider.classifyImage();

    if (!context.mounted) return;

    if (provider.state == ClassificationState.success) {
      final categoryName = provider.result?.category ?? '';
      final libraryProvider = context.read<LibraryProvider>();

      var matchedItem = libraryProvider.findByTitle(categoryName);
      matchedItem ??= await libraryProvider.findByTitleFromFirestore(categoryName);

      if (context.mounted) {
        provider.setMatchedLibraryItem(matchedItem);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ResultPage()),
        );
      }
    } else if (provider.state == ClassificationState.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Klasifikasi gagal'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18,),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text('Klasifikasi Penyakit Daun'),
        centerTitle: true,
      ),
      body: Consumer<ClassificationProvider>(
        builder: (context, provider, _) {
          final loading = provider.state == ClassificationState.loading;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          provider.selectedImage!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        CustomPaint(painter: _CropOverlayPainter()),
                        const Positioned(
                          bottom: 14,
                          left: 0,
                          right: 0,
                          child: Text(
                            'Dekatkan kamera — daun harus memenuhi kotak',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Klasifikasi Sekarang',
                  isLoading: loading,
                  onPressed: loading ? null : () => _classifyImage(context),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Ganti Gambar',
                  isOutlined: true,
                  onPressed: loading ? null : () => _replaceImage(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
