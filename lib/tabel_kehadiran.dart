import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:horizontal_data_table/horizontal_data_table.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TabelKehadiranPage extends StatefulWidget {
  const TabelKehadiranPage({super.key});

  @override
  State<TabelKehadiranPage> createState() => _TabelKehadiranPageState();
}

class _TabelKehadiranPageState extends State<TabelKehadiranPage> {
  // 🔹 Selected bulan & tahun
  DateTime selectedDate = DateTime.now();

  // 🔹 Data dari API
  List<String> jadwalTanggal = [];
  List<Map<String, dynamic>> pesertaList = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData(); // ambil data pertama kali
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);

    final bulan = selectedDate.month;
    final tahun = selectedDate.year;
    final apiUrl = dotenv.env['API_URL'];

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final res = await http.get(
        Uri.parse("$apiUrl/api/presensi-bulanan/?bulan=$bulan&tahun=$tahun"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          jadwalTanggal = List<String>.from(data["jadwalTanggal"]);
          pesertaList = List<Map<String, dynamic>>.from(data["pesertaList"]);
        });
      } else {
        debugPrint("Error: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("Exception: $e");
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final String bulanTahun =
        "${_bulanIndo(selectedDate.month)} ${selectedDate.year}";

    return Scaffold(
      appBar: AppBar(
        title: Text(bulanTahun),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                // 🔹 Hitung lebar kanan (jadwal)
                double rightWidth = jadwalTanggal.length * 100;

                // 🔹 Minimal: isi full layar (dikurangi kolom kiri)
                double minRightWidth = constraints.maxWidth - 120;

                if (rightWidth < minRightWidth) {
                  rightWidth = minRightWidth;
                }

                return HorizontalDataTable(
                  leftHandSideColumnWidth: 120,
                  rightHandSideColumnWidth: rightWidth,
                  isFixedHeader: true,
                  headerWidgets: _getHeaderWidgets(rightWidth),
                  leftSideItemBuilder: _generateFirstColumnRow,
                  rightSideItemBuilder: _generateRightHandSideColumnRow,
                  itemCount: pesertaList.length,
                  rowSeparatorWidget:
                      const Divider(color: Colors.black26, height: 1),
                  leftHandSideColBackgroundColor: Colors.white,
                  rightHandSideColBackgroundColor: Colors.white,
                );
              },
            ),

      // 🔹 Floating Button pilih bulan/tahun
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (ctx) {
              int tempYear = selectedDate.year;
              int tempMonth = selectedDate.month;

              return StatefulBuilder(
                builder: (ctx, setStateModal) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButton<int>(
                          value: tempMonth,
                          items: List.generate(12, (i) => i + 1).map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Text(_bulanIndo(m)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setStateModal(() => tempMonth = val);
                            }
                          },
                        ),
                        DropdownButton<int>(
                          value: tempYear,
                          items: List.generate(10, (i) => 2020 + i).map((y) {
                            return DropdownMenuItem(
                              value: y,
                              child: Text(y.toString()),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setStateModal(() => tempYear = val);
                            }
                          },
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              selectedDate = DateTime(tempYear, tempMonth, 1);
                            });
                            Navigator.pop(ctx);
                            _fetchData(); // 🔹 refresh data
                          },
                          child: const Text("Pilih"),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
        child: const Icon(Icons.calendar_month, color: Colors.white),
      ),
    );
  }

  // 🔹 Header tabel
  List<Widget> _getHeaderWidgets(double rightWidth) {
    return [
      _headerCell("Peserta", 120),
      SizedBox(
        width: rightWidth,
        child: Row(
          children: jadwalTanggal.map((tgl) => _headerCell(tgl, 100)).toList(),
        ),
      ),
    ];
  }

  Widget _headerCell(String label, double width) {
    return Container(
      width: width,
      height: 56,
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  // 🔹 Kolom kiri
  Widget _generateFirstColumnRow(BuildContext context, int index) {
    return Container(
      width: 120,
      height: 52,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 8),
      child: Text(pesertaList[index]["nama"]),
    );
  }

  // 🔹 Kolom kanan
  Widget _generateRightHandSideColumnRow(BuildContext context, int index) {
    final peserta = pesertaList[index];
    return Row(
      children: jadwalTanggal.map((tgl) {
        final jam = peserta["kehadiran"][tgl] ?? "-";
        return Container(
          width: 100,
          height: 52,
          alignment: Alignment.center,
          child: Text(jam),
        );
      }).toList(),
    );
  }

  // 🔹 Helper nama bulan Indonesia
  String _bulanIndo(int bulan) {
    const namaBulan = [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember"
    ];
    return namaBulan[bulan - 1];
  }
}
