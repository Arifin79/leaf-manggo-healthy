import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'admin_dashboard_page.dart';
import 'profile_page.dart';
import '../providers/library_provider.dart';
import 'admin_saved_classification_page.dart';
import '../../data/firestore_service.dart';
import '../providers/auth_provider.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().loadItems();
    });
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
        automaticallyImplyLeading: false,
        title: const Text(
          'Dashboard',
          style: TextStyle(color: darkBlueText, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: primaryBlue.withValues(alpha:0.5), width: 2)),
                child: const CircleAvatar(radius: 16, backgroundColor: Color(0xFFE5F0FF), child: Icon(Icons.person, size: 20, color: primaryBlue)),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<LibraryProvider>(
        builder: (context, libraryProvider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ringkasan Sistem', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlueText)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _buildSummaryCard(title: 'Jumlah Penyakit', count: libraryProvider.items.length.toString(), icon: Icons.spa_outlined, color: Colors.green)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: FirestoreService().streamSavedClassifications(
                        userFilter: context.watch<AppAuthProvider>().userEmail
                      ),
                      builder: (context, snapshot) {
                        final count = snapshot.hasData ? snapshot.data!.length.toString() : '...';
                        return _buildSummaryCard(
                          title: 'Hasil Klasifikasi', 
                          count: count, 
                          icon: Icons.save_outlined, 
                          color: Colors.orange
                        );
                      }
                    ),
                  ),
                ]),
                const SizedBox(height: 40),
                const Text('Menu Utama', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlueText)),
                const SizedBox(height: 16),
                _menuCard(context, 'Hasil Klasifikasi Tersimpan', 'Lihat dan kelola hasil klasifikasi pengguna', Icons.save_outlined, Colors.green,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSavedClassificationPage()))),
                const SizedBox(height: 16),
                _menuCard(context, 'Manajemen Pustaka', 'Kelola daftar penyakit, gejala, dan solusi penanganannya', Icons.library_books, primaryBlue,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardPage()))),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _menuCard(BuildContext ctx, String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha:0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 32)),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ])),
          const SizedBox(width: 12),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _buildSummaryCard({required String title, required String count, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withValues(alpha:0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha:0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 16),
        Text(count, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      ]),
    );
  }
}
