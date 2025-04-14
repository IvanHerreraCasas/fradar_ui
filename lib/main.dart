// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:fradar_ui/data/sources/local_job_storage_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import Data Layer components
import 'package:fradar_ui/data/api/radproc_api.dart';
import 'package:fradar_ui/data/api/settings_api.dart';
import 'package:fradar_ui/data/sources/http_radproc_api.dart';
import 'package:fradar_ui/data/sources/local_settings_api.dart';
import 'package:fradar_ui/data/services/sse_service.dart';

// Import Domain Layer components
import 'package:fradar_ui/domain/repositories/radproc_repository.dart';

// Import App Shell
import 'package:fradar_ui/app/view/app_view.dart';

// Optional: Simple Bloc Observer for debugging
// import 'package:fradar_ui/app/bloc_observer.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Optional: Setup Bloc Observer for debugging state changes
  // Bloc.observer = const AppBlocObserver();

  // --- Dependency Injection Setup ---

  // 1. Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  // 2. Initialize SettingsApi
  final settingsApi = LocalSettingsApi(plugin: sharedPreferences);
  final jobStorageApi = LocalJobStorageApi(plugin: sharedPreferences);

  // 3. Initialize Dio Client
  final baseUrl = await settingsApi.getApiBaseUrl() ?? 'http://localhost:8000/api/v1'; // Default fallback
  final dioOptions = BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  );
  final dioClient = Dio(dioOptions);

  // 4. Initialize RadprocApi
  final radprocApi = HttpRadprocApi(dioClient: dioClient);

    // Create SSE Service (Needs base URL without /api/v1 typically)
  final sseService = SseService(apiBaseUrl: baseUrl);

  // Provide SseService to Repository
  final radprocRepository = RadprocRepository(
    radprocApi: radprocApi,
    settingsApi: settingsApi,
    jobStorageApi: jobStorageApi,
    dioClient: dioClient,
    sseService: sseService, // Provide it here
  );

  // --- Run the App ---
  runApp(
    // Provide the Repository to the widget tree
    RepositoryProvider.value(
      value: radprocRepository,
      child: const App(), // Your main App widget
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FRadar UI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AppView(), // Start with the App Shell
    );
  }
}