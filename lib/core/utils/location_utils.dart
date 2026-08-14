import 'dart:io';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';

class LocationUtils {
  /// Fetch both public IP and WiFi SSID of the current network connection
  static Future<({String? ip, String? ssid})> getCurrentWifiDetails() async {
    String? publicIp;
    String? wifiSsid;

    // 1. Fetch public IP via ipify (Router WAN IP)
    try {
      final request = await HttpClient()
          .getUrl(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 8));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody);
      publicIp = (data['ip'] as String?)?.trim();
    } catch (_) {}

    // 2. Request location permission first (strictly required by iOS & Android to read WiFi SSID)
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {}

    // 3. Fetch WiFi SSID via network_info_plus
    try {
      final info = NetworkInfo();
      String? rawSsid = await info.getWifiName();
      if (rawSsid != null) {
        // Strip surrounding quotes
        rawSsid = rawSsid.replaceAll('"', '').replaceAll("'", '').trim();
        if (rawSsid.isNotEmpty &&
            rawSsid.toLowerCase() != '<unknown ssid>' &&
            rawSsid.toLowerCase() != 'null') {
          wifiSsid = rawSsid;
        }
      }
    } catch (_) {}

    return (ip: publicIp, ssid: wifiSsid);
  }

  /// Verify if the current device's public IP matches any in the allowed IP list
  static Future<bool> isOnStoreNetwork(List<String> allowedIPs) async {
    final cleanAllowed = allowedIPs
        .map((ip) => ip.trim())
        .where((ip) => ip.isNotEmpty)
        .toList();
    if (cleanAllowed.isEmpty) return false;

    try {
      final request = await HttpClient()
          .getUrl(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 8));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody);
      final currentIP = (data['ip'] as String?)?.trim();
      return currentIP != null && cleanAllowed.contains(currentIP);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isInStoreRange(
      double lat, double lng, double radiusMeters) async {
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

      final distance =
          Geolocator.distanceBetween(lat, lng, pos.latitude, pos.longitude);
      return distance <= radiusMeters;
    } catch (_) {
      return false;
    }
  }
}
