// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'; // Import kReleaseMode
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/presentation/screen/error_screen.dart'; // Import Splash Screen
//import 'package:mama_care/presentation/viewmodel/dashboard_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:sizer/sizer.dart';

import 'data/local/database_helper.dart';
import 'domain/usecases/notification_use_case.dart';
import 'firebase_options.dart';
import 'injection.dart';
import 'navigation/navigation_service.dart';
import 'navigation/router.dart';
import 'presentation/viewmodel/auth_viewmodel.dart';
import 'presentation/viewmodel/doctor_dashboard_viewmodel.dart';
import 'utils/app_theme.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:device_preview/device_preview.dart'; // <-- Import Device Preview
import 'package:intl/date_symbol_data_local.dart'; // Import for locale data init

// Use locator to get the logger instance configured via DI
final Logger _logger = locator<Logger>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _initializeApplication();

    // --- Wrap the app with DevicePreview ---
    // Enable it only in debug mode (kDebugMode)
    runApp(
      DevicePreview(
        enabled: !kReleaseMode, // Enable only in debug/profile mode
        builder: (context) => const MamaCareApp(), // Wrap your app
      ),
    );
    // -------------------------------------
  } catch (error, stackTrace) {
    final initLogger = Logger(printer: PrettyPrinter());
    initLogger.f(
      'Application initialization failed fatally.',
      error: error,
      stackTrace: stackTrace,
    );
    // Don't wrap ErrorApp in DevicePreview
    runApp(ErrorApp(error: error, stackTrace: stackTrace));
  }
}

Future<void> _initializeApplication() async {
  // Initialize Intl data (Needed if using DevicePreview locales)
  await initializeDateFormatting(); // Initialize default locale data

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Logger(printer: SimplePrinter()).i('Firebase initialized successfully.');
  await configureDependencies();
  _logger.i('Dependency Injection configured.');
  await _initializeDatabase();
  await _setupNotifications();
  _logger.i('Application initialization complete.');
}

Future<void> _initializeDatabase() async {
  // ... (implementation remains the same) ...
  try {
    final databaseHelper = locator<DatabaseHelper>();
    await databaseHelper.database;
    await databaseHelper.transaction((txn) async {
      await txn.insert('preferences', {
        'key': 'onboarding_completed',
        'value': '0',
      }, conflictAlgorithm: sqflite.ConflictAlgorithm.ignore);
      await txn.insert('preferences', {
        'key': 'theme',
        'value': 'system',
      }, conflictAlgorithm: sqflite.ConflictAlgorithm.ignore);
    });
    await databaseHelper.performMaintenance();
    _logger.i('Database initialized and initial preferences set.');
  } catch (e, stackTrace) {
    _logger.e(
      'Database initialization failed',
      error: e,
      stackTrace: stackTrace,
    );
    throw Exception('Failed to initialize database: ${e.toString()}');
  }
}

Future<void> _setupNotifications() async {
  try {
    await locator<NotificationUseCase>().initialize();
    _logger.i('Notifications initialized successfully.');
  } catch (e, stackTrace) {
    _logger.w('Notification setup failed', error: e, stackTrace: stackTrace);
  }
}

// Main Application Widget
class MamaCareApp extends StatelessWidget {
  const MamaCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: _buildProviders(),
      child: Sizer(
        builder: (context, orientation, deviceType) {
          return MaterialApp(
            // --- DevicePreview Integration ---
            locale: DevicePreview.locale(
              context,
            ), // Use locale from DevicePreview
            builder: DevicePreview.appBuilder, // Use builder from DevicePreview
            // ---------------------------------
            useInheritedMediaQuery: true, // Important for DevicePreview
            debugShowCheckedModeBanner: false,
            title: 'MamaCare',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system, // Keep or make dynamic later
            navigatorKey: NavigationService.navigatorKey,
            initialRoute: NavigationRoutes.splash, // Start with Splash
            onGenerateRoute: RouteGenerator.generateRoute,
            onUnknownRoute:
                (settings) => MaterialPageRoute(
                  builder:
                      (_) => NotFoundScreen(
                        errorMessage: 'Route Not Found',
                        errorDetails: 'No route defined for ${settings.name}',
                      ),
                ),
          );
        },
      ),
    );
  }

  // --- Provider Setup ---
  List<SingleChildWidget> _buildProviders() {
    return [
      ChangeNotifierProvider<AuthViewModel>(
        create: (_) => locator<AuthViewModel>(),
      ),
    ChangeNotifierProvider<DoctorDashboardViewModel>(
    create: (_) => locator<DoctorDashboardViewModel>(),),
    ];
  }
}

// --- Initialization Error App Widget ---
class ErrorApp extends StatelessWidget {
  final dynamic error;
  final StackTrace? stackTrace;
  const ErrorApp({super.key, required this.error, this.stackTrace});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: NotFoundScreen(
          errorMessage: 'Application Initialization Failed',
          errorDetails: '$error\n\n${stackTrace ?? ''}',
          onRetry: () {
            Logger(
              printer: SimplePrinter(),
            ).w('Retrying application initialization...');
            main(); // Call main() to restart the process
          },
        ),
      ),
    );
  }
}
