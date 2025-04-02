import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:mama_care/injection.dart';
import 'package:mama_care/navigation/router.dart';
import 'package:sizer/sizer.dart';
import 'firebase_options.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/domain/usecases/notification_use_case.dart';
import 'package:mama_care/presentation/screen/error_screen.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger('Main');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _setupLogging();

  try {
    _logger.info('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    _logger.info('Configuring dependencies...');
    await configureDependencies();

    _logger.info('Initializing database...');
    final databaseHelper = locator<DatabaseHelper>();
    await databaseHelper.database;
    await _ensureInitialData(databaseHelper);

    _logger.info('Initializing notifications...');
    final notificationUseCase = locator<NotificationUseCase>();
    await notificationUseCase.initializeNotifications();

    _logger.info('Starting MyApp...');
    runApp(const MyApp());
  } catch (e, stackTrace) {
    _logger.severe('Initialization failed', e, stackTrace);
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Initialization failed: $e'),
          ),
        ),
      ),
    );
  }
}

void _setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      print('Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      print('Stack Trace: ${record.stackTrace}');
    }
  });
}

Future<void> _ensureInitialData(DatabaseHelper databaseHelper) async {
  final isOnboardingCompleted = await databaseHelper.isOnboardingCompleted();
  if (!isOnboardingCompleted) {
    await databaseHelper.setOnboardingCompleted(false);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return FutureBuilder<Map<String, bool>>(
          future: _getAppInitialState(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              _logger.info('Loading...');
              return _buildLoadingApp();
            }

            if (snapshot.hasError) {
              _logger.severe('Error loading app state', snapshot.error);
              return _buildErrorApp(snapshot.error.toString());
            }

            final initialRoute = _determineInitialRoute(snapshot.data ?? {
              'isOnboardingCompleted': false,
              'isLoggedIn': false,
            });

            _logger.info('Initial route determined: $initialRoute');
            return _buildMainApp(initialRoute);
          },
        );
      },
    );
  }

  Future<Map<String, bool>> _getAppInitialState() async {
    try {
      final databaseHelper = locator<DatabaseHelper>();
      return {
        'isOnboardingCompleted': await databaseHelper.isOnboardingCompleted(),
        'isLoggedIn': await databaseHelper.isLoggedIn(),
      };
    } catch (e, stackTrace) {
      _logger.severe('Failed to get app initial state', e, stackTrace);
      return {
        'isOnboardingCompleted': false,
        'isLoggedIn': false,
      };
    }
  }

  String _determineInitialRoute(Map<String, bool> appState) {
    final isOnboardingCompleted = appState['isOnboardingCompleted'] ?? false;
    final isLoggedIn = appState['isLoggedIn'] ?? false;

    if (!isOnboardingCompleted) return NavigationRoutes.onboarding;
    return isLoggedIn ? NavigationRoutes.mainScreen : NavigationRoutes.login;
  }

  Widget _buildLoadingApp() {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              SizedBox(height: 2.h),
              Text(
                'Loading MAMA CARE...',
                style: TextStyle(fontSize: 12.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorApp(String error) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Initialization error: $error',
            style: TextStyle(fontSize: 12.sp, color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildMainApp(String initialRoute) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MAMA CARE',
      initialRoute: initialRoute,
      onGenerateRoute: (settings) {
        try {
          _logger.info('Generating route for: ${settings.name}');
          final route = RouteGenerator.generateRoute(settings);
          // Remove the null check here - route is properly handled in RouteGenerator
          return route;
        } catch (e, stackTrace) {
          _logger.severe('Route generation failed', e, stackTrace);
          return MaterialPageRoute(
            builder: (_) => NotFoundScreen(
              errorMessage: 'Route generation failed: ${e.toString()}',
            ),
          );
        }
      },
      theme: ThemeData(
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: Colors.grey.shade50,
        textTheme: TextTheme(
          headlineLarge: TextStyle(
            fontFamily: 'ProductSans',
            fontWeight: FontWeight.bold,
            fontSize: 26.sp,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 20.sp,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 12.sp,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 10.sp,
          ),
          bodySmall: GoogleFonts.inter(),
        ),
      ),
    );
  }
}