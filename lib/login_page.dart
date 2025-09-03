import 'dart:async';
import 'dart:convert';
import 'package:eltekers/sasana_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final apiUrl = dotenv.env['API_URL'];
  final apiKey = dotenv.env['API_KEY'];
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
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: "Username"),
                validator: (value) =>
                    value!.isEmpty ? "Username wajib diisi" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Password"),
                validator: (value) =>
                    value!.isEmpty ? "Password wajib diisi" : null,
              ),
              const SizedBox(height: 20),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      child: const Text("Login"),
                    ),
              if (_message != null) ...[
                const SizedBox(height: 20),
                Text(_message!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
