import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/presentation/viewmodel/onboarding_viewmodel.dart';
import 'package:mama_care/presentation/screen/onboarding/OnboardingStack.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OnBoardingViewModel(),
      child: const OnboardingStack(index: 0),
    );
  }
}