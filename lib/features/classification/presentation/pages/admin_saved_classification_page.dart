import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'saved_result_detail_page.dart'; // import to navigate to Detail Page
import '../../data/firestore_service.dart';

class AdminSavedClassificationPage extends StatefulWidget {
  const AdminSavedClassificationPage({super.key});

  @override
  State<AdminSavedClassificationPage> createState() => _AdminSavedClassificationPageState();
}

class _AdminSavedClassificationPageState extends State<AdminSavedClassificationPage> {
  final FirestoreService _firestoreService = FirestoreService();

  void _deleteItem(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Data'),
        content: const Text('Anda yakin ingin menghapus data klasifikasi ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _firestoreService.deleteSavedClassification(id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data berhasil dihapus')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus data: $e')),
                  );
                }
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF007BFF);
    const Color darkBlueText = Color(0xFF0A2540);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkBlueText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Hasil Tersimpan',
          style: TextStyle(
            color: darkBlueText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.streamSavedClassifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          final _savedItems = snapshot.data ?? [];

          if (_savedItems.isEmpty) {
            return const Center(child: Text('Belum ada data klasifikasi tersimpan'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: _savedItems.length,
            itemBuilder: (context, index) {
              final item = _savedItems[index];
              
              IconData icon;
              Color iconColor;
              Color bgColor;

              final String resultName = item['result'] ?? 'Unknown';
              final bool isHealthy = resultName.toLowerCase().contains('sehat') || resultName.toLowerCase() == 'healthy';

              if (isHealthy) {
                icon = Icons.eco_outlined;
                iconColor = Colors.green;
                bgColor = Colors.green.shade50;
              } else if (resultName.toLowerCase().contains('anthracnose')) {
                icon = Icons.coronavirus_outlined;
                iconColor = Colors.brown;
                bgColor = Colors.orange.shade50;
              } else {
                icon = Icons.local_florist_outlined;
                iconColor = Colors.red;
                bgColor = Colors.red.shade50;
              }

              // Format date from timestamp or string
              String formattedDate = item['date'] ?? '';
              if (item['timestamp'] != null) {
                try {
                  final DateTime date = item['timestamp'].toDate();
                  formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(date);
                } catch (_) {}
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SavedResultDetailPage(savedItem: item),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor),
                    ),
                    title: Text(
                      resultName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkBlueText,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Akurasi: ${item['confidence'] ?? 0}%',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$formattedDate • By ${item['user'] ?? 'Guest'}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red.shade300,
                      onPressed: () => _deleteItem(item['id']),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
