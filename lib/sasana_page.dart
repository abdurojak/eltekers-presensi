import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:eltekers/presensi_manual.dart';
import 'package:eltekers/scan_presensi.dart';
import 'package:eltekers/tabel_kehadiran.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eltekers/login_page.dart';

class SasanaPage extends StatefulWidget {
  const SasanaPage({super.key});

  @override
  State<SasanaPage> createState() => SasanaPageState();
}

class SasanaPageState extends State<SasanaPage> {
  Map<String, dynamic>? userData;
  Uint8List? qrBytes;
  List presensiList = [];
  List<String> jadwalLatihan = [];
  List<Map<String, String>> jadwalLatihanDetail = [];
  bool _loading = true;
  String? _error;
  final apiUrl = dotenv.env['API_URL'];
  final apiKey = dotenv.env['API_KEY'];

  @override
  void initState() {
    super.initState();
    _fetchUser();
    _fetchPresensi();
    _fetchJadwalLatihan();
  }

  Future<void> _fetchJadwalLatihan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("$apiUrl/api/jadwal-latihan/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        debugPrint("Jadwal latihan: $data");

        final List jadwal = data['jadwal_latihan'] ?? [];

        setState(() {
          // Simpan detail hari + jam
          jadwalLatihanDetail = jadwal.map<Map<String, String>>((e) {
            return {
              "hari": e['hari'].toString(),
              "jam": e['jam_latihan'].toString(),
            };
          }).toList();

          // Kalau tetap perlu list hari saja
          jadwalLatihan =
              jadwalLatihanDetail.map((e) => e['hari'] ?? "").toList();
        });
      } else {
        debugPrint("Gagal load jadwal: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetchJadwal: $e");
    }
  }

  Future<void> _fetchUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('token');

      if (accessToken == null) {
        setState(() {
          _error = "Token tidak ditemukan. Silakan login ulang.";
          _loading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse("$apiUrl/api/my-sasana/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          userData = data['sasana']; // ambil langsung object sasana
          _loading = false;
        });
      } else {
        setState(() {
          _error = "Gagal ambil data (${response.statusCode})";
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
        _loading = false;
      });
    }
  }

  Future<void> _fetchPresensi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("$apiUrl/api/presensi-saya-hari-ini/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          presensiList = data['data']; // ambil array peserta
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
        debugPrint("Gagal load presensi: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      debugPrint("Error fetchPresensi: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Sasana Page")),
        body: Center(child: Text(_error!)),
      );
    }

    final List<String> hariList = [
      "Minggu",
      "Senin",
      "Selasa",
      "Rabu",
      "Kamis",
      "Jumat",
      "Sabtu",
    ];

    final now = DateTime.now();
    final todayName = hariList[now.weekday % 7]; // weekday 1=Senin...7=Minggu

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final todayJadwal = jadwalLatihanDetail.firstWhere(
      (j) => j['hari'] == todayName,
      orElse: () => {"hari": "", "jam": ""},
    );

    final jadwalHariIni = todayJadwal['hari']!.isNotEmpty
        ? "Jadwal Latihan: ${todayJadwal['hari']} (${todayJadwal['jam']})"
        : "Jadwal Latihan: Tidak ada jadwal hari ini";

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Hilangkan tombol back
        title: const Text("Home Page"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear(); // hapus semua data di shared preferences

              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: userData == null
            ? const Text("Tidak ada data sasana")
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 👇 Logo Sasana di atas
                  if (userData!['logo_url'] != null)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          userData!['logo_url'],
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                  const Text("Detail Sasana",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("Nama Sasana: ${userData!['nama_sasana']}"),
                  Text("Sejak: ${userData!['sejak']}"),
                  Text("Alamat: ${userData!['alamat_sasana']}"),
                  Text(
                    jadwalHariIni,
                    // style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: hariList.map((hari) {
                      bool isInJadwal = jadwalLatihan.contains(hari);
                      bool isToday = hari == todayName;

                      Color bgColor = Colors.grey.shade300;
                      if (isToday && isInJadwal) {
                        bgColor = Colors.green;
                      } else if (isToday) {
                        bgColor = Colors.blue;
                      } else if (isInJadwal) {
                        bgColor = Colors.grey;
                      }

                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hari.substring(0, 3),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text("Scan Presensi"),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QrScannerPage(
                                  idSasana: userData!['id_sasana'],
                                ),
                              ),
                            );

                            if (result != null) {
                              final message = result is Map
                                  ? (result['error'] ?? result.toString())
                                  : result.toString();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(message)),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.assignment),
                          label: const Text("Presensi Manual"),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const PresensiManualPage()),
                            );
                            if (result == true) {
                              _fetchPresensi();
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const Text(
                    "Daftar Presensi Hari Ini",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : presensiList.isEmpty
                            ? const Center(
                                child: Text("Belum ada presensi hari ini"),
                              )
                            : ListView.builder(
                                itemCount: presensiList.length,
                                itemBuilder: (context, index) {
                                  final item = presensiList[index];
                                  return ListTile(
                                    leading: const Icon(Icons.person),
                                    title: Text(item['peserta']),
                                    subtitle: Text(
                                        "${item['tanggal']} • ${item['waktu']}"),
                                  );
                                },
                              ),
                  ),
                ],
              ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(width: 12),
          Expanded(
            // biar full width
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: FloatingActionButton.extended(
                heroTag: "btnLihatKehadiran",
                backgroundColor: Colors.blue,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TabelKehadiranPage(),
                    ),
                  );
                },
                label: const Text(
                  'Tabel Kehadiran Peserta',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                icon: const Icon(Icons.table_chart, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: "btnRefresh",
            backgroundColor: Colors.blue,
            onPressed: () {
              _fetchUser();
              _fetchPresensi();
              _fetchJadwalLatihan();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Halaman berhasil dimuat ulang")),
              );
            },
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
