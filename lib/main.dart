import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tracking_location/helper/app_logger.dart';
import 'package:tracking_location/pages/SplashScreen.dart';
import 'package:tracking_location/services/background_geolocation_headless.dart';
import 'package:tracking_location/services/background_service.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // await initializeService();
  bg.BackgroundGeolocation.registerHeadlessTask(bgHeadlessTask);

  // ✅ Buat notification channel khusus untuk foreground service
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'hajj_channel_id', // unique ID
    'Location Tracking', // nama channel
    description: 'Channel untuk foreground location tracking',
    importance: Importance.low,
  );

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/launcher_icon'); // gunakan ic_launcher, bukan launcher_icon

  const DarwinInitializationSettings initializationSettingsDarwin =
  DarwinInitializationSettings();

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // ✅ Daftarkan channel supaya valid sebelum service start
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  await AppLogger.init();

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
