import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/classification/presentation/pages/home_page.dart';
import 'features/classification/presentation/providers/classification_provider.dart';
import 'features/classification/presentation/providers/auth_provider.dart';
import 'features/classification/presentation/providers/library_provider.dart';
import 'features/classification/presentation/providers/class_management_provider.dart';
import 'features/classification/data/firestore_service.dart';
import 'shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final firestoreService = FirestoreService();
  await firestoreService.seedInitialData();

  runApp(const LeafClassificationApp());
}

class LeafClassificationApp extends StatelessWidget {
  const LeafClassificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClassificationProvider()),
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => ClassManagementProvider()),
      ],
      child: MaterialApp(
        title: 'ManggoCare',
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        home: const HomePage(),
      ),
    );
  }
}