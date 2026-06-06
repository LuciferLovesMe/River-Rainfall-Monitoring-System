import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Tambahkan import ini
import '../widgets.dart';
import 'login_page.dart'; // Tambahkan import halaman login

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // Fungsi untuk Logout
  Future<void> _handleLogout(BuildContext context) async {
    try {
      // Perintah ke Firebase untuk sign out
      await FirebaseAuth.instance.signOut();

      // Jika berhasil, arahkan kembali ke halaman Login dan hapus semua riwayat halaman
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      // Tangkap error jika gagal logout (walaupun sangat jarang terjadi)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gagal logout. Silakan coba lagi.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Tombol Back (Opsional, agar bisa kembali ke Dashboard)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              const SizedBox(height: 20),

              // --- Foto Profil (Menggunakan Icon Default) ---
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.1),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: const Icon(
                  Icons.person,
                  size: 60,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 24),

              // --- Nama ---
              const Text(
                'Pascal',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 40),

              // --- Menu Buttons ---
              CustomButton(
                text: 'Ganti Kata Sandi',
                onPressed: () {
                  // TODO: Aksi navigasi atau dialog ganti kata sandi
                },
              ),

              const SizedBox(height: 20),

              CustomButton(
                text: 'Tentang Aplikasi',
                onPressed: () {
                  // Menampilkan popup dialog Tentang Aplikasi
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        title: const Text(
                          'Tentang Aplikasi',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        content: const Text(
                          'Aplikasi Onboard IoT Monitoring.\n\n'
                          'Digunakan untuk memantau ketinggian dan debit air secara real-time dari perangkat IoT Anda.\n\n'
                          'Versi 1.0',
                          style: TextStyle(height: 1.5, fontSize: 14),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // Tutup dialog
                            },
                            child: const Text(
                              'Tutup',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              // Spacer akan mendorong elemen di bawahnya (Logout) sampai ke paling bawah layar
              const Spacer(),

              // --- Tombol Logout ---
              CustomButton(
                text: 'Logout',
                color: AppColors.danger,
                onPressed: () {
                  // Panggil fungsi logout saat ditekan
                  _handleLogout(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
