import 'package:flutter/material.dart';
import 'package:mama_care/presentation/screen/pregnancy_detail_screen.dart';
import 'package:mama_care/presentation/screen/video_list_screen.dart';
import 'package:mama_care/presentation/screen/article_list_screen.dart';
import 'package:mama_care/presentation/screen/article_screen.dart';
import 'package:mama_care/presentation/screen/dashboard_screen.dart';
import 'package:mama_care/presentation/screen/error_screen.dart';
import 'package:mama_care/presentation/screen/exercise_detail_screen.dart';
import 'package:mama_care/presentation/screen/exercise_screen.dart';
import 'package:mama_care/presentation/screen/hospital_screen.dart';
import 'package:mama_care/presentation/screen/login_screen.dart';
import 'package:mama_care/presentation/screen/onboarding/on_boarding_page.dart';
import 'package:mama_care/presentation/screen/signup_screen.dart';
import 'package:mama_care/presentation/screen/suggested_food_screen.dart';

import '../presentation/screen/predicition_screen.dart';
import '../presentation/screen/mama_care_screen.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger('RouteGenerator');

abstract class NavigationRoutes {
  static const String login = '/login';
  static const String mainScreen = '/';
  static const String dashboard = '/dashboard';
  static const String onboarding = '/onboarding';
  static const String signup = '/signup';
  static const String articleList = '/profile/article_list';
  static const String article = '/article';
  static const String advise = '/advise';
  static const String map = '/dashboard/map';
  static const String exercise = '/exercise';
  static const String exerciseDetail = '/exercise/detail';
  static const String food = '/food';
  static const String video_list = '/video_list';
  static const String predictor = '/predictor';
  static const String otpVerification = '/otpVerification';
  
  static const String pregnancy_detail = '/pregnancy_detail';
}

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    _logger.info('Generating route for: ${settings.name}');
    try {
      switch (settings.name) {
        case NavigationRoutes.mainScreen:
          return MaterialPageRoute(builder: (_) => const MamaCareScreen());
        case NavigationRoutes.map:
          return MaterialPageRoute(builder: (_) => const HospitalScreen());
        case NavigationRoutes.articleList:
          return MaterialPageRoute(builder: (_) => const ArticleListScreen());
        case NavigationRoutes.article:
          final articleId = settings.arguments as String?;
          if (articleId == null) {
            _logger.warning('Article ID is null for route: ${settings.name}');
            return MaterialPageRoute(builder: (_) => NotFoundScreen(errorMessage: 'Article ID is required'));
          }
          return MaterialPageRoute(
            builder: (_) => ArticleScreen(articleId: articleId),
          );
        case NavigationRoutes.login:
          return MaterialPageRoute(builder: (_) => const LoginScreen());
        case NavigationRoutes.predictor:
          return MaterialPageRoute(builder: (_) => const PredictionScreen());
        case NavigationRoutes.onboarding:
          return MaterialPageRoute(builder: (_) => const OnBoardingPage());
        case NavigationRoutes.signup:
          return MaterialPageRoute(builder: (_) => const SignUpScreen());
        case NavigationRoutes.dashboard:
          return MaterialPageRoute(builder: (_) => const DashboardScreen());
        case NavigationRoutes.exercise:
          return MaterialPageRoute(builder: (_) => const ExerciseScreen());
        case NavigationRoutes.video_list:
          return MaterialPageRoute(builder: (_) => const VideoListScreen());
        case NavigationRoutes.food:
          return MaterialPageRoute(builder: (_) => const SuggestedFoodScreen());
        case NavigationRoutes.pregnancy_detail:
          return MaterialPageRoute(builder: (_) => const PregnancyDetailScreen());
        case NavigationRoutes.exerciseDetail:
          // Extract exercise details from arguments or use defaults
          final arguments = settings.arguments as Map<String, String>?;
          final title = arguments?['title'] ?? "Default Exercise";
          final description = arguments?['description'] ?? "No description available";
          final image = arguments?['image'] ?? "assets/images/dancing.png"; // Provide a default image path

          return MaterialPageRoute(
            builder: (_) => ExerciseDetailPage(
              title: title,
              description: description,
              image: image,
            ),
          );
        default:
          _logger.warning('No route defined for ${settings.name}');
          return MaterialPageRoute(builder: (_) => NotFoundScreen(errorMessage: 'No route defined for ${settings.name}'));
      }
    } catch (e, stackTrace) {
      _logger.severe('Route generation failed for ${settings.name}', e, stackTrace);
      return MaterialPageRoute(
        builder: (_) => NotFoundScreen(
          errorMessage: 'Route generation failed: ${e.toString()}',
        ),
      );
    }
  }
}