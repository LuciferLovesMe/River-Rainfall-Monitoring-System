import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets.dart';
import '../services/notification_service.dart';
import 'profile_page.dart';
import 'history_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int? _lastProcessedUnix;

  @override
  void initState() {
    super.initState();
    _initSystem();
  }

  Future<void> _initSystem() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    await NotificationService.initialize();
    _listenToSensorAlerts();
  }

  // Membaca dari koleksi "sensor_data" dokumen "latest"
  void _listenToSensorAlerts() {
    FirebaseFirestore.instance
        .collection('sensor_data')
        .doc('latest')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;

        int currentUnix = (data['timestamp_unix'] as num?)?.toInt() ?? 0;
        if (_lastProcessedUnix == currentUnix) return;
        _lastProcessedUnix = currentUnix;

        double jarakCm = (data['jarak_cm'] as num?)?.toDouble() ?? 0.0;
        double debitValue = (data['hujan_interval'] as num?)?.toDouble() ?? 0.0;

        bool isExtremeRain = debitValue > 20.0;
        bool isHighWater = jarakCm <= 30.0; // Bahaya jika jarak air <= 30 CM

        if (isHighWater || isExtremeRain) {
          String body = '';
          if (isHighWater && isExtremeRain)
            body =
                'Air tersisa ${jarakCm.toStringAsFixed(1)}CM & Hujan Ekstrem!';
          else if (isHighWater)
            body =
                'Air tersisa ${jarakCm.toStringAsFixed(1)}CM (Waspada Banjir!)';
          else if (isExtremeRain)
            body = 'Hujan Ekstrem (${debitValue.toStringAsFixed(1)} mm)';

          NotificationService.showNotification(
            id: 1,
            title: '⚠️ PERINGATAN BAHAYA',
            body: body,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: SingleChildScrollView(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sensor_data')
              .doc('latest')
              .snapshots(),
          builder: (context, snapshot) {
            String jarakCmStr = "0.0";
            double debitValue = 0.0;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              double jarak = (data['jarak_cm'] as num?)?.toDouble() ?? 0.0;
              jarakCmStr = jarak.toStringAsFixed(1);
              debitValue = (data['hujan_interval'] as num?)?.toDouble() ?? 0.0;
            }

            String weather = "Cerah";
            IconData weatherIcon = Icons.wb_sunny_outlined;

            if (debitValue == 0) {
              weather = "Cerah";
              weatherIcon = Icons.wb_sunny_outlined;
            } else if (debitValue > 0 && debitValue <= 5.0) {
              weather = "Hujan Ringan";
              weatherIcon = Icons.grain;
            } else if (debitValue > 5.0 && debitValue <= 10.0) {
              weather = "Hujan Sedang";
              weatherIcon = Icons.water_drop_outlined;
            } else if (debitValue > 10.0 && debitValue <= 20.0) {
              weather = "Hujan Lebat";
              weatherIcon = Icons.thunderstorm_outlined;
            } else {
              weather = "Hujan Ekstrem";
              weatherIcon = Icons.warning_amber_rounded;
            }

            return Column(
              children: [
                SizedBox(
                  height: 260,
                  child: Stack(
                    children: [
                      Container(
                        height: 210,
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 20,
                          left: 24,
                          right: 24,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const ProfilePage())),
                              child: const CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white24,
                                  child: Icon(Icons.person,
                                      color: Colors.white, size: 30)),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: StreamBuilder<DocumentSnapshot>(
                                stream: user != null
                                    ? FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user.uid)
                                        .snapshots()
                                    : const Stream.empty(),
                                builder: (context, userSnapshot) {
                                  String fullName = userSnapshot.hasData &&
                                          userSnapshot.data!.exists
                                      ? (userSnapshot.data!.data()
                                              as Map)['fullName'] ??
                                          "User"
                                      : "User";
                                  return Text('Welcome $fullName',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white));
                                },
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const HistoryPage())),
                              child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2)),
                                  child: const Icon(Icons.access_time,
                                      color: Colors.white, size: 20)),
                            )
                          ],
                        ),
                      ),
                      Positioned(
                        top: 140,
                        left: 24,
                        right: 24,
                        child: Row(
                          children: [
                            Expanded(
                                child: _buildInfoCard(
                                    title: 'Cuaca',
                                    value: weather,
                                    icon: weatherIcon)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildInfoCard(
                                    title: 'Debit Air Hujan',
                                    value:
                                        '${debitValue.toStringAsFixed(1)} mm',
                                    icon: Icons.water_drop)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                      border: Border.all(color: AppColors.primary, width: 4)),
                  child: Center(
                      child: Text('$jarakCmStr CM',
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87))),
                ),
                const SizedBox(height: 50),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: WaterLevelChart(),
                ),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      {required String title, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ]),
      child: Row(
        children: [
          Icon(icon, size: 32, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500))),
                const SizedBox(height: 4),
                FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87))),
              ],
            ),
          )
        ],
      ),
    );
  }
}
