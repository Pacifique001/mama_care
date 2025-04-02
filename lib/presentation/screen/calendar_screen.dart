import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/presentation/view/calendar_view.dart';
import 'package:mama_care/presentation/viewmodel/calendar_viewmodel.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/domain/usecases/calendar_use_case.dart';
import 'package:mama_care/injection.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CalendarViewModel(
        locator<CalendarUseCase>(),
        locator<DatabaseHelper>(),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Calendar'),
        ),
        body: const CalendarView(),
      ),
    );
  }
}