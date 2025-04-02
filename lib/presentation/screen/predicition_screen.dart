import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/injection.dart';
import 'package:mama_care/domain/usecases/risk_detector_use_case.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/presentation/view/prediction_view.dart';
import 'package:mama_care/presentation/viewmodel/risk_detector_viewmodel.dart';


class PredictionScreen extends StatelessWidget {
  const PredictionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RiskDetectorViewModel(
        locator<RiskDetectorUseCase>(),
        locator<DatabaseHelper>(),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Risk Prediction'),
        ),
        body: const PredictionView(),
      ),
    );
  }
}
