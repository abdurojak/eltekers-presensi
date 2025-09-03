import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? userData;
  Uint8List? qrBytes;
  bool _loading = true;
  String? _error;
  final apiUrl = dotenv.env['API_URL'];
  final apiKey = dotenv.env['API_KEY'];

  @override
  void initState() {
    super.initState();
    _fetchUser();
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
        Uri.parse("$apiUrl/api/me/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final qrString = data['detail']['qrcode'];
        Uint8List? bytes;
        if (qrString != null && qrString.toString().contains(',')) {
          // hapus prefix "data:image/png;base64,"
          bytes = base64Decode(qrString.split(',')[1]);
        }

        setState(() {
          userData = data;
          qrBytes = bytes;
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
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Home Page")),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Home Page")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: userData == null
            ? const Text("Tidak ada data")
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Detail Peserta:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("Nama: ${userData!['detail']['nama_peserta']}"),
                  Text(
                      "Tanggal Lahir: ${userData!['detail']['tanggal_lahir_peserta']}"),
                  Text("Kendala: ${userData!['detail']['kendala_terapi']}"),
                  Text(
                      "Sasana: ${userData!['detail']['sasana']['nama_sasana']}"),
                  const SizedBox(height: 16),
                  if (qrBytes != null) ...[
                    Expanded(
                      child: Center(
                        child: Image.memory(
                          qrBytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
