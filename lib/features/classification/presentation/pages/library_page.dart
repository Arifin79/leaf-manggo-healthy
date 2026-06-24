import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../models/library_item_data.dart';
import 'library_detail_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF1E3B21);
    const Color primaryBlue = Color(0xFF007BFF);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'LIBRARY',
          style: TextStyle(
            color: darkGreen,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<LibraryProvider>(
        builder: (context, libraryProvider, _) {
          if (libraryProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (libraryProvider.items.isEmpty) {
            return const Center(
              child: Text('Data pustaka belum tersedia'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Library',
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Identifikasi gejala secara akurat dengan panduan visual dan langkah penanganan medis botani kami.',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                ...libraryProvider.items.map((item) => _buildLibraryItem(context, item)),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLibraryItem(BuildContext context, LibraryItemData item) {
    IconData icon;
    Color iconColor;
    Color bgColor;

    switch (item.title) {
      case 'Anthracnose':
        icon = Icons.coronavirus_outlined;
        iconColor = Colors.brown;
        bgColor = Colors.orange.shade100;
        break;
      case 'Daun Sehat':
        icon = Icons.eco_outlined;
        iconColor = Colors.green;
        bgColor = Colors.green.shade100;
        break;
      case 'Die Back':
        icon = Icons.local_florist_outlined;
        iconColor = Colors.red;
        bgColor = Colors.red.shade50;
        break;
      case 'Gall Midge':
        icon = Icons.bug_report_outlined;
        iconColor = Colors.deepOrange;
        bgColor = Colors.orange.shade50;
        break;
      case 'Powdery Mildew':
        icon = Icons.cloud_outlined;
        iconColor = Colors.blueAccent;
        bgColor = Colors.blue.shade50;
        break;
      case 'Sooty Mould':
      default:
        icon = Icons.spa_outlined;
        iconColor = Colors.grey.shade800;
        bgColor = Colors.grey.shade200;
        break;
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LibraryDetailPage(item: item),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Color(0xFF1E3B21),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'serif',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.shortDescription,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.blue,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
