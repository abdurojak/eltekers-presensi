import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'registrasi.dart';

class PilihSasanaPage extends StatefulWidget {
  const PilihSasanaPage({super.key});

  @override
  State<PilihSasanaPage> createState() => _PilihSasanaPageState();
}

class _PilihSasanaPageState extends State<PilihSasanaPage> {
  bool _loading = true;
  List<dynamic> _sasanas = [];
  final apiUrl = dotenv.env['API_URL'];
  final apiKey = dotenv.env['API_KEY'];

  @override
  void initState() {
    super.initState();
    _fetchSasana();
  }

  Future<void> _fetchSasana() async {
    try {
      // Pastikan permission lokasi diberikan
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location service tidak aktif")),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Izin lokasi ditolak")),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Izin lokasi ditolak permanen")),
        );
        return;
      }

      // Ambil lokasi user
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final url =
          "$apiUrl/api/sasana-terdekat/?lat=${position.latitude}&lng=${position.longitude}";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _sasanas = data['sasana_terdekat'];
          _loading = false;
        });
      } else {
        throw Exception("Gagal load data: ${response.body}");
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pilih Sasana")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sasanas.isEmpty
              ? const Center(child: Text("Tidak ada sasana ditemukan"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sasanas.length,
                  itemBuilder: (context, index) {
                    final sasana = _sasanas[index];
                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (sasana["profile"] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  sasana["profile"],
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              sasana["nama_sasana"],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(sasana["alamat"]),
                            Text("Jarak: ${sasana["jarak_km"]} km"),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RegistrasiPage(
                                        idSasana: sasana["id"],
                                      ),
                                    ),
                                  );
                                },
                                child: const Text("Pilih"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
