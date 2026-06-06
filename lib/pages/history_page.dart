import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime startOfDay = DateTime(
        selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
    DateTime endOfDay = DateTime(
        selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

    // Ubah DateTime batas rentang waktu menjadi format Unix (detik)
    int startUnix = startOfDay.millisecondsSinceEpoch ~/ 1000;
    int endUnix = endOfDay.millisecondsSinceEpoch ~/ 1000;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        title: const Text('History',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sensor_logs')
            // GANTI pencarian dari 'timestamp' menjadi 'timestamp_unix'
            .where('timestamp_unix', isGreaterThanOrEqualTo: startUnix)
            .where('timestamp_unix', isLessThanOrEqualTo: endUnix)
            .snapshots(),
        builder: (context, snapshot) {
          // Struktur Map: Jam -> (Menit -> List Data)
          Map<int, Map<int, List<double>>> hourlyMinuteWater = {};
          Map<int, Map<int, List<double>>> hourlyMinuteDebit = {};

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;

              DateTime time;

              // LOGIKA PERBAIKAN FORMAT TANGGAL YANG SOLID
              if (data['timestamp_unix'] != null) {
                // Konversi langsung dari format Unix (Angka integer panjang)
                time = DateTime.fromMillisecondsSinceEpoch(
                    (data['timestamp_unix'] as num).toInt() * 1000);
              } else {
                // Fallback jika membaca dari string 'waktu' atau 'timestamp'
                String timeStr = data['waktu']?.toString() ??
                    data['timestamp']?.toString() ??
                    "";
                if (timeStr.isEmpty)
                  continue; // Skip jika data waktu sama sekali tidak ada

                try {
                  // Bedah format "DD/MM/YYYY HH:MM:SS" secara manual
                  List<String> parts = timeStr.split(' ');
                  List<String> dateParts = parts[0].split('/');

                  // Susun balik susunan dari DD/MM/YYYY jadi standar YYYY-MM-DD
                  String formattedString =
                      "${dateParts[2]}-${dateParts[1]}-${dateParts[0]} ${parts.length > 1 ? parts[1] : '00:00:00'}";
                  time = DateTime.parse(formattedString);
                } catch (e) {
                  // Fallback aman jika pembelahan string masih gagal
                  time = DateTime.now();
                }
              }

              final hour = time.hour;
              final minute = time.minute;

              // Menggunakan jarak_cm
              if (data['jarak_cm'] != null) {
                hourlyMinuteWater.putIfAbsent(hour, () => {});
                hourlyMinuteWater[hour]!
                    .putIfAbsent(minute, () => [])
                    .add((data['jarak_cm'] as num).toDouble());
              }

              // Menggunakan hujan_interval
              if (data['hujan_interval'] != null) {
                hourlyMinuteDebit.putIfAbsent(hour, () => {});
                hourlyMinuteDebit[hour]!
                    .putIfAbsent(minute, () => [])
                    .add((data['hujan_interval'] as num).toDouble());
              }
            }
          }

          List<FlSpot> chartSpots = [];
          List<Map<String, dynamic>> hourlyListData = [];

          // Logika Kalkulasi: Rata-rata dari Rata-rata per Menit
          for (int h = 0; h <= 23; h++) {
            double hourlyAvgWater = 0.0;
            double hourlyAvgDebit = 0.0;

            if (hourlyMinuteWater.containsKey(h) &&
                hourlyMinuteWater[h]!.isNotEmpty) {
              // Hitung Rata-rata Jarak Air (jarak_cm)
              double sumOfMinuteAvgsW = 0.0;
              int minuteCountW = 0;
              hourlyMinuteWater[h]!.forEach((min, values) {
                double minAvg = values.reduce((a, b) => a + b) / values.length;
                sumOfMinuteAvgsW += minAvg;
                minuteCountW++;
              });
              hourlyAvgWater = sumOfMinuteAvgsW / minuteCountW;

              // Hitung Rata-rata Debit Hujan (hujan_interval)
              if (hourlyMinuteDebit.containsKey(h)) {
                double sumOfMinuteAvgsD = 0.0;
                int minuteCountD = 0;
                hourlyMinuteDebit[h]!.forEach((min, values) {
                  double minAvg =
                      values.reduce((a, b) => a + b) / values.length;
                  sumOfMinuteAvgsD += minAvg;
                  minuteCountD++;
                });
                hourlyAvgDebit = sumOfMinuteAvgsD / minuteCountD;
              }

              hourlyListData.add({
                'hour': h,
                'jarak_cm': hourlyAvgWater,
                'hujan_interval': hourlyAvgDebit,
              });
            }
            chartSpots.add(FlSpot(h.toDouble(), hourlyAvgWater));
          }

          // Urutkan list riwayat dari jam terbaru ke terlama (descending)
          hourlyListData
              .sort((a, b) => (b['hour'] as int).compareTo(a['hour'] as int));

          return Column(
            children: [
              Container(
                color: AppColors.primary,
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
                child: CustomDatePickerField(
                  hintText:
                      "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                  onTap: () => _selectDate(context),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        height: 220,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: LineChart(
                          LineChartData(
                            minY: 0,
                            maxY: 200, // SKALA 200 CM
                            minX: 0,
                            maxX: 23,
                            gridData: FlGridData(
                                show: true,
                                horizontalInterval: 50,
                                drawVerticalLine: false),
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
                                      style: const TextStyle(fontSize: 10)),
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 50,
                                  reservedSize: 35,
                                  getTitlesWidget: (val, meta) => Text(
                                      '${val.toInt()}CM',
                                      style: const TextStyle(fontSize: 10)),
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
                                    color: AppColors.primary.withOpacity(0.1)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator())
                      else if (!snapshot.hasData || hourlyListData.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text("Tidak ada data untuk tanggal ini",
                                style: TextStyle(color: Colors.black54)))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: hourlyListData.length,
                          itemBuilder: (context, index) {
                            final data = hourlyListData[index];

                            double jarakCm = data['jarak_cm'];
                            double hujanInterval = data['hujan_interval'];
                            int hour = data['hour'];
                            String formattedTime =
                                "${hour.toString().padLeft(2, '0')}:00";

                            String weather = "Cerah";
                            if (hujanInterval > 0 && hujanInterval <= 5.0)
                              weather = "Hujan Ringan";
                            else if (hujanInterval > 5.0 &&
                                hujanInterval <= 10.0)
                              weather = "Hujan Sedang";
                            else if (hujanInterval > 10.0 &&
                                hujanInterval <= 20.0)
                              weather = "Hujan Lebat";
                            else if (hujanInterval > 20.0)
                              weather = "Hujan Ekstrem";

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.water_drop,
                                        color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            "Jarak Air: ${jarakCm.toStringAsFixed(1)} CM",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        Text(weather,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(formattedTime,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87)),
                                      Text(
                                          "${hujanInterval.toStringAsFixed(1)} mm",
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
