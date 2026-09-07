import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/bloc/app_bloc_observer.dart';
import 'core/di/injection.dart';
import 'core/storage/preferences_storage.dart';
import 'core/storage/secure_storage.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  configureDependencies();

  // Set up global Bloc observer
  Bloc.observer = AppBlocObserver();

  // Initialize storage
  final prefs = await SharedPreferences.getInstance();
  final secureStorage = SecureStorage(const FlutterSecureStorage());
  final preferencesStorage = PreferencesStorage(prefs);

  runApp(
    MainApp(
      secureStorage: secureStorage,
      preferencesStorage: preferencesStorage,
    ),
  );
}
