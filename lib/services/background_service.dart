import 'dart:async';
import 'dart:ui';

import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:tracking_location/helper/local_storage_helper.dart';

final logger = Logger();
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
      isForegroundMode: false,
      notificationChannelId: 'location_channel',
      initialNotificationTitle: 'Tracking Location',
      initialNotificationContent: 'Service is starting...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
    service.on("startScheduler").listen((event) {
      if (event != null && event["minutes"] != null) {
        int newMinutes = event["minutes"];
        int userId = event["userId"];
        logger.i(
          "Background tracking started with interval: $newMinutes minutes",
        );

        // 🔹 Periodically get location
        Timer.periodic(Duration(minutes: newMinutes), (timer) async {
          try {
            Position pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
              ),
            );
            logger.i(
              '📍 Background location: ${pos.latitude}, ${pos.longitude}',
            );
            await sendLocation(userId, pos.latitude, pos.longitude);
          } catch (e) {
            logger.i('⚠️ Failed to get location: $e');
          }
        });
      } else {
        logger.w("⚠️ Invalid start tracking event data: $event");
      }
    });
    service.on('stopService').listen((event) async {
      await service.stopSelf();
    });
  }
}

Future<void> sendLocation(int userId, double lat, double lon) async {
  var batteryLevel = await battery.batteryLevel;
  final currentDateTime = DateTime.now().toIso8601String();

  final data = {
    'user_id': userId,
    'latitude': lat,
    'longitude': lon,
    'created_at': currentDateTime,
    'batrai': batteryLevel,
    'signal_level': 100,
  };
  logger.i("Attempting to send location: $data");

  try {
    final response = await dio.post(apiUrl, data: data);

    if (response.statusCode == 200 || response.statusCode == 201) {
      logger.i("✅ Location sent successfully");
      await LocalStorageHelper.saveTrackingAttempt(data, 'sent');
    } else {
      logger.w("API returned status ${response.statusCode}. Will retry later.");
      await LocalStorageHelper.saveTrackingAttempt(data, 'pending');
    }
  } catch (e) {
    logger.e("Error sending location (connection error): $e");
    await LocalStorageHelper.saveTrackingAttempt(data, 'pending');
  }

  // Always clean up old records after a send attempt
  await LocalStorageHelper.cleanupOldRecords();
}
