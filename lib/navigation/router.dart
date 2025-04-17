// lib/navigation/router.dart

import 'package:flutter/material.dart';
import 'package:logging/logging.dart'; // Use package:logging
// Assuming locator is here

// --- Import all Screen/View Widgets ---
// Ensure these paths and names are correct in your project

// Onboarding & Auth
import 'package:mama_care/presentation/screen/onboarding/OnboardingScreen.dart';
import 'package:mama_care/presentation/screen/login_screen.dart';
import 'package:mama_care/presentation/screen/signup_screen.dart';
import 'package:mama_care/presentation/view/otp_verification_view.dart';
import 'package:mama_care/presentation/screen/forgot_password_screen.dart';

// Main Structure & Role Dashboards
import 'package:mama_care/presentation/screen/mama_care_screen.dart'; // Patient main wrapper
import 'package:mama_care/presentation/screen/dashboard_screen.dart'; // Patient dashboard view (inside MamaCareScreen?)
import 'package:mama_care/presentation/screen/nurse_dashboard_screen.dart'; // <-- ADD THIS (Create file)
import 'package:mama_care/presentation/screen/doctor_dashboard_screen.dart'; // <-- ADD THIS (Import existing)
import 'package:mama_care/presentation/screen/admin_dashboard_screen.dart'; // <-- ADD THIS (Create file)

// Drawer/Bottom Nav Items (if standalone screens)
import 'package:mama_care/presentation/view/calendar_view.dart';
import 'package:mama_care/presentation/view/timeline_view.dart';
import 'package:mama_care/presentation/view/profile_view.dart';

// Feature Screens
import 'package:mama_care/presentation/screen/article_list_screen.dart';
import 'package:mama_care/presentation/screen/article_screen.dart';
import 'package:mama_care/presentation/screen/hospital_screen.dart';
import 'package:mama_care/presentation/screen/exercise_screen.dart';
import 'package:mama_care/presentation/screen/exercise_detail_screen.dart';
import 'package:mama_care/presentation/screen/video_list_screen.dart';
import 'package:mama_care/presentation/screen/suggested_food_screen.dart';
import 'package:mama_care/presentation/screen/prediction_screen.dart';
import 'package:mama_care/presentation/screen/pregnancy_detail_screen.dart';
import 'package:mama_care/presentation/view/add_appointment_view.dart';

// Nurse Management Screens
import 'package:mama_care/presentation/screen/assign_nurse_screen.dart';
import 'package:mama_care/presentation/screen/nurse_details_screen.dart'; // Use wrapper if providing VM here
import 'package:mama_care/presentation/screen/nurse_assignment_management_screen.dart'; // Use wrapper if providing VM here
import 'package:mama_care/presentation/screen/assign_patient_to_nurse_screen.dart'; // Placeholder created

// Error Screen
import 'package:mama_care/presentation/screen/error_screen.dart';

import 'package:mama_care/utils/asset_helper.dart'; // Should not be needed here


// Use logger from package:logging
final Logger _logger = Logger('RouteGenerator');

/// Defines named routes used throughout the application for navigation.
abstract class NavigationRoutes {
  // --- Core & Auth ---
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String otpVerification = '/otp-verification';
  static const String forgotPassword = '/forgot-password';

  // --- Role-Based Main Screens ---
  static const String mainScreen = '/main'; // Patient Main Screen (e.g., wrapper with bottom nav)
  static const String nurseDashboard = '/nurse/dashboard'; // Nurse Main Screen
  static const String doctorDashboard = '/doctor/dashboard'; // Doctor Main Screen
  static const String adminDashboard = '/admin/dashboard'; // Admin Main Screen

  // --- Sections (potentially nested within main screens or standalone) ---
  static const String dashboard = '/dashboard'; // Specific dashboard content view (if separate from mainScreen)
  static const String calendar = '/calendar';
  static const String timeline = '/timeline';
  static const String profile = '/profile';

