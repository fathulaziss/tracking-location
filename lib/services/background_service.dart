import 'dart:async';
import 'dart:ui';

import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tracking_location/helper/app_logger.dart';
import 'package:tracking_location/helper/local_storage_helper.dart';

// final AppLogger = Logger();
final Battery battery = Battery();
final dio = Dio();
final String apiUrl = 'http://34.101.176.197/api/v1/tracking';

Future<void> initializeService() async {
  // 🔹 Ensure bindings and plugins registered
  WidgetsFlutterBinding.ensureInitialized();

  final service = FlutterBackgroundService();

  // 🔹 Configure service
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'hajj_channel_id',
      initialNotificationTitle: 'Tracking Location',
      initialNotificationContent: 'Service is starting...',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [
        AndroidForegroundType.dataSync,
        AndroidForegroundType.location,
      ],
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  await AppLogger.init();
  int currentBatteryLevel = 0;

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: "Tracking Active",
      content: "App is tracking location...",
    );

    service.on("updateBattery").listen((event) {
      currentBatteryLevel = event?["level"] ?? 0;
      AppLogger.i("🔋 Battery updated from main: $currentBatteryLevel%");
    });

    service.on("startScheduler").listen((event) {
      if (event != null && event["minutes"] != null) {
        int interval = event["minutes"];
        String deviceId = event["deviceId"] ?? "";
        String deviceName = event['deviceName'] ?? "";
        AppLogger.i("Background tracking started every $interval minutes");

        Timer.periodic(Duration(minutes: interval), (timer) async {
          AppLogger.i("✅ Background service heartbeat running...");
          try {
            Position pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                distanceFilter: 10,
              ),
            );
            AppLogger.i('📍 Location: ${pos.latitude}, ${pos.longitude}');

            await sendLocation(deviceId, deviceName, pos.latitude, pos.longitude, currentBatteryLevel);

            // 🔹 Update notifikasi foreground bawaan
            service.setForegroundNotificationInfo(
              title: "Tracking Active",
              content: 'Lat: ${pos.latitude}, Lng: ${pos.longitude}',
            );
          } catch (e) {
            AppLogger.i('⚠️ Failed to get location: $e');
          }
        });
      }
    });

    service.on('stopService').listen((event) async {
      await service.stopSelf();
    });
  }
}


Future<void> sendLocation(
  String deviceId,
  String deviceName,
  double lat,
  double lon,
  int batteryLevel,
) async {
  // var batteryLevel = await battery.batteryLevel;
  final currentDateTime = DateTime.now().toIso8601String();

  final data = {
    'device': {'id': deviceId, 'name': deviceId},
    'latitude': lat,
    'longitude': lon,
    'created_at': currentDateTime,
    'batrai': batteryLevel,
    'signal_level': 100,
  };
  AppLogger.i("Attempting to send location: $data");

  try {
    final response = await dio.post(apiUrl, data: data);

    if (response.statusCode == 200 || response.statusCode == 201) {
      AppLogger.i("✅ Location sent successfully");
      await LocalStorageHelper.saveTrackingAttempt(data, 'sent');
    } else {
      AppLogger.w(
        "API returned status ${response.statusCode}. Will retry later.",
      );
      await LocalStorageHelper.saveTrackingAttempt(data, 'pending');
    }
  } catch (e) {
    AppLogger.e("Error sending location (connection error): $e");
    await LocalStorageHelper.saveTrackingAttempt(data, 'pending');
  }

  // Always clean up old records after a send attempt
  await LocalStorageHelper.cleanupOldRecords();
}

// Notification for foreground service
Future<void> showOrUpdateNotification(double lat, double lon) async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'hajj_channel_id',
    'Location Tracking',
    channelDescription: 'Tracking running in background',
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    autoCancel: false,
    showWhen: true,
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    0,
    'Tracking Active',
    'Lat: $lat, Lng: $lon',
    notificationDetails,
  );
}
