import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RiwayatPresensiPage extends StatefulWidget {
  const RiwayatPresensiPage({super.key});

  @override
  State<RiwayatPresensiPage> createState() => _RiwayatPresensiPageState();
}

class _RiwayatPresensiPageState extends State<RiwayatPresensiPage> {
  List<dynamic> presensiList = [];
  String? pesertaNama;
  bool _loading = true;
  String? _error;
  final apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    _fetchRiwayat();
  }

  Future<void> _fetchRiwayat() async {
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
        Uri.parse("$apiUrl/api/riwayat-presensi/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          pesertaNama = data['peserta'];
          presensiList = data['riwayat_presensi'] ?? [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Riwayat Presensi")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : presensiList.isEmpty
                  ? const Center(child: Text("Belum ada riwayat presensi"))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pesertaNama != null)
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              "$pesertaNama",
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: presensiList.length,
                            itemBuilder: (context, index) {
                              final item = presensiList[index];
                              final tanggal = item['tanggal'] ?? '-';
                              final waktu = item['waktu'] ?? '-';
                              final sasana = item['sasana'] ?? 'Tidak ada';
                              final jadwal =
                                  item['jadwal'] ?? ''; // UUID string

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                child: ListTile(
                                  leading: const Icon(Icons.event_available,
                                      color: Colors.blue),
                                  title: Text("$tanggal $waktu"),
                                  subtitle:
                                      Text("Sasana: $sasana\nJadwal: $jadwal"),
                                ),
                              );
                            },
                          ),
                        )
                      ],
                    ),
    );
  }
}
