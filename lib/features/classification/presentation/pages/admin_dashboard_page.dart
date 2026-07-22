import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/library_item_data.dart';
import '../providers/library_provider.dart';
import '../providers/class_management_provider.dart';
import 'disease_form_page.dart';
import 'admin_library_detail_page.dart' as admin_detail;

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().loadItems();
      context.read<ClassManagementProvider>().fetchModelStatus();
    });
  }

  void _deleteItem(LibraryItemData item) {
    if (item.id == null) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Data'),
        content: Text('Anda yakin ingin menghapus data "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);

              // Classes added via the dynamic "train new class" flow also
              // exist in the Flask model (classes.json, dataset_master.csv,
              // rf_addon_*.pkl) — remove them there too, or the model keeps
              // recognizing a class that no longer has a library entry.
              //
              // Only do this for entries that actually finished training
              // (isActive == true). A pending/failed entry (isActive ==
              // false) never made it into the model under this specific
              // Firestore doc, so there's nothing there to clean up — and
              // if its name happens to collide with one of the 6 protected
              // original classes, calling the backend would incorrectly
              // get rejected and block deleting the local ghost entry too.
              if (item.addedBy != null && item.isActive) {
                final removedFromModel = await context.read<ClassManagementProvider>().deleteDynamicClass(item.title);
                if (!removedFromModel && mounted) {
                  final message = context.read<ClassManagementProvider>().deleteErrorMessage;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message ?? 'Gagal menghapus kelas dari model')),
                  );
                  return;
                }
              }

              if (!mounted) return;
              final success = await context.read<LibraryProvider>().deleteItem(item.id!);
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data berhasil dihapus')),
                );
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddForm(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DiseaseFormPage()),
    );
    if (context.mounted) {
      context.read<LibraryProvider>().loadItems();
      context.read<ClassManagementProvider>().fetchModelStatus();
    }
  }

  void _showMoreOptions(BuildContext context, LibraryItemData item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                title: const Text('Edit Data'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DiseaseFormPage(itemToEdit: item)),
                  );
                  if (context.mounted) {
                    context.read<LibraryProvider>().loadItems();
                    context.read<ClassManagementProvider>().fetchModelStatus();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.note_add_outlined, color: Colors.green),
                title: const Text('Tambah Catatan Khusus'),
                onTap: () {
                  Navigator.pop(ctx);
                  
                  final noteCtrl = TextEditingController(text: item.adminNote);
                  
                  showDialog(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.admin_panel_settings, color: Colors.amber.shade800, size: 24),
                              const SizedBox(width: 10),
                              const Text('Catatan Khusus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                              children: [
                                const TextSpan(text: 'Penyakit: '),
                                TextSpan(text: item.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      content: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.9,
                        child: TextField(
                          controller: noteCtrl,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: 'Tulis informasi tambahan atau catatan rahasia di sini...\n(Hanya admin yang bisa melihat)',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.5),
                            filled: true,
                            fillColor: Colors.amber.shade50.withValues(alpha:0.3),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.amber.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.amber.shade200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.amber.shade600, width: 2)),
                          ),
                        ),
                      ),
                      actionsPadding: const EdgeInsets.only(bottom: 20, right: 20, left: 20),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: Text('Batal', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final newNote = noteCtrl.text.trim();
                            Navigator.pop(dialogCtx);
                            
                            // Save to firestore
                            final updatedItem = item.copyWith(adminNote: newNote);
                            if (updatedItem.id != null) {
                              final success = await context.read<LibraryProvider>().updateItem(updatedItem.id!, updatedItem);
                              if (context.mounted) {
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catatan berhasil disimpan')));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan catatan')));
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Simpan Catatan', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Hapus Data', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteItem(item);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
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
          'Manajemen Pustaka',
          style: TextStyle(
            color: darkBlueText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<LibraryProvider>(
        builder: (context, libraryProvider, _) {
          if (libraryProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = libraryProvider.items;

          if (items.isEmpty) {
            return const Center(child: Text('Data Pustaka Kosong'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => admin_detail.AdminLibraryDetailPage(item: item),
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
                        color: Colors.black.withValues(alpha:0.02),
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
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.spa, color: primaryBlue),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkBlueText,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Consumer<ClassManagementProvider>(
                        builder: (context, classProvider, _) {
                          final isModelActive = item.isActive && classProvider.isClassActive(item.title);
                          return Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                item.status,
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isModelActive ? Colors.green.shade50 : Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isModelActive ? Colors.green.shade200 : Colors.amber.shade300),
                                ),
                                child: Text(
                                  isModelActive ? 'Model Aktif' : 'Sedang Diproses',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isModelActive ? Colors.green.shade700 : Colors.amber.shade800,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      color: Colors.grey,
                      onPressed: () => _showMoreOptions(context, item),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddForm(context),
        backgroundColor: primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Penyakit Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
