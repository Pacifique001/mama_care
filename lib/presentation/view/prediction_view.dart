import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/presentation/viewmodel/risk_detector_viewmodel.dart';
import 'package:mama_care/presentation/widgets/custom_button.dart';
import 'package:mama_care/presentation/widgets/mama_care_app_bar.dart';
import 'package:sizer/sizer.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/navigation/router.dart';

class PredictionView extends StatefulWidget {
  const PredictionView({Key? key}) : super(key: key);

  @override
  State<PredictionView> createState() => _PredictionViewState();
}

class _PredictionViewState extends State<PredictionView> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _sbpController = TextEditingController();
  final _dbpController = TextEditingController();
  final _bsController = TextEditingController();
  final _tempController = TextEditingController();
  final _heartRateController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Consumer<RiskDetectorViewModel>(
      builder: (context, riskDetectorViewModel, _) => Scaffold(
        appBar: MamaCareAppBar(
          title: 'Health Prediction',
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Enter Data",
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.pinkAccent,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        SizedBox(height: 3.h),
                        _buildTextField("Age", "Enter your age in years", _ageController, TextInputType.number),
                        SizedBox(height: 2.h),
                        _buildTextField("Systolic Blood Pressure", "Enter your Systolic BP", _sbpController, TextInputType.number),
                        SizedBox(height: 2.h),
                        _buildTextField("Diastolic Blood Pressure", "Enter your Diastolic BP", _dbpController, TextInputType.number),
                        SizedBox(height: 2.h),
                        _buildTextField("Body Temperature", "In F", _tempController, TextInputType.number),
                        SizedBox(height: 2.h),
                        _buildTextField("Heart Rate", "Enter your heart rate in bps", _heartRateController, TextInputType.number),
                        SizedBox(height: 2.h),
                        _buildTextField("BS", "Enter your BS", _bsController, TextInputType.number),
                        SizedBox(height: 3.h),
                        CustomButton(
                          label: "Get Prediction",
                          onPressed: () async {
                            if (_formKey.currentState?.validate() == true) {
                              final result = await riskDetectorViewModel.getRiskData(
                                int.parse(_ageController.text),
                                int.parse(_sbpController.text),
                                int.parse(_dbpController.text),
                                double.parse(_bsController.text),
                                double.parse(_tempController.text),
                                int.parse(_heartRateController.text),
                              );

                              final dbHelper = DatabaseHelper();
                              await dbHelper.insertPredictionHistory({
                                'age': int.parse(_ageController.text),
                                'sbp': int.parse(_sbpController.text),
                                'dbp': int.parse(_dbpController.text),
                                'bs': double.parse(_bsController.text),
                                'temp': double.parse(_tempController.text),
                                'heartRate': int.parse(_heartRateController.text),
                                'result': result,
                                'timestamp': DateTime.now().millisecondsSinceEpoch,
                              });
                            }
                          },
                          color: Colors.pinkAccent,
                        ),
                        SizedBox(height: 5.h),
                        if (riskDetectorViewModel.riskData != null)
                          Text(
                            riskDetectorViewModel.riskData!.toString(),
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  color: Colors.pinkAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller, TextInputType keyboardType) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.pinkAccent),
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.pinkAccent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.pinkAccent, width: 2),
        ),
      ),
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) {
        if (value?.isEmpty ?? true) {
          return 'Please enter a value';
        }
        return null;
      },
    );
  }
}
