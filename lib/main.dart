import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // File ini otomatis terbuat saat kamu jalankan flutterfire configure
import 'pages/login_page.dart';
import 'widgets.dart';

void main() async {
  // Wajib ditambahkan sebelum inisialisasi Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Menyalakan Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Onboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Menggunakan warna background yang sudah kita set di widgets.dart
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
      ),
      home: const LoginPage(),
    );
  }
}
