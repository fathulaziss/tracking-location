import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tracking_location/pages/TrackingScreen/TrackingScreen.dart';
import 'package:tracking_location/widgets/TextWidgets.dart';

// ------------------------------------
// 1. Splash Screen (Layar Pemuatan)
// ------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const TrackingScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Warna hijau yang lebih gelap
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ikon yang lebih menonjol
            Image.asset(
              'assets/images/logos/Logo.png',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 20),
            const Textwidgets(
              'Hajj Tracking System',
              fontSize: 28, // Font lebih besar
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 1.5,
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
            const SizedBox(height: 10),
            const Textwidgets('Memuat aplikasi...', color: Colors.black),
          ],
        ),
      ),
    );
  }
}
