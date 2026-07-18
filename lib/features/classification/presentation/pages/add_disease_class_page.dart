import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../../data/class_management_service.dart';
import '../models/library_item_data.dart';
import '../providers/class_management_provider.dart';
import '../providers/library_provider.dart';
import '../providers/auth_provider.dart';

/// Adds a brand-new disease class: trains the Flask model from sample
/// photos AND fills in the full library record in one form, so admins
/// don't have to do a second pass through "Tambah Data Pustaka" afterwards.
class AddDiseaseClassPage extends StatefulWidget {
  const AddDiseaseClassPage({super.key});

  @override
  State<AddDiseaseClassPage> createState() => _AddDiseaseClassPageState();
}

class _AddDiseaseClassPageState extends State<AddDiseaseClassPage> {
  static const Color primaryBlue = Color(0xFF007BFF);
  static const Color darkBlueText = Color(0xFF0A2540);

  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _shortDescCtrl = TextEditingController();
  final _origNameCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _partsCtrl = TextEditingController();
  final _earlyCtrl = TextEditingController();
  final _chronicCtrl = TextEditingController();
  final _techCtrl = TextEditingController();
  final _chemInfoCtrl = TextEditingController();
  final _chemDoseCtrl = TextEditingController();
  final _chemTimeCtrl = TextEditingController();
  final _spreadCtrl = TextEditingController();

  final List<File> _photos = [];
  int _referenceIndex = 0;
  bool _checkingName = false;
  String? _nameError;

  @override
  void dispose() {
    for (final c in [
      _titleCtrl, _subtitleCtrl, _shortDescCtrl, _origNameCtrl, _statusCtrl,
      _typeCtrl, _descCtrl, _partsCtrl, _earlyCtrl, _chronicCtrl, _techCtrl,
      _chemInfoCtrl, _chemDoseCtrl, _chemTimeCtrl, _spreadCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _parseParts(String t) {
    final m = <String, String>{};
    if (t.trim().isEmpty) return m;
    for (final p in t.split(',')) {
      final kv = p.trim().split(':');
      if (kv.length == 2) m[kv[0].trim()] = kv[1].trim();
    }
    return m;
  }

  Future<void> _pickPhotos() async {
    final remainingSlots = ClassManagementService.maxPhotos - _photos.length;
    if (remainingSlots <= 0) return;

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty) return;

    final accepted = <File>[];
    var oversized = 0;
    for (final xfile in picked.take(remainingSlots)) {
      final file = File(xfile.path);
      final size = await file.length();
      if (size > ClassManagementService.maxPhotoSizeBytes) {
        oversized++;
        continue;
      }
      accepted.add(file);
    }

    setState(() => _photos.addAll(accepted));

    if (oversized > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$oversized foto dilewati karena ukurannya melebihi 10MB')),
      );
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      if (_photos.isEmpty) {
        _referenceIndex = 0;
      } else if (_referenceIndex == index) {
        _referenceIndex = 0;
      } else if (_referenceIndex > index) {
        _referenceIndex -= 1;
      }
    });
  }

  // Flask requires description/symptoms/treatment to be non-empty, derived
  // from the richer fields below — so those need at least one source filled.
  bool get _canSubmit =>
      _titleCtrl.text.trim().isNotEmpty &&
      _descCtrl.text.trim().isNotEmpty &&
      (_earlyCtrl.text.trim().isNotEmpty || _chronicCtrl.text.trim().isNotEmpty) &&
      (_techCtrl.text.trim().isNotEmpty || _chemInfoCtrl.text.trim().isNotEmpty) &&
      _photos.length >= ClassManagementService.minPhotos &&
      !_checkingName;

