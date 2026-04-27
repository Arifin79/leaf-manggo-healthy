import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/library_item_data.dart';
import '../providers/library_provider.dart';

class AddDiseasePage extends StatefulWidget {
  final LibraryItemData? itemToEdit;

  const AddDiseasePage({super.key, this.itemToEdit});

  @override
  State<AddDiseasePage> createState() => _AddDiseasePageState();
}

class _AddDiseasePageState extends State<AddDiseasePage> {
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
  File? _selectedImage;
  String? _existingBase64Image;

  @override
  void initState() {
    super.initState();
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

      // Join lists/maps for text fields
      _partsCtrl.text = item.partsAttacked.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      _techCtrl.text = item.technicalControl.join('\n');
    }
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _origNameCtrl, _statusCtrl, _typeCtrl,
        _descCtrl, _subtitleCtrl, _shortDescCtrl, _partsCtrl, _earlyCtrl,
        _chronicCtrl, _techCtrl, _chemInfoCtrl, _chemDoseCtrl, _chemTimeCtrl,
        _spreadCtrl, _adminNoteCtrl]) {
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
        _existingBase64Image = null; // Clear existing if new picked
      });
    }
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

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama penyakit wajib diisi!')));
      return;
    }
    setState(() => _saving = true);
    
    String? base64Image = _existingBase64Image;

    // Process new image to Base64
    if (_selectedImage != null) {
      try {
        final bytes = await _selectedImage!.readAsBytes();
        img.Image? originalImage = img.decodeImage(bytes);
        if (originalImage != null) {
          img.Image resizedImage = img.copyResize(originalImage, width: 400);
          List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 70);
          base64Image = base64Encode(compressedBytes);
        }
      } catch (e) {
        debugPrint("Error processing image: $e");
      }
    }

    final item = LibraryItemData(
      id: widget.itemToEdit?.id,
      title: _titleCtrl.text.trim(),
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
    );
    
    final bool ok;
    if (widget.itemToEdit != null && widget.itemToEdit!.id != null) {
      ok = await context.read<LibraryProvider>().updateItem(widget.itemToEdit!.id!, item);
    } else {
      ok = await context.read<LibraryProvider>().addItem(item);
    }

    setState(() => _saving = false);
    if (mounted) {
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.itemToEdit != null ? 'Data berhasil diperbarui!' : 'Penyakit baru berhasil disimpan!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF007BFF);
    const Color darkBlueText = Color(0xFF0A2540);
    
    Uint8List? existingBytes;
    if (_existingBase64Image != null && _existingBase64Image!.isNotEmpty) {
      try {
        existingBytes = base64Decode(_existingBase64Image!);
      } catch (_) {}
    }

    final isEditing = widget.itemToEdit != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkBlueText), onPressed: () => Navigator.pop(context)),
        title: Text(isEditing ? 'Edit Penyakit' : 'Tambah Penyakit Baru', style: const TextStyle(color: darkBlueText, fontSize: 18, fontWeight: FontWeight.bold)),
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
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                  : (existingBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(existingBytes, fit: BoxFit.cover),
                        )
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
          _field('Nama Penyakit *', 'Misal: Sooty Mould', _titleCtrl),
          _field('Subtitle', 'Misal: JAMUR • MELIOLA', _subtitleCtrl),
          _field('Deskripsi Singkat', 'Misal: Lapisan hitam...', _shortDescCtrl),
          _field('Nama Latin/Asli', 'Misal: (Penyakit Kapang Jelaga)', _origNameCtrl),
          _field('Status Penyakit', 'Misal: Penyakit Sekunder', _statusCtrl),
          _field('Tipe Patogen', 'Misal: Fungal Pathogen', _typeCtrl),
          _field('Deskripsi Lengkap', 'Jelaskan secara rinci...', _descCtrl, ml: 4),
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
          const SizedBox(height: 48),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(isEditing ? 'Simpan Perubahan' : 'Simpan Penyakit', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          )),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 16),
    child: Text(t, style: const TextStyle(color: Color(0xFF0A2540), fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif')));

  Widget _field(String label, String hint, TextEditingController c, {int ml = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Color(0xFF0A2540), fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      TextField(controller: c, maxLines: ml, decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true, fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF007BFF), width: 2)),
      )),
    ]),
  );
}
