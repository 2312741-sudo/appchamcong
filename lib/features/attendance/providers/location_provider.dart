import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../../store/providers/store_provider.dart';
import '../../../core/utils/location_utils.dart';

// ---------- Location permission ----------

final locationPermissionProvider = FutureProvider<bool>((ref) async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  } catch (_) {
    return false;
  }
});

// ---------- Current position ----------

final currentPositionProvider = FutureProvider<Position?>((ref) async {
  final hasPermission = await ref.watch(locationPermissionProvider.future);
  if (!hasPermission) return null;

  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  } catch (_) {
    return null;
  }
});

// ---------- Current WiFi IP ----------

final currentWifiIPProvider = FutureProvider<String?>((ref) async {
  try {
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    return ip?.trim();
  } catch (_) {
    return null;
  }
});

// ---------- Can check-in composite ----------

typedef CheckInStatus = ({bool canCheck, bool isWifi, bool isGps});

final canCheckInProvider = FutureProvider<CheckInStatus>((ref) async {
  final store = ref.watch(currentStoreProvider).whenOrNull(data: (s) => s);
  if (store == null) {
    return (canCheck: false, isWifi: false, isGps: false);
  }

  // WiFi check
  bool isWifi = false;
  if (store.hasWifi) {
    try {
      final allowedIPs = <String>[];
      if (store.networkIP != null && store.networkIP!.isNotEmpty) allowedIPs.add(store.networkIP!);
      for (final w in store.wifis) {
        if (w.ip.isNotEmpty) allowedIPs.add(w.ip);
      }
      isWifi = await LocationUtils.isOnStoreNetwork(allowedIPs);
    } catch (_) {
      isWifi = false;
    }
  }

  // GPS check
  bool isGps = false;
  if (store.hasLocation) {
    try {
      final position = await ref.watch(currentPositionProvider.future);
      if (position != null) {
        final distanceMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          store.latitude!,
          store.longitude!,
        );
        isGps = distanceMeters <= store.radiusMeters;
      }
    } catch (_) {
      isGps = false;
    }
  }

  final canCheck = isWifi || isGps;
  return (canCheck: canCheck, isWifi: isWifi, isGps: isGps);
});

// ---------- Distance to store (meters) ----------

final distanceToStoreProvider = FutureProvider<double?>((ref) async {
  try {
    final store = ref.watch(currentStoreProvider).whenOrNull(data: (s) => s);
    if (store == null || !store.hasLocation) return null;

    final position = await ref.watch(currentPositionProvider.future);
    if (position == null) return null;

    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      store.latitude!,
      store.longitude!,
    );
  } catch (_) {
    return null;
  }
});
