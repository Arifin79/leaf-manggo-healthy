import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../providers/classification_provider.dart';
import '../models/library_item_data.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF324B36);
    const Color lightGreenBg = Color(0xFFF6F9F4);
    const Color lightBlueText = Color(0xFF6E8DF1);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: darkGreen), onPressed: () => Navigator.pop(context)),
        title: const Text('LAPORAN DIAGNOSIS', style: TextStyle(color: darkGreen, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: false,
      ),
      body: Consumer<ClassificationProvider>(
        builder: (context, provider, _) {
          final result = provider.result;
          final image = provider.selectedImage;
          final int percent = result?.confidencePercent ?? 0;
          final String categoryName = result?.category ?? 'Unknown';
          final LibraryItemData? diseaseData = provider.matchedLibraryItem;

          final bool isHealthy = categoryName.toLowerCase().contains('sehat') || categoryName.toLowerCase() == 'healthy';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Image Card
              Container(
                width: double.infinity, height: 300,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: Colors.black),
                child: Stack(children: [
                  if (image != null)
                    ClipRRect(borderRadius: BorderRadius.circular(24),
                      child: Image.file(image, width: double.infinity, height: double.infinity, fit: BoxFit.cover)),
                  Positioned(bottom: 16, left: 16, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: isHealthy ? Colors.green : Colors.blue, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('$percent% Confidence', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ]),
                  )),
                ]),
              ),
              const SizedBox(height: 24),
              Text(isHealthy ? 'LAPORAN ANALISIS KESEHATAN' : 'LAPORAN ANALISIS DIAGNOSIS',
                style: const TextStyle(color: lightBlueText, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              RichText(text: TextSpan(style: const TextStyle(color: darkGreen, fontSize: 28, height: 1.2), children: [
                TextSpan(text: isHealthy ? 'Status Daun:\n' : 'Infeksi Terdeteksi:\n', style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'serif')),
                TextSpan(text: categoryName, style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, fontFamily: 'serif')),
              ])),
              if (diseaseData != null) ...[
                const SizedBox(height: 4),
                Text(diseaseData.originalName, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              // Description from Firestore
              Text(
                diseaseData?.description ?? 'Deskripsi penyakit tidak tersedia.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),

              // Akurasi Card
              Container(
                width: double.infinity, padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: lightGreenBg, borderRadius: BorderRadius.circular(24)),
                child: Column(children: [
                  const Text('AKURASI DIAGNOSIS', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  const SizedBox(height: 20),
                  CircularPercentIndicator(
                    radius: 65, lineWidth: 10, percent: percent / 100,
                    center: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('$percent%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
                      const Text('COCOK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey)),
                    ]),
                    progressColor: isHealthy ? Colors.green : Colors.blue,
                    backgroundColor: (isHealthy ? Colors.green : Colors.blue).withOpacity(0.1),
                    circularStrokeCap: CircularStrokeCap.round, animation: true, animationDuration: 800,
                  ),
                  const SizedBox(height: 20),
                  Text(percent >= 90 ? 'Peringkat Presisi: Sangat Baik' : percent >= 70 ? 'Peringkat Presisi: Baik' : 'Peringkat Presisi: Cukup',
                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(isHealthy ? 'Daun dalam kondisi sehat dan normal' : 'Konsisten dengan profil patogen tingkat keyakinan tinggi',
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ]),
              ),
              const SizedBox(height: 32),

              // Disease detail sections from Firestore
              if (diseaseData != null) ...[
                // Bagian Diserang
                if (diseaseData.partsAttacked.isNotEmpty) ...[
                  _sectionHeader(isHealthy ? 'Kondisi Tanaman' : 'Bagian Diserang', Icons.coronavirus_outlined),
                  const SizedBox(height: 12),
                  ...diseaseData.partsAttacked.entries.map((e) => _bulletPoint('${e.key}: ${e.value}')),
                  const SizedBox(height: 24),
                ],

                // Gejala Serangan
                if (diseaseData.earlyPhase.isNotEmpty || diseaseData.chronicPhase.isNotEmpty) ...[
                  _sectionHeader('Gejala Serangan', Icons.visibility_outlined),
                  const SizedBox(height: 12),
                  if (diseaseData.earlyPhase.isNotEmpty) ...[
                    _phaseTag('Fase Awal', Colors.blue.shade100, Colors.blue.shade800),
                    const SizedBox(height: 6),
                    Text(diseaseData.earlyPhase, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.5)),
                    const SizedBox(height: 12),
                  ],
                  if (diseaseData.chronicPhase.isNotEmpty) ...[
                    _phaseTag('Fase Kronis', Colors.orange.shade100, Colors.orange.shade800),
                    const SizedBox(height: 6),
                    Text(diseaseData.chronicPhase, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.5)),
                  ],
                  const SizedBox(height: 24),
                ],

                // Rekomendasi / Pengendalian
                const Text('Rekomendasi Ahli', style: TextStyle(color: darkGreen, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'serif')),
                const SizedBox(height: 4),
                Text(isHealthy ? 'Tips perawatan untuk menjaga kesehatan tanaman' : 'Langkah penanganan yang direkomendasikan',
                  style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 16),

                // Kultur Teknis
                if (diseaseData.technicalControl.isNotEmpty)
                  ...diseaseData.technicalControl.map((step) => _recCard(
                    icon: Icons.eco_outlined, title: 'Kultur Teknis', description: step)),

                // Kimiawi
                if (diseaseData.chemicalControlInfo.isNotEmpty)
                  _recCard(icon: Icons.science_outlined, title: 'Pengendalian Kimiawi', description: diseaseData.chemicalControlInfo),

                if (diseaseData.chemicalDose.isNotEmpty)
                  _recCard(icon: Icons.local_pharmacy_outlined, title: 'Dosis', description: diseaseData.chemicalDose),

                if (diseaseData.chemicalTime.isNotEmpty)
                  _recCard(icon: Icons.access_time, title: 'Waktu Aplikasi', description: diseaseData.chemicalTime),

                // Peringatan Penyebaran
                if (diseaseData.spreadWarning.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFF0D253F), borderRadius: BorderRadius.circular(20)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.air_outlined, color: Colors.white, size: 24)),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Peringatan Penyebaran', style: TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(diseaseData.spreadWarning, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, height: 1.5)),
                      ])),
                    ]),
                  ),
                ],
              ] else ...[
                // Fallback if no Firestore match
                const Text('Rekomendasi Ahli', style: TextStyle(color: darkGreen, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'serif')),
                const SizedBox(height: 16),
                _recCard(icon: Icons.content_cut_rounded, title: 'Sanitasi Bagian Terinfeksi', description: 'Bersihkan bagian tanaman yang terinfeksi dan buang jauh dari area kebun.'),
                _recCard(icon: Icons.science_outlined, title: 'Aplikasi Fungisida', description: 'Gunakan fungisida berbahan dasar tembaga untuk menghentikan penyebaran spora.'),
                _recCard(icon: Icons.water_drop_outlined, title: 'Manajemen Irigasi', description: 'Atur penyiraman hanya pada bagian akar, hindari membasahi daun secara berlebih.'),
              ],
              const SizedBox(height: 80),
            ]),
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
        child: ElevatedButton.icon(
          onPressed: () {
            Provider.of<ClassificationProvider>(context, listen: false).resetAll();
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
          icon: const Icon(Icons.home_filled, size: 20),
          label: const Text('Kembali'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: Colors.blue.shade700),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(color: Color(0xFF324B36), fontSize: 16, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _bulletPoint(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 6, right: 8),
          child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle))),
        Expanded(child: Text(text, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4))),
      ]));
  }

  Widget _phaseTag(String label, Color bg, Color text) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.bold)));
  }

  Widget _recCard({required IconData icon, required String title, required String description}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Color(0xFFF0F5ED), shape: BoxShape.circle),
          child: Icon(icon, color: const Color(0xFF5D7A58), size: 24)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Color(0xFF324B36), fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(description, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
        ])),
      ]),
    );
  }
}