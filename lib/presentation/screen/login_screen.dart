import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/presentation/view/login_view.dart';
import 'package:mama_care/presentation/viewmodel/auth_viewmodel.dart';
import 'package:mama_care/domain/usecases/login_use_case.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mama_care/domain/repositories/firebase_auth_repository.dart';
import 'package:mama_care/injection.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthViewModel(
        locator<LoginUseCase>(),
        locator<DatabaseHelper>(),
        locator<FirebaseMessaging>(),
        locator<FirebaseAuthRepository>(),
      ),
      child: const Scaffold(
        body: LoginView(),
      ),
    );
  }
}