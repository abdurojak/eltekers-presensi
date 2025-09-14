import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:month_year_picker/month_year_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eltekers',
      theme: ThemeData(
        // atur primary color jadi biru
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 38, 21, 199)),
        useMaterial3: true,

        // atur style default untuk ElevatedButton
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                const Color.fromARGB(255, 38, 21, 199), // warna background
            foregroundColor: Colors.white, // warna teks/icon
            minimumSize:
                const Size(double.infinity, 50), // biar seragam full width
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(12), // biar sudutnya agak rounded
            ),
          ),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        MonthYearPickerLocalizations.delegate, // 🔹 WAJIB
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('id'), // kalau mau bahasa Indonesia
      ],
      home: const LoginPage(),
    );
  }
}
