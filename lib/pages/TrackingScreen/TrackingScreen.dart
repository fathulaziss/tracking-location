import 'dart:async';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:signal_strength_indicator/signal_strength_indicator.dart';
import 'package:tracking_location/helper/app_logger.dart';
import 'package:tracking_location/helper/local_storage_helper.dart';
import 'package:tracking_location/helper/location_helper.dart';
import 'package:tracking_location/main.dart';
import 'package:tracking_location/pages/TrackingScreen/widgets/ListInformation.dart';
import 'package:tracking_location/pages/TrackingScreen/widgets/permission_dialog.dart';
import 'package:tracking_location/widgets/PulsingDot.dart';
import 'package:tracking_location/widgets/TextWidgets.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Timer? _trackingTimer;
  int trackingIntervalMinutes = 1;
  bool isTracking = false;
  final Battery _battery = Battery();
  final Dio dio = Dio();
  static const String apiUrl = 'http://34.101.176.197/api/v1/tracking';
  final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
  String _deviceId = '';
  String _deviceName = '';
  String latitudeText = 'Memuat...';
  String longitudeText = 'Memuat...';
  String addressText = 'Memuat...';
  String accuracyText = '';
  String errorText = '';
  final LocationHelper locationHelper = LocationHelper();

  final GlobalKey<ListInformationState> _listInfoKey =
      GlobalKey<ListInformationState>();

  void _notifyListRefresh() {
    // 2. Use the key to access the state and call the refresh method
    _listInfoKey.currentState?.loadTrackingRecords();
  }

  @override
  void initState() {
    super.initState();
    _getDeviceInfo();
    _configureBackgroundGeolocation();
    _onCheckLocationPressed();
    // _loadTrackingState();
    LocalStorageHelper.clearAllHistory();
  }

  Future<void> _onCheckLocationPressed() async {
    // await initializeService();

    setState(() {
      latitudeText = 'Memeriksa...';
      longitudeText = '';
      addressText = '';
      accuracyText = '';
      errorText = '';
    });

    final result = await locationHelper.checkLocationServiceStatus(context);
    if (result.containsKey('error')) {
      setState(() {
        errorText = result['error']!;
        latitudeText = '';
        longitudeText = '';
        accuracyText = '';
        addressText = '';
      });
    } else {
      setState(() {
        latitudeText = result['latitude'] ?? "-";
        longitudeText = result['longitude'] ?? "-";
        accuracyText = result['accuracy'] ?? "-";
        addressText = result['address'] ?? "-";
      });
    }
  }

  Future<void> _getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfoPlugin.androidInfo;
        _deviceId = info.id ?? 'unknown';
        _deviceName = info.model ?? 'unknown';
      } else if (Platform.isIOS) {
        final info = await deviceInfoPlugin.iosInfo;
        _deviceId = info.identifierForVendor ?? 'unknown';
        _deviceName = info.name ?? 'unknown';
      }
    } catch (e) {
      _deviceId = 'unknown';
      _deviceName = 'unknown';
    }
    setState(() {});
  }

  Future<void> _loadTrackingState() async {
    AppLogger.d("Load Tracking State");
    final wasTracking = await getTrackingState();
    if (wasTracking) {
      _startTracking();
    }
  }

  void _startTrackingTimer() async{
    // Cancel any existing timer
    _trackingTimer?.cancel();
    AppLogger.w("Start Tracking");
    _trackingTimer = Timer.periodic(
      Duration(minutes: trackingIntervalMinutes),
      (timer) async {
        try {
          final location = await bg.BackgroundGeolocation.getCurrentPosition(
            persist: false,
            samples: 1,
          );

          final batteryLevel = await _battery.batteryLevel;

          final data = {
            'device': {'id': _deviceId, 'name': _deviceName},
            'latitude': location.coords.latitude,
            'longitude': location.coords.longitude,
            'created_at': DateTime.now().toIso8601String(),
            'batrai': batteryLevel,
            'signal_level': 100,
          };

          AppLogger.i("Sending location (timer): $data");
          final recordId = await LocalStorageHelper.saveTrackingAttempt(data, 'pending');
          String sendStatus = "Pending";
          final response = await dio.post(apiUrl, data: data);
          AppLogger.w("Response : $response");
          if (response.statusCode == 200 || response.statusCode == 201) {
            AppLogger.i("✅ Location sent successfully");
            // await LocalStorageHelper.updateRecordStatus('last_id', 'sent');
            sendStatus = "Success";
            await _syncOfflineData();
          }else{
            sendStatus = "Failed (${response.statusCode})";
          }

          _listInfoKey.currentState?.loadTrackingRecords();


          await updateTrackingNotification(
            status: sendStatus,
            latitude: location.coords.latitude,
            longitude: location.coords.longitude,
          );
        } catch (e) {
          AppLogger.e("Error sending location: $e");
        }
      },
    );

    // isTracking = true;
    _notifyListRefresh();
  }

  Future<void> _syncOfflineData() async {
    // Get all records that are not yet marked as 'sent'
    final unsentRecords = await LocalStorageHelper.getUnsentLocations();
    if (unsentRecords.isEmpty) return;

    AppLogger.i("Attempting to sync ${unsentRecords.length} unsent records.");

    for (var record in unsentRecords) {
      final recordId = record['id'] as String;
      final locationData = record['data'] as Map<String, dynamic>;

      try {
        final response = await dio.post(apiUrl, data: locationData);

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Update status to 'sent' upon success
          await LocalStorageHelper.updateRecordStatus(recordId, 'sent');
          AppLogger.i("✅ Synced record ID: $recordId");
        } else {
          // If a non-200 status is returned, stop sync and keep for later
          AppLogger.w(
            "Sync stopped: API returned status ${response.statusCode} for record ID: $recordId",
          );
          return;
        }
      } catch (e) {
        // If an error occurs (like connection loss during sync), stop and keep remaining records for later
        AppLogger.e("Sync stopped due to connection error: $e");
        return;
      }
    }

    AppLogger.i("All unsent data synced successfully.");
    // Run cleanup after a successful sync to remove any records older than 3 hours
    await LocalStorageHelper.cleanupOldRecords();

    _notifyListRefresh();
  }

  void _configureBackgroundGeolocation() async {
    await bg.BackgroundGeolocation.ready(
      bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 10,
        stopOnTerminate: false,
        startOnBoot: true,
        enableHeadless: true,
        foregroundService: true,
        notification: bg.Notification(
          channelName: 'Hajj Notifications',
          channelId: 'hajj_channel_id',
          title: 'Tracking Active',
          text: 'Your location is being tracked',
        ),
        debug: true,
        logLevel: bg.Config.LOG_LEVEL_VERBOSE,
      ),
    );
    AppLogger.i("status Tracking : $isTracking");
    // if(isTracking){
    //   _startTrackingTimer();
    // }

    // Listen to location updates
    bg.BackgroundGeolocation.onLocation((bg.Location location) {
      setState(() {
        latitudeText = location.coords.latitude.toString();
        longitudeText = location.coords.longitude.toString();
      });
      AppLogger.i("status Tracking : $isTracking");
      if(isTracking ==  true){
        _startTrackingTimer();
      }
    });
  }

  Future<void> updateTrackingNotification({
    required String status,
    required double latitude,
    required double longitude,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'hajj_channel_id',
      'Hajj Notifications',
      channelDescription: 'Notification channel for Hajj Tracker',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      playSound: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0, // Use same ID so it updates instead of creating a new notification
      'Tracking Active',
      'Status: $status\nLat: $latitude\nLng: $longitude',
      notificationDetails,
      payload: 'tracking_payload',
    );
  }

  Future<void> _startTracking() async {
    await saveTrackingState(true);
    await bg.BackgroundGeolocation.start();
    setState(() => isTracking = true);
  }

  Future<void> _stopTracking() async {
    await saveTrackingState(false);
    await bg.BackgroundGeolocation.stop();
    setState(() => isTracking = false);
  }

  @override
  void dispose() {
    bg.BackgroundGeolocation.removeListeners();
    super.dispose();
  }

  Future<void> onIntervalChanged(int newMinutes) async {
    setState(() {
      trackingIntervalMinutes = newMinutes;
    });

    if (isTracking) {
      await bg.BackgroundGeolocation.stop();
      setState(() => isTracking = false);
      Future.delayed(const Duration(milliseconds: 100), () async {
        await bg.BackgroundGeolocation.setConfig(
          bg.Config(extras: {"trackingIntervalMinutes": newMinutes}),
        );
        await bg.BackgroundGeolocation.start();
        setState(() => isTracking = true);
        AppLogger.i("Tracking started");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 150),
              child: Column(
                children: [
                  // Header
                  SizedBox(
                    width: double.infinity,
                    height: 120,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -50,
                          right: -50,
                          child: Opacity(
                            opacity: 0.2,
                            child: Image.asset(
                              'assets/images/logos/Logo.png',
                              width: 180,
                              height: 180,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 24,
                          top: 40,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Textwidgets("Tracking", fontSize: 40),
                              Textwidgets("Excellence", fontSize: 40),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 35),

                  // Current location card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final isSmallScreen = screenWidth < 360;
                        final fontScale = isSmallScreen ? 0.9 : 1.0;
                        final horizontalPadding = isSmallScreen ? 12.0 : 20.0;

                        return Container(
                          padding: EdgeInsets.all(horizontalPadding),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 2,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Textwidgets(
                                      "Current Location",
                                      fontSize: 20 * fontScale,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Textwidgets(
                                        "Online",
                                        fontSize: 16 * fontScale,
                                      ),
                                      const SizedBox(width: 6),
                                      SignalStrengthIndicator.sector(
                                        value: 0.6,
                                        size: 18 * fontScale,
                                        barCount: 4,
                                        spacing: 0.2,
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Address + button
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Textwidgets(
                                          addressText,
                                          fontSize: 16 * fontScale,
                                        ),
                                        const SizedBox(height: 4),
                                        Textwidgets(
                                          "Device ID $_deviceId",
                                          fontSize: 14 * fontScale,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (!isTracking) {
                                        final confirmed =
                                            await showCustomDialog(
                                              context,
                                              DialogType.tracking,
                                            );
                                        if (confirmed == true) {
                                          // showSimpleNotification();
                                          // startTracking();
                                          _startTracking();
                                          setState(() => isTracking = true);
                                          AppLogger.i("Tracking started");
                                        }
                                      } else {
                                        // await flutterLocalNotificationsPlugin
                                        //     .cancel(0);
                                        // stopTracking();
                                        _stopTracking();
                                        setState(() => isTracking = false);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isTracking
                                          ? Colors.orange.shade700
                                          : Colors.orange,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 16 : 24,
                                        vertical: isSmallScreen ? 8 : 10,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isTracking) ...[
                                          const PulsingDot(color: Colors.white),
                                          const SizedBox(width: 8),
                                        ],
                                        Textwidgets(
                                          isTracking ? "Stop Track" : "Track",
                                          color: Colors.white,
                                          fontSize: 14 * fontScale,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),
                              Divider(color: Colors.grey.shade400, height: 20),
                              const SizedBox(height: 12),
                              Textwidgets(
                                "Coordinate",
                                fontSize: 16 * fontScale,
                              ),
                              const SizedBox(height: 8),
                              Textwidgets(
                                "Latitude : $latitudeText\nLongitude : $longitudeText",
                                fontSize: 14 * fontScale,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListInformation(
            key: _listInfoKey,
            onIntervalChanged: onIntervalChanged,
          ),
        ],
      ),
    );
  }
}