  Future<void> _submit() async {
    final classProvider = context.read<ClassManagementProvider>();
    final libraryProvider = context.read<LibraryProvider>();
    final authProvider = context.read<AppAuthProvider>();

    setState(() {
      _checkingName = true;
      _nameError = null;
    });

    final name = _titleCtrl.text.trim();
    bool isDuplicate;
    try {
      isDuplicate = await classProvider.isDuplicateClassName(name, libraryProvider.items);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingName = false;
        _nameError = 'Tidak bisa memverifikasi nama kelas. Periksa koneksi internet dan coba lagi.';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _checkingName = false);

    if (isDuplicate) {
      setState(() => _nameError = "Nama penyakit '$name' sudah ada dalam sistem.");
      return;
    }

    if (!mounted) return;
    _showProgressSheet();

    String? referenceImageBase64;
    try {
      final bytes = await _photos[_referenceIndex].readAsBytes();
      final originalImage = img.decodeImage(bytes);
      if (originalImage != null) {
        final resizedImage = img.copyResize(originalImage, width: 400);
        final compressedBytes = img.encodeJpg(resizedImage, quality: 70);
        referenceImageBase64 = base64Encode(compressedBytes);
      }
    } catch (e) {
      debugPrint('Error processing reference image: $e');
    }

    final libraryData = LibraryItemData(
      title: name,
      originalName: _origNameCtrl.text.trim(),
      status: _statusCtrl.text.trim().isEmpty ? 'Kelas Baru' : _statusCtrl.text.trim(),
      type: _typeCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      subtitle: _subtitleCtrl.text.trim(),
      shortDescription: _shortDescCtrl.text.trim(),
      partsAttacked: _parseParts(_partsCtrl.text),
      earlyPhase: _earlyCtrl.text.trim(),
      chronicPhase: _chronicCtrl.text.trim(),
      technicalControl: _techCtrl.text.trim().split('\n').where((s) => s.trim().isNotEmpty).toList(),
      chemicalControlInfo: _chemInfoCtrl.text.trim(),
      chemicalDose: _chemDoseCtrl.text.trim(),
      chemicalTime: _chemTimeCtrl.text.trim(),
      spreadWarning: _spreadCtrl.text.trim(),
      imageBase64: referenceImageBase64,
    );

    final ok = await classProvider.submitNewClass(
      libraryData: libraryData,
      photos: _photos,
      adminUid: authProvider.currentUser?.uid ?? '',
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close progress sheet

    if (ok) {
      libraryProvider.loadItems();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kelas penyakit baru berhasil ditambahkan dan model sedang aktif!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(classProvider.errorMessage ?? 'Gagal menambahkan kelas penyakit.')),
      );
    }
    classProvider.reset();
  }

  void _showProgressSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Consumer<ClassManagementProvider>(
          builder: (ctx, provider, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Memproses Kelas Baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlueText)),
                  const SizedBox(height: 8),
                  Text(
                    'Sistem sedang memproses dan melatih ulang model...\nHarap tunggu, proses ini membutuhkan beberapa menit.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  LinearProgressIndicator(
                    value: provider.uploadProgress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(primaryBlue),
                  ),
                  const SizedBox(height: 24),
                  _step('Mengunggah foto ke server', provider.uploadProgress >= 0.1),
                  _step('Mengekstraksi fitur gambar', provider.uploadProgress >= 0.4),
                  _step('Melatih ulang model', provider.uploadProgress >= 0.4 && provider.isTraining || provider.uploadProgress >= 0.9),
                  _step('Menyimpan data penyakit', provider.uploadProgress >= 0.9),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _step(String label, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: done ? Colors.green : Colors.grey.shade400),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 13, color: done ? darkBlueText : Colors.grey.shade500, fontWeight: done ? FontWeight.w600 : FontWeight.normal)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkBlueText), onPressed: () => Navigator.pop(context)),
        title: const Text('Tambah Penyakit Baru', style: TextStyle(color: darkBlueText, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _section('Informasi Dasar'),
          _field('Nama Penyakit *', 'Misal: Bacterial Canker', _titleCtrl, error: _nameError, onChanged: (_) => setState(() {})),
          _field('Subtitle', 'Misal: JAMUR • MELIOLA', _subtitleCtrl),
          _field('Deskripsi Singkat', 'Misal: Lapisan hitam...', _shortDescCtrl),
          _field('Nama Latin/Asli', 'Misal: (Penyakit Kapang Jelaga)', _origNameCtrl),
          _field('Status Penyakit', 'Misal: Penyakit Sekunder', _statusCtrl),
          _field('Tipe Patogen', 'Misal: Fungal Pathogen', _typeCtrl),
          _field('Deskripsi Lengkap *', 'Jelaskan secara rinci...', _descCtrl, ml: 4),
          const SizedBox(height: 24),
          _section('Gejala & Bagian Diserang'),
          _field('Bagian Diserang', 'Format: Daun: gejala, Ranting: gejala', _partsCtrl, ml: 3),
          _field('Gejala Fase Awal *', 'Misal: Muncul bercak hitam...', _earlyCtrl, ml: 3),
          _field('Gejala Fase Kronis *', 'Misal: Lapisan jelaga menutupi...', _chronicCtrl, ml: 3),
          Text('* Isi minimal salah satu dari Fase Awal / Fase Kronis', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          const SizedBox(height: 24),
          _section('Protokol Pemulihan'),
          _field('Kultur Teknis (per baris) *', '1. Kendalikan populasi\n2. Pangkas', _techCtrl, ml: 3),
          _field('Info Pengendalian Kimiawi *', 'Gunakan fungisida...', _chemInfoCtrl, ml: 2),
          Text('* Isi minimal salah satu dari Kultur Teknis / Info Kimiawi', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          const SizedBox(height: 16),
          _field('Dosis Obat', '±1,5 g/l air', _chemDoseCtrl),
          _field('Waktu Aplikasi', 'Saat populasi terdeteksi', _chemTimeCtrl),
          const SizedBox(height: 24),
          _section('Peringatan Penyebaran'),
          _field('Catatan Peringatan', 'Tangani sumber masalah...', _spreadCtrl, ml: 2),
          const SizedBox(height: 24),
          _section('Foto Sampel Penyakit'),
          Text(
            '${_photos.length}/${ClassManagementService.minPhotos} foto — butuh minimal ${ClassManagementService.minPhotos} foto (maks ${ClassManagementService.maxPhotos})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _photos.length >= ClassManagementService.minPhotos ? Colors.green.shade700 : Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 12),
          if (_photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Ketuk salah satu foto untuk jadikan Gambar Referensi pustaka (ditandai bintang)',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: _photos.length + 1,
            itemBuilder: (context, index) {
              if (index == _photos.length) {
                final full = _photos.length >= ClassManagementService.maxPhotos;
                return GestureDetector(
                  onTap: full ? null : _pickPhotos,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Icon(Icons.add_photo_alternate_outlined, color: full ? Colors.grey.shade300 : Colors.grey.shade500),
                  ),
                );
              }
              final isReference = index == _referenceIndex;
              return GestureDetector(
                onTap: () => setState(() => _referenceIndex = index),
                child: Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        border: isReference ? Border.all(color: primaryBlue, width: 3) : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.file(_photos[index], width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                    ),
                  ),
                  if (isReference)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: primaryBlue, shape: BoxShape.circle),
                        child: const Icon(Icons.star, size: 14, color: Colors.white),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removePhoto(index),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ]),
              );
            },
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _checkingName
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Latih & Simpan Kelas Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(t, style: const TextStyle(color: darkBlueText, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif')),
      );

  Widget _field(String label, String hint, TextEditingController c,
          {int ml = 1, String? error, ValueChanged<String>? onChanged}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: darkBlueText, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: c,
            maxLines: ml,
            onChanged: onChanged ?? (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Colors.grey.shade50,
              errorText: error,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
            ),
          ),
        ]),
      );
}
