import 'package:flutter/material.dart';
import 'result_page.dart'; // import to navigate to Result Page

class AdminSavedClassificationPage extends StatefulWidget {
  const AdminSavedClassificationPage({super.key});

  @override
  State<AdminSavedClassificationPage> createState() => _AdminSavedClassificationPageState();
}

class _AdminSavedClassificationPageState extends State<AdminSavedClassificationPage> {
  // Dummy data for frontend
  final List<Map<String, dynamic>> _savedItems = [
    {
      'id': '1',
      'date': '12 Apr 2026, 14:30',
      'result': 'Anthracnose',
      'confidence': 98,
      'user': 'Arifin',
    },
    {
      'id': '2',
      'date': '10 Apr 2026, 09:15',
      'result': 'Daun Sehat',
      'confidence': 99,
      'user': 'Budi',
    },
    {
      'id': '3',
      'date': '08 Apr 2026, 16:45',
      'result': 'Die Back',
      'confidence': 85,
      'user': 'Citra',
    },
  ];

  void _deleteItem(int index) {
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
            onPressed: () {
              setState(() {
                _savedItems.removeAt(index);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data berhasil dihapus')),
              );
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
          icon: const Icon(Icons.arrow_back, color: darkBlueText),
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
      body: _savedItems.isEmpty
          ? const Center(child: Text('Belum ada data klasifikasi tersimpan'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: _savedItems.length,
              itemBuilder: (context, index) {
                final item = _savedItems[index];
                
                IconData icon;
                Color iconColor;
                Color bgColor;

                if (item['result'] == 'Daun Sehat') {
                  icon = Icons.eco_outlined;
                  iconColor = Colors.green;
                  bgColor = Colors.green.shade50;
                } else if (item['result'] == 'Anthracnose') {
                  icon = Icons.coronavirus_outlined;
                  iconColor = Colors.brown;
                  bgColor = Colors.orange.shade50;
                } else {
                  icon = Icons.local_florist_outlined;
                  iconColor = Colors.red;
                  bgColor = Colors.red.shade50;
                }

                return GestureDetector(
                  onTap: () {
                    // Navigate to Result Page to see details
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ResultPage(),
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
                        item['result'],
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
                              'Akurasi: ${item['confidence']}%',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item['date']} • By ${item['user']}',
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
                        onPressed: () => _deleteItem(index),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
