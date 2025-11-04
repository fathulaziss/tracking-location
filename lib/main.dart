import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tracking_location/pages/SplashScreen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings(
        '@mipmap/launcher_icon',
      ); // ensure you have this drawable

  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings();

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
    // optionally linux/mac/windows
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      // This handles notification tap when app is in foreground/background
      final String? payload = response.payload;
      if (payload != null) {
        debugPrint('notification payload: $payload');
      }
      // e.g., navigate to another screen
    },
    // optionally: onDidReceiveBackgroundNotificationResponse
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hajj Tracker App',
      theme: ThemeData(
        // Menggunakan warna hijau yang lebih kaya untuk tema utama
        primarySwatch: Colors.green,
        primaryColor: Colors.green.shade700,
        scaffoldBackgroundColor:
            Colors.grey.shade50, // Latar belakang abu-abu muda
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
        // Mengatur tema App Bar secara global untuk desain yang lebih bersih
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green.shade700,
          elevation: 0,
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await initializeService();
//   runApp(const MyApp());
// }
//
// class MyApp extends StatefulWidget {
//   const MyApp({super.key});
//
//   @override
//   State<MyApp> createState() => _MyAppState();
// }
//
// class _MyAppState extends State<MyApp> {
//   String location = "Unknown";
//
//   @override
//   void initState() {
//     super.initState();
//     _checkPermission();
//   }
//
//   Future<void> _checkPermission() async {
//     await Geolocator.requestPermission();
//   }
//
//   Future<void> _getLocation() async {
//     Position pos = await Geolocator.getCurrentPosition();
//     setState(() {
//       location = "Lat: ${pos.latitude}, Lng: ${pos.longitude}";
//     });
//   }
//
//   Future<void> startTracking() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       await Geolocator.openLocationSettings();
//     }
//
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//
//     if (permission == LocationPermission.deniedForever) {
//       print("Location permission permanently denied.");
//       return;
//     }
//
//     // Setelah semua izin diberikan baru start service
//     await FlutterBackgroundService().startService();
//   }
//
//   void _stopService() {
//     FlutterBackgroundService().invoke("stopService");
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: const Text("Location Tracker")),
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(location, style: const TextStyle(fontSize: 18)),
//               const SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: _getLocation,
//                 child: const Text("Get Foreground Location"),
//               ),
//               ElevatedButton(
//                 onPressed: startTracking,
//                 child: const Text("Start Background Service"),
//               ),
//               ElevatedButton(
//                 onPressed: _stopService,
//                 child: const Text("Stop Background Service"),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
