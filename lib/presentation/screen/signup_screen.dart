import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/presentation/view/signup_view.dart';
import 'package:mama_care/presentation/viewmodel/signup_viewmodel.dart';
import 'package:mama_care/domain/usecases/signup_use_case.dart';
import 'package:mama_care/data/repositories/signup_repository.dart';
import 'package:mama_care/injection.dart';
import 'package:mama_care/domain/usecases/login_use_case.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/presentation/viewmodel/auth_viewmodel.dart';
import 'package:mama_care/domain/repositories/firebase_auth_repository.dart'; 

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SignupViewModel(
        locator<SignupUseCase>(),
        
      ),
      child: const SignUpView(),
    );
  }
}