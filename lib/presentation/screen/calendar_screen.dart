import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/injection.dart';
import 'package:mama_care/presentation/view/calendar_view.dart';
import 'package:mama_care/domain/usecases/calendar_use_case.dart';
import 'package:mama_care/presentation/viewmodel/calendar_viewmodel.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CalendarViewModel(locator<CalendarUseCase>()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pregnancy Calendar'),
          actions: [
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: () => context.read<CalendarViewModel>().updateSelectedDate(DateTime.now()),
            ),
          ],
        ),
        body: const CalendarView(),
      ),
    );
  }
}