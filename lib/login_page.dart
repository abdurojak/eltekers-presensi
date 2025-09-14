import 'dart:async';
import 'dart:convert';
import 'package:eltekers/home_page.dart';
import 'package:eltekers/pilih_sasana.dart';
import 'package:eltekers/sasana_page.dart';
import 'package:eltekers/registrasi.dart'; // <-- pastikan file registrasi.dart ada
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final apiUrl = dotenv.env['API_URL'];
  final apiKey = dotenv.env['API_KEY'];
  bool _obscurePassword = true;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  String? _message;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse("$apiUrl/api/login/"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "username": _usernameController.text,
              "password": _passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access'];
        final role = data['role'];

        // simpan token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);

        // redirect berdasarkan role
        if (context.mounted) {
          if (role == 'peserta') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SasanaPage()),
            );
          }
        }
      } else {
        setState(() {
          _message = "Login gagal (${response.statusCode})";
        });
      }
    } on TimeoutException catch (_) {
      setState(() {
        _message = "Login gagal: Waktu habis (timeout)";
      });
    } catch (e) {
      setState(() {
        _message = "Error: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO
                Image.asset(
                  "assets/images/logo.png",
                  height: 120,
                ),
                const SizedBox(height: 32),

                // USERNAME
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: "Username",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? "Username wajib diisi" : null,
                ),
                const SizedBox(height: 16),

                // PASSWORD
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? "Password wajib diisi" : null,
                ),
                const SizedBox(height: 24),

                // LOGIN BUTTON
                _loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text("Login"),
                      ),
                const SizedBox(height: 12),

                // REGISTER BUTTON
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PilihSasanaPage()),
                    );
                  },
                  child: const Text("Belum punya akun? Daftar di sini"),
                ),

                if (_message != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _message!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
