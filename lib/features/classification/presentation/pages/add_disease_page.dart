import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/library_item_data.dart';
import '../providers/library_provider.dart';

class AddDiseasePage extends StatefulWidget {
  const AddDiseasePage({super.key});

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
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_titleCtrl, _origNameCtrl, _statusCtrl, _typeCtrl,
        _descCtrl, _subtitleCtrl, _shortDescCtrl, _partsCtrl, _earlyCtrl,
        _chronicCtrl, _techCtrl, _chemInfoCtrl, _chemDoseCtrl, _chemTimeCtrl,
        _spreadCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _parseParts(String t) {
    final m = <String, String>{};
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
    final item = LibraryItemData(
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
    );
    final ok = await context.read<LibraryProvider>().addItem(item);
    setState(() => _saving = false);
    if (mounted) {
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Penyakit baru berhasil disimpan!')));
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: darkBlueText), onPressed: () => Navigator.pop(context)),
        title: const Text('Tambah Penyakit Baru', style: TextStyle(color: darkBlueText, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          const SizedBox(height: 48),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Simpan Penyakit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
