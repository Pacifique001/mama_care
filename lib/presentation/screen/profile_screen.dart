import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/presentation/view/profile_view.dart';
import 'package:mama_care/presentation/viewmodel/profile_viewmodel.dart';
import 'package:mama_care/domain/usecases/profile_use_case.dart';
import 'package:mama_care/injection.dart';
import 'package:mama_care/data/local/database_helper.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileViewModel(
        locator<ProfileUseCase>(),
        locator<DatabaseHelper>(),
      ),
      child: const Scaffold(
        body: ProfileView(),
      ),
    );
  }
}