  // --- Features ---
  static const String articleList = '/articles';
  static const String article = '/article'; // Detail view (expects ID)
  static const String map = '/map';
  static const String exercise = '/exercise';
  static const String exerciseDetail = '/exercise/detail'; // Expects args
  static const String food = '/food';
  static const String video_list = '/videos';
  static const String predictor = '/predictor';
  static const String pregnancy_detail = '/pregnancy-detail';
  static const String addAppointment = '/add-appointment';
  static const String appointmentDetail = '/appointments/detail';
  static const String rescheduleAppointment = '/appointments/reschedule';

  // --- Nurse/Doctor Management ---
  static const String assignNurse = '/assign-nurse'; // Doctor assigns nurse to patient/appt
  static const String assignPatientToNurse = '/nurses/assign-patient'; // Doctor assigns patient to specific nurse
  static const String nurseDetail = '/nurses/detail'; // View nurse profile (expects ID)
  static const String nurseAssignmentManagement = '/nurses/assignments';

  //static String patientDetail; // Manage assignments for a nurse (expects ID)

  // --- Add other routes ---
}

/// Generates routes based on route settings (name and arguments).
class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final routeName = settings.name;
    final args = settings.arguments;

    _logger.info('Navigating to: $routeName ${args != null ? "with args: $args" : ""}');

    if (routeName == null) {
      _logger.warning('Route name is null.');
      return _errorRoute('Route name cannot be null');
    }

    try {
      switch (routeName) {
        // --- Core & Auth ---
        case NavigationRoutes.splash: return _buildRoute(const OnboardingScreen(), settings: settings); // Replace with actual Splash
        case NavigationRoutes.onboarding: return _buildRoute(const OnboardingScreen(), settings: settings);
        case NavigationRoutes.login: return _buildRoute(const LoginScreen(), settings: settings);
        case NavigationRoutes.signup: return _buildRoute(const SignUpScreen(), settings: settings);
        case NavigationRoutes.otpVerification:
          final email = args as String?;
          return _buildRoute(OtpVerificationView(email: email), settings: settings);
        case NavigationRoutes.forgotPassword: return _buildRoute(const ForgotPasswordScreen(), settings: settings);

        // --- Role-Based Main Screens ---
        case NavigationRoutes.mainScreen: return _buildRoute(const MamaCareScreen(), settings: settings);
        case NavigationRoutes.nurseDashboard: return _buildRoute(const NurseDashboardScreen(), settings: settings); // CREATE THIS SCREEN
        case NavigationRoutes.doctorDashboard: return _buildRoute(const DoctorDashboardScreen(), settings: settings); // EXISTS
        case NavigationRoutes.adminDashboard: return _buildRoute(const AdminDashboardScreen(), settings: settings); // CREATE THIS SCREEN

        // --- Sections ---
        // These might be part of the main screens above, but allow direct nav if needed
        case NavigationRoutes.dashboard: return _buildRoute(const DashboardScreen(), settings: settings); // Patient dashboard content
        case NavigationRoutes.calendar: return _buildRoute(const CalendarView(), settings: settings);
        case NavigationRoutes.timeline: return _buildRoute(const TimelineView(), settings: settings);
        case NavigationRoutes.profile: return _buildRoute(const ProfileView(), settings: settings);

        // --- Features ---
        case NavigationRoutes.articleList: return _buildRoute(const ArticleListScreen(), settings: settings);
        case NavigationRoutes.article: return _handleArticleRoute(settings);
        case NavigationRoutes.map: return _buildRoute(const HospitalScreen(), settings: settings);
        case NavigationRoutes.exercise: return _buildRoute(const ExerciseScreen(), settings: settings);
        case NavigationRoutes.exerciseDetail: return _handleExerciseDetailRoute(settings);
        case NavigationRoutes.video_list: return _buildRoute(const VideoListScreen(), settings: settings);
        case NavigationRoutes.food: return _buildRoute(const SuggestedFoodScreen(), settings: settings);
        case NavigationRoutes.predictor: return _buildRoute(const PredictionScreen(), settings: settings);
        case NavigationRoutes.pregnancy_detail: return _buildRoute(const PregnancyDetailScreen(), settings: settings);
        case NavigationRoutes.addAppointment:
             // final doctorId = args as String?; // Pass if needed
             return _buildRoute(const AddAppointmentView(/*preselectedDoctorId: doctorId*/), settings: settings);
        case NavigationRoutes.appointmentDetail:
            if (args is String) return _errorRoute('Appt Detail screen not implemented'); // Placeholder
            return _errorRoute('Appointment ID missing');
        case NavigationRoutes.rescheduleAppointment:
             if (args is String) return _errorRoute('Reschedule screen not implemented'); // Placeholder
             return _errorRoute('Appointment ID missing');

        // --- Nurse/Doctor Management ---
        case NavigationRoutes.assignNurse:
           final contextId = args as String?;
           return _buildRoute(AssignNurseScreen(contextId: contextId), settings: settings);
        case NavigationRoutes.assignPatientToNurse:
           if (args is String) return _buildRoute(AssignPatientToNurseScreen(nurseId: args), settings: settings); // Use placeholder
           return _errorRoute('Nurse ID missing for assigning patient');
        case NavigationRoutes.nurseDetail:
           if (args is String) return _buildRoute(NurseDetailScreenWrapper(nurseId: args), settings: settings); // Use wrapper
           return _errorRoute('Nurse ID required for nurse details');
        case NavigationRoutes.nurseAssignmentManagement:
           if (args is String) return _buildRoute(NurseAssignmentManagementScreenWrapper(nurseId: args), settings: settings); // Use wrapper
           return _errorRoute('Nurse ID required for assignment management');

        // --- Default Error Route ---
        default:
          _logger.warning('No route defined for: $routeName');
          return _errorRoute('Route not found: $routeName');
      }
    } catch (e, stackTrace) {
      _logger.severe('Route generation failed for $routeName. Args: $args', e, stackTrace);
      return _errorRoute('Failed to display the requested screen.');
    }
  }

  // --- Helper Methods ---
  static MaterialPageRoute<T> _buildRoute<T>(Widget widget, {RouteSettings? settings}) {
    return MaterialPageRoute<T>(builder: (_) => widget, settings: settings);
  }
  static MaterialPageRoute _errorRoute(String message) {
    return MaterialPageRoute(builder: (_) => NotFoundScreen( errorMessage: 'Navigation Error', errorDetails: message,));
  }
  static MaterialPageRoute _handleArticleRoute(RouteSettings settings) {
    // ... (implementation remains the same) ...
    final articleId = settings.arguments as String?;
    if (articleId == null || articleId.isEmpty) { _logger.warning('Article ID missing or empty for route: ${settings.name}'); return _errorRoute('Article ID is required for this route.'); }
    return _buildRoute(ArticleScreen(articleId: articleId), settings: settings);
  }
  static MaterialPageRoute _handleExerciseDetailRoute(RouteSettings settings) {
    // ... (implementation remains the same) ...
    final arguments = settings.arguments;
    if (arguments is Map<String, dynamic>) { final String title = arguments['title'] as String? ?? "Exercise Detail"; final String description = arguments['description'] as String? ?? "No description."; final String imagePath = arguments['image'] as String? ?? AssetsHelper.stretching; return _buildRoute( ExerciseDetailPage( title: title, description: description, image: imagePath, ), settings: settings ); }
    else { _logger.warning('Invalid arguments type for exercise detail: Expected Map<String, dynamic>, got ${arguments?.runtimeType}'); return _errorRoute('Invalid arguments for Exercise Detail.'); }
  }
}

// --- REMINDER: Create the actual screen widget files ---
// - NurseDashboardScreen
// - AdminDashboardScreen
// - Splash Screen (if using '/')
// - AppointmentDetailScreen
// - RescheduleAppointmentScreen
// - AssignPatientToNurseScreen
// - ForgotPasswordScreen (ensure implementation exists)
// - Ensure all other imported screens/views exist