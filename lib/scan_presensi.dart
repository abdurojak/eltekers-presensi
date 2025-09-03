import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class QrScannerPage extends StatefulWidget {
  final String idSasana; // bisa int atau String, sesuaikan tipe dari API

  const QrScannerPage({super.key, required this.idSasana});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  final apiUrl = dotenv.env['API_URL'];
  final apiKey = dotenv.env['API_KEY'];

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR Code")),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text("Kembali"),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      controller.pauseCamera();

      try {
        final qrCode = scanData.code;

        // 👇 print isi asli QR yang terbaca
        debugPrint("RAW QR DATA: $qrCode");

        if (qrCode == null || qrCode.isEmpty) {
          if (context.mounted) {
            Navigator.pop(
                context, {"error": "QR Code kosong atau tidak valid"});
          }
          return;
        }

        // 👇 ubah kutip tunggal ke kutip ganda biar bisa di-parse sebagai JSON
        final fixedQr = qrCode.replaceAll("'", '"');

        // 👇 parse ke Map
        final qrData = jsonDecode(fixedQr);

        debugPrint("Decoded QR DATA: $qrData");

        // validasi id_sasana
        if (qrData["id_sasana"].toString() != widget.idSasana.toString()) {
          if (context.mounted) {
            Navigator.pop(
              context,
              {"error": "Peserta tidak terdaftar pada sasana ini!"},
            );
          }
          return; // jangan lanjut ke API
        }

        // ambil token
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');

        // kirim ke API
        final response = await http.post(
          Uri.parse("$apiUrl/api/scan/"),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
            "id_peserta": qrData["id_peserta"],
            "nama_peserta": qrData["nama_peserta"],
            "tanggal_lahir_peserta": qrData["tanggal_lahir_peserta"],
            "id_sasana": widget.idSasana,
            "status": "hadir",
          }),
        );

        debugPrint("Payload: ${jsonEncode({
              "data": qrData,
              "status": "hadir",
              "id_sasana": widget.idSasana,
            })}");

        if (response.statusCode == 200 || response.statusCode == 201) {
          // sukses (baik 200 OK atau 201 Created)
          final data = jsonDecode(response.body);
          if (context.mounted) {
            Navigator.pop(
                context, data['message']?.toString() ?? "Berhasil scan");
          }
        } else {
          // gagal, tampilkan pesan error dari response kalau ada
          String errorMessage = "Gagal scan (${response.statusCode})";
          try {
            final data = jsonDecode(response.body);
            if (data["message"] != null) {
              errorMessage = data["message"].toString();
            }
          } catch (_) {}
          if (context.mounted) {
            Navigator.pop(context, {"error": errorMessage});
          }
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context, {"error": e.toString()});
        }
      }
    });
  }
}
