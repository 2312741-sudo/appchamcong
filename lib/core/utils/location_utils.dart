import 'dart:io';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class LocationUtils {
  static Future<bool> isOnStoreNetwork(List<String> allowedIPs) async {
    if (allowedIPs.isEmpty) return false;
    try {
      final request = await HttpClient().getUrl(Uri.parse('https://api.ipify.org?format=json'));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody);
      final currentIP = data['ip'] as String?;
      return currentIP != null && allowedIPs.contains(currentIP);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isInStoreRange(double lat, double lng, double radiusMeters) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }
      if (permission == LocationPermission.deniedForever) return false;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final distance = Geolocator.distanceBetween(lat, lng, pos.latitude, pos.longitude);
      return distance <= radiusMeters;
    } catch (_) {
      return false;
    }
  }
}
