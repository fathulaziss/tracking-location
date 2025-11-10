import 'dart:async';
import 'dart:ui';

import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
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
        AndroidForegroundType.location
      ]
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // DartPluginRegistrant.ensureInitialized();

  int currentBatteryLevel = 0;

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
    service.on("updateBattery").listen((event) {
      currentBatteryLevel = event?["level"] ?? 0;
      AppLogger.i("🔋 Battery updated from main: $currentBatteryLevel%");
    });

    service.on("startScheduler").listen((event) {
      if (event != null && event["minutes"] != null) {
        int newMinutes = event["minutes"];
        String deviceId = event["deviceId"] ?? "";
        String deviceName = event['deviceName'] ?? "";
        AppLogger.i(
          "Background tracking started with interval: $newMinutes minutes",
        );

        // 🔹 Periodically get location
        Timer.periodic(Duration(minutes: newMinutes), (timer) async {
          try {
            Position pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                distanceFilter: 10,
              ),
            );
            AppLogger.i(
              '📍 Background location: ${pos.latitude}, ${pos.longitude}',
            );
            await sendLocation(deviceId,deviceName, pos.latitude, pos.longitude,currentBatteryLevel);
          } catch (e) {
            AppLogger.i('⚠️ Failed to get location: $e');
          }
        });
      } else {
        AppLogger.w("⚠️ Invalid start tracking event data: $event");
      }
    });
    service.on('stopService').listen((event) async {
      await service.stopSelf();
    });
  }
}

Future<void> sendLocation(String deviceId,String deviceName, double lat, double lon,int batteryLevel) async {
  // var batteryLevel = await battery.batteryLevel;
  final currentDateTime = DateTime.now().toIso8601String();

  final data = {
    'device': {
      'id' : deviceId,
      'name' : deviceId
    },
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
      AppLogger.w("API returned status ${response.statusCode}. Will retry later.");
      await LocalStorageHelper.saveTrackingAttempt(data, 'pending');
    }
  } catch (e) {
    AppLogger.e("Error sending location (connection error): $e");
    await LocalStorageHelper.saveTrackingAttempt(data, 'pending');
  }

  // Always clean up old records after a send attempt
  await LocalStorageHelper.cleanupOldRecords();
}
