import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:location/location.dart';
import 'package:logger/logger.dart';
import 'package:signal_strength_indicator/signal_strength_indicator.dart';
import 'package:tracking_location/helper/local_storage_helper.dart';
import 'package:tracking_location/helper/location_helper.dart';
import 'package:tracking_location/pages/TrackingScreen/widgets/ListInformation.dart';
import 'package:tracking_location/pages/TrackingScreen/widgets/permission_dialog.dart';
import 'package:tracking_location/services/background_service.dart';
import 'package:tracking_location/widgets/PulsingDot.dart';
import 'package:tracking_location/widgets/TextWidgets.dart';

import '../../main.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with WidgetsBindingObserver {
  bool isTracking = false;
  final Location location = Location();
  Timer? _timer;
  int trackingIntervalMinutes = 1;
  StreamSubscription<LocationData>? _locationSubscription;
  final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
  String latitudeText = 'Memuat...';
  String longitudeText = 'Memuat...';
  String addressText = 'Memuat...';
  String accuracyText = '';
  String errorText = '';
  final LocationHelper locationHelper = LocationHelper();
  var logger = Logger();
  final Battery _battery = Battery();
  final dio = Dio();
  static const String apiUrl = 'http://34.101.176.197/api/v1/tracking';
  static const int userId = 1;
  final GlobalKey<ListInformationState> _listInfoKey =
      GlobalKey<ListInformationState>();
  String _deviceInfo = 'Memuat informasi perangkat...';
  String _deviceId = "";
  String _deviceName = "";
   void _notifyListRefresh() {
    // 2. Use the key to access the state and call the refresh method
    _listInfoKey.currentState?.loadTrackingRecords();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _onCheckLocationPressed();
    _getDeviceInfo();
    // Run initial cleanup on app start
    // LocalStorageHelper.cleanupOldRecords();
    LocalStorageHelper.clearAllHistory();

    Connectivity().onConnectivityChanged.listen((status) async {
      if (status != ConnectivityResult.none) {
        logger.i("🌐 Network reconnected — syncing offline data");
        await _syncOfflineData();
      }
    });
  }

  // --- DEVICE INFO LOGIC (Tidak berubah) ---
  Future<void> _getDeviceInfo() async {
    String info = 'Tidak tersedia';
    String? id = '';
    String? name = '';
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        info = '${androidInfo.name} - ${androidInfo.id}';
        id = androidInfo.id;
        name = androidInfo.name;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
        info = '${iosInfo.model} - ${iosInfo.identifierForVendor}';
        id = iosInfo.identifierForVendor;
        name = iosInfo.name;
      } else {
        info = 'Perangkat tidak didukung';
      }
      logger.i(info);
    } catch (e) {
      info = 'Gagal mendapatkan info perangkat: $e';
    }

    if (mounted) {
      setState(() {
        _deviceInfo = info;
        _deviceId = id ?? '';
        _deviceName = name ?? '';
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state case AppLifecycleState.resumed) {
      if (isTracking) {
        logger.i('✅ App is in foreground (onResume)');
        _stopBackgroundTracking();
        startTracking();
      }
    } else if (state case AppLifecycleState.paused) {
      if (isTracking) {
        logger.i('⏸️ App is in background (onPause)');
        stopTracking();
        _startBackgroundTracking();
      }
    } else if (state case AppLifecycleState.detached) {
      logger.i('❌ App is detached (destroyed)');
    }
  }

  Future<void> showSimpleNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'hajj_channel_id', // unique channel id
          'Hajj Notifications', // channel name
          channelDescription: 'Notification channel for Hajj Tracker',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          ongoing: true, // keeps it active (cannot be swiped away)
          autoCancel: false, // tapping it won't dismiss
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0, // notification id
      'Tracking Active', // title
      'Your location tracking is running...!', // body
      notificationDetails,
      payload: 'tracking_payload', // optional
    );
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

  Future<void> _onCheckLocationPressed() async {
    await initializeService();

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

  Future<void> startTracking() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    _locationSubscription = location.onLocationChanged.listen((locationData) async{
      setState(() {
        latitudeText = locationData.latitude?.toString() ?? '-';
        longitudeText = locationData.longitude?.toString() ?? '-';
        accuracyText = locationData.accuracy?.toString() ?? '-';
      });
      // Just update notification without sending to server
      // await updateTrackingNotification(
      //   status: isTracking ? "Tracking..." : "Paused",
      //   latitude: locationData.latitude ?? 0,
      //   longitude: locationData.longitude ?? 0,
      // );
    });

    await _sendLocation();
    _timer = Timer.periodic(
      Duration(minutes: trackingIntervalMinutes),
      (timer) async => await _sendLocation(),
    );
  }

  Future<void> _sendLocation() async {
    final loc = await location.getLocation();
    var batteryLevel = await _battery.batteryLevel;
    final currentDateTime = DateTime.now().toIso8601String();

    final data = {
      'device': {
        'id' : _deviceId,
        'name' : _deviceName
      },
      'latitude': loc.latitude,
      'longitude': loc.longitude,
      'created_at': currentDateTime,
      'batrai': batteryLevel,
      'signal_level': 100,
    };
    logger.i("Attempting to send location: $data");

    // Save the attempt immediately with 'pending' status
    // Note: We're relying on _syncOfflineData to find this record later.
    await LocalStorageHelper.saveTrackingAttempt(data, 'pending');

    String sendStatus = "Pending";

    try {
      // NOTE: We assume the last added record is the one we are attempting to send.
      // A more robust way would be to get the ID back from saveTrackingAttempt.
      // For this example, we'll simply check if the send was successful and then
      // run a sync right after, which will mark it as sent.

      final response = await dio.post(apiUrl, data: data);

      if (response.statusCode == 200 || response.statusCode == 201) {
        logger.i("✅ Location sent successfully");
        // Run sync immediately to mark this (and any other pending) record as sent
        sendStatus = "Success";
        await _syncOfflineData();
      } else {
        // If API returns an error status code (but not a connection error)
        logger.w(
          "API returned status ${response.statusCode}. Will retry later.",
        );
        sendStatus = "Failed (${response.statusCode})";
        // The record is already saved as 'pending', no change needed.
      }

      await updateTrackingNotification(
        status: sendStatus,
        latitude: loc.latitude ?? 0,
        longitude: loc.longitude ?? 0,
      );
    } catch (e) {
      logger.e("Error sending location (connection error): $e");
      // The record is already saved as 'pending', it will be retried.
    }

    // Always clean up old records after a send attempt
    await LocalStorageHelper.cleanupOldRecords();

    _notifyListRefresh();
  }

  Future<void> _syncOfflineData() async {
    // Get all records that are not yet marked as 'sent'
    final unsentRecords = await LocalStorageHelper.getUnsentLocations();
    if (unsentRecords.isEmpty) return;

    logger.i("Attempting to sync ${unsentRecords.length} unsent records.");

    for (var record in unsentRecords) {
      final recordId = record['id'] as String;
      final locationData = record['data'] as Map<String, dynamic>;

      try {
        final response = await dio.post(apiUrl, data: locationData);

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Update status to 'sent' upon success
          await LocalStorageHelper.updateRecordStatus(recordId, 'sent');
          logger.i("✅ Synced record ID: $recordId");
        } else {
          // If a non-200 status is returned, stop sync and keep for later
          logger.w(
            "Sync stopped: API returned status ${response.statusCode} for record ID: $recordId",
          );
          return;
        }
      } catch (e) {
        // If an error occurs (like connection loss during sync), stop and keep remaining records for later
        logger.e("Sync stopped due to connection error: $e");
        return;
      }
    }

    logger.i("All unsent data synced successfully.");
    // Run cleanup after a successful sync to remove any records older than 3 hours
    await LocalStorageHelper.cleanupOldRecords();

    _notifyListRefresh();
  }

  void stopTracking() {
    _locationSubscription?.cancel();
    _timer?.cancel();
  }

  void onIntervalChanged(int newMinutes) {
    setState(() {
      trackingIntervalMinutes = newMinutes;
    });

    if (isTracking) {
      stopTracking();
      setState(() => isTracking = false);
      Future.delayed(const Duration(milliseconds: 100), () {
        startTracking();
        setState(() => isTracking = true);
        logger.i("Tracking started");
      });
    }
  }

  Future<void> _startBackgroundTracking() async {
    await FlutterBackgroundService().startService();
    FlutterBackgroundService().invoke("startScheduler", {
      "minutes": trackingIntervalMinutes,
      "deviceId" : _deviceId,
      "deviceName": _deviceName,
    });
  }

  void _stopBackgroundTracking() {
    FlutterBackgroundService().invoke("stopService");
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
                                          "Device ID $_deviceInfo",
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
                                          showSimpleNotification();
                                          startTracking();
                                          setState(() => isTracking = true);
                                          logger.i("Tracking started");
                                        }
                                      } else {
                                        await flutterLocalNotificationsPlugin
                                            .cancel(0);
                                        stopTracking();
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

          // Draggable bottom info sheet
          ListInformation(
            key: _listInfoKey, // Pass the key here
            onIntervalChanged: onIntervalChanged,
          ),
        ],
      ),
    );
  }
}
