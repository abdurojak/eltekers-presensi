import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:eltekers/login_page.dart';
import 'package:eltekers/riwayat_presensi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
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

  Future<bool> _requestStoragePermission() async {
    // Android 13+ pakai READ_MEDIA_IMAGES (Permission.photos)
    if (await Permission.photos.request().isGranted) {
      return true;
    }

    // Android 12 kebawah pakai storage
    if (await Permission.storage.request().isGranted) {
      return true;
    }

    return false;
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

  Future<void> _saveQrToGallery() async {
    if (qrBytes == null) return;

    final granted = await _requestStoragePermission();

    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Izin penyimpanan ditolak")),
      );
      return;
    }

    try {
      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(qrBytes!),
        quality: 100,
        name: "qrcode_${userData!['detail']['nama_peserta']}",
      );

      debugPrint("Save result: $result");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("QR Code berhasil disimpan ke galeri")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal menyimpan gambar: $e")),
      );
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
        appBar: AppBar(title: const Text("Beranda")),
        body: Center(child: Text(_error!)),
      );
    }

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
            ? const Text("Tidak ada data")
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Detail Peserta:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.download),
                          label: const Text("Download QR"),
                          onPressed: _saveQrToGallery,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.history),
                          label: const Text("Riwayat Presensi"),
                          onPressed: () {
                            // TODO: arahkan ke halaman riwayat presensi
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RiwayatPresensiPage(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
