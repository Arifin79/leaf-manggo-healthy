import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../../data/class_management_service.dart';
import '../models/library_item_data.dart';
import '../providers/auth_provider.dart';
import '../providers/class_management_provider.dart';
import '../providers/library_provider.dart';

/// Single form for the whole disease-library lifecycle: adding a brand-new
/// class (trains the Flask model from sample photos), editing an existing
/// entry's metadata, and topping up an already-recognized class with more
/// photos to retrain it. Which of these happens is decided at submit time
/// by whether the class name is already active in the model and whether
/// any sample photos were added — the admin doesn't have to pick between
/// separate "Tambah Data Pustaka" / "Tambah Kelas Baru" menus anymore.
class DiseaseFormPage extends StatefulWidget {
  final LibraryItemData? itemToEdit;

  const DiseaseFormPage({super.key, this.itemToEdit});

  @override
  State<DiseaseFormPage> createState() => _DiseaseFormPageState();
}

class _DiseaseFormPageState extends State<DiseaseFormPage> {
  static const Color primaryBlue = Color(0xFF007BFF);
  static const Color darkBlueText = Color(0xFF0A2540);

  final _titleCtrl = TextEditingController();
  final _origNameCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _shortDescCtrl = TextEditingController();
  final _partsCtrl = TextEditingController();
  final _earlyCtrl = TextEditingController();
  final _chronicCtrl = TextEditingController();
  final _techCtrl = TextEditingController();
  final _chemInfoCtrl = TextEditingController();
  final _chemDoseCtrl = TextEditingController();
  final _chemTimeCtrl = TextEditingController();
  final _spreadCtrl = TextEditingController();
  final _adminNoteCtrl = TextEditingController();

  bool _saving = false;
  bool _checkingName = false;
  String? _nameError;

  File? _selectedImage;
  String? _existingBase64Image;

  final List<File> _photos = [];

