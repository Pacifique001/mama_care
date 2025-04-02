import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/injection.dart';
import 'package:mama_care/domain/usecases/hospital_use_case.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/presentation/view/hospital_view.dart';
import 'package:mama_care/presentation/viewmodel/hospital_viewmodel.dart';

class HospitalScreen extends StatelessWidget {
  const HospitalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HospitalViewModel(
        locator<HospitalUseCase>(),
        locator<DatabaseHelper>(),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hospitals'),
        ),
        body: const HospitalView(),
      ),
    );
  }
}
