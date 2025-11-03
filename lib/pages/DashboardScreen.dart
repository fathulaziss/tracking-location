import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:logger/logger.dart';

// ------------------------------------
// 2. Dashboard Screen
// ------------------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Location location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

  String _deviceInfo = 'Memuat informasi perangkat...';
  String _currentLocationText = 'Memuat lokasi saat ini...';
  bool _isTracking = false;
  var logger = Logger();

  @override
  void initState() {
    super.initState();
    _getDeviceInfo();
    _checkLocationServiceStatus();
  }

  // --- DEVICE INFO LOGIC (Tidak berubah) ---
  Future<void> _getDeviceInfo() async {
    String info = 'Tidak tersedia';
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        info = 'Model: ${androidInfo.model}\nOS: Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
        info = 'Model: ${iosInfo.model}\nOS: iOS ${iosInfo.systemVersion}';
      } else {
        info = 'Perangkat tidak didukung';
      }
    } catch (e) {
      info = 'Gagal mendapatkan info perangkat: $e';
    }

    if (mounted) {
      setState(() {
        _deviceInfo = info;
      });
    }
  }

  // --- LOCATION LOGIC (Tidak berubah) ---
  Future<void> _checkLocationServiceStatus() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        _updateLocationText('Layanan Lokasi dinonaktifkan.');
        return;
      }
    }
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        _updateLocationText('Izin Lokasi ditolak.');
        return;
      }
    }
    _getCurrentLocation();
  }

  void _updateLocationText(String text) {
    if (mounted) {
      setState(() {
        _currentLocationText = text;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    _updateLocationText('Mengambil koordinat...');
    try {
      LocationData locationData = await location.getLocation();
      _updateLocationText(_formatLocation(locationData));
    } on PlatformException catch (e) {
      _updateLocationText('Gagal mendapatkan lokasi: ${e.message}');
    }
  }

  String _formatLocation(LocationData data) {
    return 'Lat: ${data.latitude?.toStringAsFixed(6) ?? 'N/A'}\nLon: ${data.longitude?.toStringAsFixed(6) ?? 'N/A'}\nAkurasi: ${data.accuracy?.toStringAsFixed(1) ?? 'N/A'}m';
  }

  // --- TRACKING LOGIC (Tidak berubah) ---
  Future<void> _startTracking() async {
    await location.enableBackgroundMode(enable: true);
    await location.changeSettings(
      distanceFilter: 10,
      interval: 5000,
    );
    _locationSubscription = location.onLocationChanged.listen(
          (LocationData data) {
        final String formattedCoord = 'Lat: ${data.latitude}, Lon: ${data.longitude}, Time: ${DateTime.now().toIso8601String()}';
        logger.i('[Hajj Tracker - TRACKING] Mengirim Koordinat: $formattedCoord');
        _updateLocationText(_formatLocation(data));
      },
      onError: (error) {
        logger.e('[Hajj Tracker - ERROR] Kesalahan Tracking: $error');
        _updateLocationText('Kesalahan saat melacak lokasi.');
        _stopTracking();
      },
      cancelOnError: true,
    );
    if (mounted) {
      setState(() {
        _isTracking = true;
      });
    }
    logger.w('[Hajj Tracker] Pelacakan Haji DIMULAI.');
  }

  void _stopTracking() {
    _locationSubscription?.cancel();
    location.enableBackgroundMode(enable: false);
    if (mounted) {
      setState(() {
        _isTracking = false;
        _currentLocationText = 'Pelacakan berhenti. Tekan MULAI untuk melanjutkan.';
      });
    }
    logger.w('[Hajj Tracker] Pelacakan Haji DIHENTIKAN.');
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  // --- UI DENGAN APPBAR YANG LEBIH BAIK ---
  @override
  Widget build(BuildContext context) {
    // Warna tema
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      // App Bar dengan tampilan yang lebih kaya
      appBar: AppBar(
        title: const Text('Hajj Tracking Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(Icons.location_searching, color: Colors.white, size: 28),
          ),
        ],
        // Menambahkan garis bawah untuk pemisah visual yang elegan
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.white54,
            height: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Kartu Status Tracking ---
            Card(
              elevation: 8, // Elevated shadow
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: _isTracking ? Colors.green.shade600 : Colors.red.shade400,
                    width: 2
                ),
              ),
              color: _isTracking ? Colors.green.shade50 : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isTracking ? 'STATUS: AKTIF MELACAK' : 'STATUS: TIDAK AKTIF',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _isTracking ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isTracking
                          ? 'Pelacakan aktif! Data lokasi dikirim ke server secara periodik, termasuk di latar belakang.'
                          : 'Tekan tombol MULAI untuk mengaktifkan pelacakan real-time jamaah haji.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // --- Lokasi Saat Ini ---
            _buildInfoCard(
              icon: Icons.my_location,
              title: 'Koordinat Lokasi',
              content: _currentLocationText,
              color: primaryColor, // Menggunakan warna primer tema
              bgColor: Colors.lightGreen.shade50,
            ),
            const SizedBox(height: 20),

            // --- Informasi Perangkat ---
            _buildInfoCard(
              icon: Icons.phone_android,
              title: 'Perangkat & Sistem Operasi',
              content: _deviceInfo,
              color: Colors.blueGrey.shade600,
              bgColor: Colors.blueGrey.shade50,
            ),
            const SizedBox(height: 40),

            // --- Tombol Mulai/Hentikan Pelacakan ---
            _buildTrackingButton(primaryColor),

            const SizedBox(height: 10),
            Text(
              _isTracking
                  ? 'Anda dapat menutup aplikasi. Pelacakan tetap berjalan.'
                  : 'Pastikan layanan lokasi aktif dan izin diberikan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingButton(Color primaryColor) {
    return ElevatedButton.icon(
      onPressed: () {
        if (_isTracking) {
          _stopTracking();
        } else {
          _startTracking();
        }
      },
      icon: Icon(
        _isTracking ? Icons.stop_circle_outlined : Icons.track_changes,
        size: 28,
      ),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          _isTracking ? 'HENTIKAN PELACAKAN' : 'MULAI PELACAKAN HAJI',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isTracking ? Colors.red.shade600 : primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        shadowColor: _isTracking ? Colors.red.shade900 : Colors.green.shade900,
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
    required Color bgColor,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}