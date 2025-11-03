import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tracking_location/pages/TrackingScreen/widgets/permission_dialog.dart';

class LocationHelper {
  final Logger logger = Logger();

  Future<String> getAddressFromLatLong(
    double latitude,
    double longitude,
  ) async {
    try {
      List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) return 'Tidak ditemukan alamat.';

      geo.Placemark place = placemarks[0];
      logger.i("Placemark: $place");

      // Kombinasi nama wilayah (sesuaikan kebutuhan)
      String address =
          "${place.street ?? ''}, ${place.subAdministrativeArea ?? ''}, ${place.administrativeArea ?? ''}";
      logger.i("Address: $address");

      return address.trim().isNotEmpty ? address : '-';
    } catch (e) {
      logger.e("Failed to get address: $e");
      return 'Gagal mendapatkan nama lokasi.';
    }
  }

  Future<Map<String, String>> checkLocationServiceStatus(
    BuildContext context,
  ) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return {'error': 'Layanan lokasi dinonaktifkan.'};
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      bool userAgreed = await showCustomDialog(context, DialogType.permission);
      if (!userAgreed) {
        return {'error': 'Izin lokasi dibatalkan oleh pengguna.'};
      }

      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return {'error': 'Izin lokasi ditolak.'};
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return {
        'error': 'Izin lokasi ditolak permanen. Silakan ubah di pengaturan.',
      };
    }

    // 🔸 Android: cek izin tambahan (opsional)
    if (Platform.isAndroid) {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      if (await Permission.locationAlways.isDenied) {
        await Permission.locationAlways.request();
      }
    }

    // Jika semua izin sudah beres → ambil lokasi
    return await _getCurrentLocation();
  }

  Future<Map<String, String>> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final lat = position.latitude.toStringAsFixed(6);
      final lon = position.longitude.toStringAsFixed(6);
      final acc = "${position.accuracy.toStringAsFixed(1)} m";

      String address = await getAddressFromLatLong(
        position.latitude,
        position.longitude,
      );

      logger.w(lat);
      logger.w(lon);
      logger.w(acc);
      logger.w(address);

      return {
        'latitude': 'Lat: $lat',
        'longitude': 'Lon: $lon',
        'accuracy': 'Akurasi: $acc',
        'address': address,
      };
    } catch (e) {
      logger.e("Error getting location: $e");
      return {'error': 'Gagal mendapatkan lokasi: ${e.toString()}'};
    }
  }
}
