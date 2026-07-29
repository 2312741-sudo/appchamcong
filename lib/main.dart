import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Firebase - may already be configured natively by AppDelegate
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase initialization: $e');
  }

  // Initialize Hive for local storage
  try {
    await Hive.initFlutter();
    // Use compaction to clean up lock files from prior crashes
    await Hive.openBox('attendance_offline',
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 20);
    await Hive.openBox('app_cache',
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 20);
  } catch (e) {
    debugPrint('Hive initialization error: $e');
    // If Hive fails, try deleting and re-creating
    try {
      await Hive.deleteBoxFromDisk('attendance_offline');
      await Hive.deleteBoxFromDisk('app_cache');
      await Hive.openBox('attendance_offline');
      await Hive.openBox('app_cache');
    } catch (_) {}
  }

  // Global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exception}');
  };

  runApp(
    const ProviderScope(
      child: ChamCongTramApp(),
    ),
  );
}
