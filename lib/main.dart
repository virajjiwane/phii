import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:phii/core/utils/logging.dart';
import 'package:phii/screens/home_screen.dart';

import 'core/themes/app_theme.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLogging(showDebugLogs: true);
  await Alarm.init();

  await Hive.initFlutter();
  Hive.registerAdapter(ProfileAdapter());
  await Hive.openBox<Profile>('profiles');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomeScreen(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
    );
  }
}