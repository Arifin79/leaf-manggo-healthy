import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/classification_provider.dart';
import 'image_preview.dart';
import 'library_page.dart';
import 'profile_page.dart';
import 'admin_saved_classification_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);

    if (picked != null && context.mounted) {
      context.read<ClassificationProvider>().onImageSelected(File(picked.path));
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ImagePreviewPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color darkText = Color(0xFF1E2124);
    const Color lightBlueText = Color(0xFF5A89FF);
    const Color cardBg = Color(0xFFF7F8FA);
    const Color primaryBlue = Color(0xFF0084FF);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Klasifikasi Daun',
          style: TextStyle(
            color: darkText,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryBlue.withOpacity(0.5), width: 2),
                ),
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFE5F0FF),
                  child: Icon(Icons.person, size: 20, color: primaryBlue),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KLASIFIKASI PENYAKIT DAUN TANAMAN MANGGA',
              style: TextStyle(
                color: lightBlueText,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  color: darkText,
                  fontSize: 32,
                  height: 1.2,
                  fontFamily: 'serif',
                ),
                children: [
                  TextSpan(
                    text: 'Mulai Identifikasi\n',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: 'Spesimen Anda',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F0FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined, color: primaryBlue, size: 28),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Tambahkan Gambar',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'serif',
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Unggah foto daun yang jelas untuk\nmendapatkan klasifikasi spesies.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => _pickImage(context, ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD6E4FF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      'KLIK UNTUK MEMILIH',
                      style: TextStyle(
                        color: lightBlueText,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.lightbulb_outline, color: primaryBlue, size: 20),
                        SizedBox(height: 16),
                        Text(
                          'TIPS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Gunakan cahaya alami untuk hasil terbaik.',
                          style: TextStyle(
                            fontSize: 13,
                            color: darkText,
                            fontFamily: 'serif',
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.verified_user_outlined, color: primaryBlue, size: 20),
                        SizedBox(height: 16),
                        Text(
                          'AKURASI AI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '98.4% Confidence',
                          style: TextStyle(
                            fontSize: 13,
                            color: darkText,
                            fontFamily: 'serif',
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 20), 
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(context, ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    label: const Text('Kamera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(context, ImageSource.gallery),
                    icon: const Icon(Icons.grid_view_outlined, size: 20),
                    label: const Text('Galeri'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminSavedClassificationPage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.save_outlined, color: Colors.green, size: 32),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hasil Klasifikasi Tersimpan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A2540),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lihat dan kelola hasil klasifikasi Anda',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LibraryPage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.library_books, color: Color(0xFF007BFF), size: 32),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pustaka Penyakit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A2540),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pelajari berbagai jenis penyakit mangga dan solusinya',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