  bool get _isEditing => widget.itemToEdit != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassManagementProvider>().fetchModelStatus();
    });

    if (widget.itemToEdit != null) {
      final item = widget.itemToEdit!;
      _titleCtrl.text = item.title;
      _origNameCtrl.text = item.originalName;
      _statusCtrl.text = item.status;
      _typeCtrl.text = item.type;
      _descCtrl.text = item.description;
      _subtitleCtrl.text = item.subtitle;
      _shortDescCtrl.text = item.shortDescription;
      _earlyCtrl.text = item.earlyPhase;
      _chronicCtrl.text = item.chronicPhase;
      _chemInfoCtrl.text = item.chemicalControlInfo;
      _chemDoseCtrl.text = item.chemicalDose;
      _chemTimeCtrl.text = item.chemicalTime;
      _spreadCtrl.text = item.spreadWarning;
      _adminNoteCtrl.text = item.adminNote ?? '';
      _existingBase64Image = item.imageBase64;
      _partsCtrl.text = item.partsAttacked.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      _techCtrl.text = item.technicalControl.join('\n');
    }
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl, _origNameCtrl, _statusCtrl, _typeCtrl, _descCtrl,
      _subtitleCtrl, _shortDescCtrl, _partsCtrl, _earlyCtrl, _chronicCtrl,
      _techCtrl, _chemInfoCtrl, _chemDoseCtrl, _chemTimeCtrl, _spreadCtrl,
      _adminNoteCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _existingBase64Image = null;
      });
    }
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
    setState(() => _photos.removeAt(index));
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

  bool get _canSubmit =>
      _titleCtrl.text.trim().isNotEmpty &&
      _descCtrl.text.trim().isNotEmpty &&
      !_checkingName &&
      !_saving;

  Future<void> _submit() async {
    final classProvider = context.read<ClassManagementProvider>();
    final libraryProvider = context.read<LibraryProvider>();
    final authProvider = context.read<AppAuthProvider>();

    final title = _titleCtrl.text.trim();
    final titleChanged = !_isEditing || widget.itemToEdit!.title.trim().toLowerCase() != title.toLowerCase();

    setState(() {
      _checkingName = true;
      _nameError = null;
    });

    bool isRecognized;
    if (titleChanged) {
      final others = libraryProvider.items.where((i) => i.id != widget.itemToEdit?.id).toList();
      bool isDuplicate;
      try {
        isDuplicate = await classProvider.isDuplicateClassName(title, others);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _checkingName = false;
          _nameError = 'Tidak bisa memverifikasi nama kelas. Periksa koneksi internet dan coba lagi.';
        });
        return;
      }
      if (isDuplicate) {
        if (!mounted) return;
        setState(() {
          _checkingName = false;
          _nameError = "Nama penyakit '$title' sudah ada dalam sistem.";
        });
        return;
      }
      isRecognized = classProvider.isClassActive(title);
    } else {
      isRecognized = classProvider.isClassActive(title) || (widget.itemToEdit?.isActive ?? false);
    }

    if (!mounted) return;
    setState(() => _checkingName = false);

    if (!isRecognized && _photos.length < ClassManagementService.minPhotos) {
      setState(() => _nameError =
          "Kelas ini belum dikenal model — upload minimal ${ClassManagementService.minPhotos} foto untuk melatihnya.");
      return;
    }
    if (isRecognized && _photos.isNotEmpty && _photos.length < ClassManagementService.retrainMinPhotos) {
      setState(() => _nameError =
          'Untuk melatih ulang, tambahkan minimal ${ClassManagementService.retrainMinPhotos} foto (atau kosongkan agar tidak melatih ulang).');
      return;
    }

    String? base64Image = _existingBase64Image;
    if (_selectedImage != null) {
      try {
        final bytes = await _selectedImage!.readAsBytes();
        final originalImage = img.decodeImage(bytes);
        if (originalImage != null) {
          final resizedImage = img.copyResize(originalImage, width: 400);
          final compressedBytes = img.encodeJpg(resizedImage, quality: 70);
          base64Image = base64Encode(compressedBytes);
        }
      } catch (e) {
        debugPrint('Error processing image: $e');
      }
    }

    if (!mounted) return;

    final libraryData = LibraryItemData(
      id: widget.itemToEdit?.id,
      title: title,
      originalName: _origNameCtrl.text.trim(),
      status: _statusCtrl.text.trim(),
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
      adminNote: _adminNoteCtrl.text.trim(),
      imageBase64: base64Image,
      isActive: isRecognized,
      addedBy: widget.itemToEdit?.addedBy,
    );

    if (!isRecognized) {
      // Brand new to the model (or an existing-but-never-trained entry
      // that's finally getting its training photos) — needs full training.
      _showProgressSheet();
      final ok = await classProvider.submitNewClass(
        libraryData: libraryData,
        photos: _photos,
        adminUid: authProvider.currentUser?.uid ?? '',
        existingId: widget.itemToEdit?.id,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
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
      return;
    }

    if (_photos.isNotEmpty) {
      _showProgressSheet();
      final retrainOk = await classProvider.submitRetrain(className: title, newPhotos: _photos);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (!retrainOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(classProvider.errorMessage ?? 'Gagal melatih ulang kelas.')),
        );
        classProvider.reset();
        return;
      }
      classProvider.reset();
    }

    setState(() => _saving = true);
    final bool ok;
    if (_isEditing) {
      ok = await libraryProvider.updateItem(widget.itemToEdit!.id!, libraryData);
    } else {
      ok = await libraryProvider.addItem(libraryData);
    }
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Data berhasil diperbarui!' : 'Penyakit baru berhasil disimpan!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
      );
    }
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
                  const Text('Memproses Model', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlueText)),
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
    Uint8List? existingBytes;
    if (_existingBase64Image != null && _existingBase64Image!.isNotEmpty) {
      try {
        existingBytes = base64Decode(_existingBase64Image!);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkBlueText), onPressed: () => Navigator.pop(context)),
        title: Text(_isEditing ? 'Edit Penyakit' : 'Tambah Penyakit', style: const TextStyle(color: darkBlueText, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _section('Gambar Referensi'),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              ),
              child: _selectedImage != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(_selectedImage!, fit: BoxFit.cover))
                  : (existingBytes != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(existingBytes, fit: BoxFit.cover))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('Pilih Gambar', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        )),
            ),
          ),
          const SizedBox(height: 24),
          _section('Informasi Dasar'),
          _field('Nama Penyakit *', 'Misal: Sooty Mould', _titleCtrl, error: _nameError, onChanged: (_) => setState(() {})),
          _field('Subtitle', 'Misal: JAMUR • MELIOLA', _subtitleCtrl),
          _field('Deskripsi Singkat', 'Misal: Lapisan hitam...', _shortDescCtrl),
          _field('Nama Latin/Asli', 'Misal: (Penyakit Kapang Jelaga)', _origNameCtrl),
          _field('Status Penyakit', 'Misal: Penyakit Sekunder', _statusCtrl),
          _field('Tipe Patogen', 'Misal: Fungal Pathogen', _typeCtrl),
          _field('Deskripsi Lengkap *', 'Jelaskan secara rinci...', _descCtrl, ml: 4, onChanged: (_) => setState(() {})),
          const SizedBox(height: 24),
          _section('Gejala & Bagian Diserang'),
          _field('Bagian Diserang', 'Format: Daun: gejala, Ranting: gejala', _partsCtrl, ml: 3),
          _field('Gejala Fase Awal', 'Misal: Muncul bercak hitam...', _earlyCtrl, ml: 3),
          _field('Gejala Fase Kronis', 'Misal: Lapisan jelaga menutupi...', _chronicCtrl, ml: 3),
          const SizedBox(height: 24),
          _section('Protokol Pemulihan'),
          _field('Kultur Teknis (per baris)', '1. Kendalikan populasi\n2. Pangkas', _techCtrl, ml: 3),
          _field('Info Pengendalian Kimiawi', 'Gunakan fungisida...', _chemInfoCtrl, ml: 2),
          _field('Dosis Obat', '±1,5 g/l air', _chemDoseCtrl),
          _field('Waktu Aplikasi', 'Saat populasi terdeteksi', _chemTimeCtrl),
          const SizedBox(height: 24),
          _section('Peringatan Penyebaran'),
          _field('Catatan Peringatan', 'Tangani sumber masalah...', _spreadCtrl, ml: 2),
          const SizedBox(height: 24),
          _section('Catatan Khusus Admin (Opsional)'),
          _field('Catatan Khusus', 'Hanya admin yang bisa melihat catatan ini...', _adminNoteCtrl, ml: 3),
          const SizedBox(height: 24),
          _section('Foto Sampel Penyakit'),
          Text(
            'Wajib minimal ${ClassManagementService.minPhotos} foto kalau ini kelas baru yang belum dikenal model. '
            'Kalau kelasnya sudah dikenal model, foto ini opsional — isi minimal ${ClassManagementService.retrainMinPhotos} '
            'kalau mau melatih ulang model dengan data tambahan, atau kosongkan untuk sekadar update info.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            '${_photos.length} foto dipilih',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
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
              return Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_photos[index], width: double.infinity, height: double.infinity, fit: BoxFit.cover),
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
              ]);
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
              child: (_saving || _checkingName)
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEditing ? 'Simpan Perubahan' : 'Simpan Penyakit', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            onChanged: onChanged,
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
