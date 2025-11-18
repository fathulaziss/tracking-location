import 'dart:async';

import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:tracking_location/helper/app_logger.dart';
import 'package:tracking_location/helper/local_storage_helper.dart';
import 'package:dio/dio.dart';
import 'package:tracking_location/services/device_info_plus.dart';

final dio = Dio();
const String apiUrl = 'http://34.101.176.197/api/v1/tracking';

Timer? _headlessTimer;
int trackingIntervalMinutes = 1; // can be dynamic

@pragma('vm:entry-point')
void bgHeadlessTask(bg.HeadlessEvent headlessEvent) async {
  try {
    final deviceInfo = await getDeviceInfo();

    switch (headlessEvent.name) {
      case bg.Event.LOCATION:
        // Clear existing timer if any
        _headlessTimer?.cancel();
        final state = await bg.BackgroundGeolocation.state;
        final interval = state.extras?['trackingIntervalMinutes'] ?? 1;

        // Start a periodic timer
        _headlessTimer = Timer.periodic(Duration(minutes: interval), (
          timer,
        ) async {
          try {
            final location = await bg.BackgroundGeolocation.getCurrentPosition(
              persist: false,
              samples: 1,
            );
            AppLogger.i('[HEADLESS TIMER] Location get : $location');

            final data = {
              "device": {"id": deviceInfo["id"], "name": deviceInfo["name"]},
              "latitude": location.coords.latitude,
              "longitude": location.coords.longitude,
              "created_at": DateTime.now().toIso8601String(),
              'batrai': 100,
              'signal_level': 100,
            };

            AppLogger.i('[HEADLESS TIMER] Location: $data');

            // ========= UPDATE NOTIFICATION =========
            await bg.BackgroundGeolocation.setConfig(
              bg.Config(
                notification: bg.Notification(
                  title: "Tracking Active",
                  text:
                  "Location Tracking Pending",
                ),
              ),
            );
            // ========================================

            await LocalStorageHelper.saveTrackingAttempt(data, 'pending');

            // Send to API
            final response = await dio.post(apiUrl, data: data);
            if (response.statusCode == 200 || response.statusCode == 201) {
              AppLogger.i('[HEADLESS TIMER] Location sent successfully');
              // ========= UPDATE NOTIFICATION =========
              await bg.BackgroundGeolocation.setConfig(
                bg.Config(
                  notification: bg.Notification(
                    title: "Tracking Active",
                    text:
                    "Location Tracking Success Send",
                  ),
                ),
              );
              // ========================================
            } else {
              AppLogger.w('[HEADLESS TIMER] API error: ${response.statusCode}');
              // ========= UPDATE NOTIFICATION =========
              await bg.BackgroundGeolocation.setConfig(
                bg.Config(
                  notification: bg.Notification(
                    title: "Tracking Active",
                    text:
                    "Location Tracking Something Wrong",
                  ),
                ),
              );
              // ========================================
            }

            await LocalStorageHelper.cleanupOldRecords();
          } catch (e) {
            AppLogger.e('[HEADLESS TIMER] Error sending location: $e');
          }
        });

        break;

      default:
        AppLogger.i('[HEADLESS] Event: ${headlessEvent.name}');
    }
  } catch (e, st) {
    AppLogger.e('[HEADLESS] Error: $e\n$st');
  }
}
