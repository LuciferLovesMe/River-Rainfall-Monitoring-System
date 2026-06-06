import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- 1. Definisi Warna ---
class AppColors {
  static const Color primary = Color(0xFF50C2C9);
  static const Color danger = Color(0xFFEA142D);
  static const Color background = Color(0xFFF2F5F5);
  static const Color chartLine = Color(0xFF50C2C9);
}

// --- 2. Komponen Tombol Custom ---
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// --- 3. Komponen Input Field Custom (Untuk Tanggal) ---
class CustomDatePickerField extends StatelessWidget {
  final String hintText;
  final VoidCallback? onTap;

  const CustomDatePickerField({
    super.key,
    required this.hintText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              hintText,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              color: Colors.black54,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// --- 4. Komponen Grafik (Skala CM) ---
class WaterLevelChart extends StatelessWidget {
  const WaterLevelChart({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sensor_logs')
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .where('timestamp', isLessThanOrEqualTo: endOfDay)
            .snapshots(),
        builder: (context, snapshot) {
          // Struktur Map: Jam -> (Menit -> List Data)
          Map<int, Map<int, List<double>>> hourlyMinuteWater = {};

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['timestamp'] == null || data['jarak_cm'] == null)
                continue; // Pengecekan null agar aman

              DateTime time;
              if (data['timestamp'] is Timestamp) {
                time = (data['timestamp'] as Timestamp).toDate();
              } else {
                time = DateTime.parse(data['timestamp'].toString());
              }

              final hour = time.hour;
              final minute = time.minute;

              hourlyMinuteWater.putIfAbsent(hour, () => {});
              // MENGGUNAKAN jarak_cm
              hourlyMinuteWater[hour]!
                  .putIfAbsent(minute, () => [])
                  .add((data['jarak_cm'] as num).toDouble());
            }
          }

          List<FlSpot> chartSpots = [];
          for (int h = 0; h <= 23; h++) {
            double hourlyAvgW = 0.0;

            // Logika: Rata-rata dari (Rata-rata per Menit)
            if (hourlyMinuteWater.containsKey(h) &&
                hourlyMinuteWater[h]!.isNotEmpty) {
              double sumOfMinuteAvgs = 0.0;
              int minuteCount = 0;

              hourlyMinuteWater[h]!.forEach((min, values) {
                double minAvg = values.reduce((a, b) => a + b) / values.length;
                sumOfMinuteAvgs += minAvg;
                minuteCount++;
              });

              hourlyAvgW = sumOfMinuteAvgs / minuteCount;
            }
            chartSpots.add(FlSpot(h.toDouble(), hourlyAvgW));
          }

          return Column(
            children: [
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 200,
                    minX: 0,
                    maxX: 23,
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: 50,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withOpacity(0.2),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 6,
                          getTitlesWidget: (val, meta) => Text(
                            '${val.toInt().toString().padLeft(2, '0')}.00',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.black54),
                          ),
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 50,
                          reservedSize: 35,
                          getTitlesWidget: (val, meta) => Text(
                            '${val.toInt()}CM',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.black54),
                          ),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: chartSpots,
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primary.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Tren Jarak Air Hari Ini',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
