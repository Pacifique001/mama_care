import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/presentation/viewmodel/dashboard_viewmodel.dart';
import 'package:mama_care/presentation/view/dashboard_view.dart';
import 'package:mama_care/domain/usecases/dashboard_use_case.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/injection.dart'; // Import your locator

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DashboardViewModel(
        locator<DashboardUseCase>(),
        locator<DatabaseHelper>(),
        locator<Logger>(),
        locator<FirebaseAuth>(),
      )..loadData(),
      child: const DashboardView(),
    );
  }
}