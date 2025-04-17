import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:mama_care/domain/entities/calendar_notes_model.dart';
import 'package:mama_care/presentation/viewmodel/calendar_viewmodel.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late final CalendarViewModel _vm;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm = context.read<CalendarViewModel>();
    _vm.loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarViewModel>(
      builder: (context, vm, _) {
        return Column(
          children: [
            _buildCalendar(vm),
            const SizedBox(height: 20),
            _buildNotesList(vm),
          ],
        );
      },
    );
  }

  Widget _buildCalendar(CalendarViewModel vm) {
    return TableCalendar(
      focusedDay: vm.selectedDate,
      firstDay: DateTime.utc(2020),
      lastDay: DateTime.utc(2030),
      calendarFormat: CalendarFormat.month,
      eventLoader: (day) => _getEventsForDay(day, vm),
      onDaySelected: (selected, focused) => vm.updateSelectedDate(selected),
      calendarStyle: const CalendarStyle(
        markerDecoration: BoxDecoration(
          color: Colors.pinkAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  List<dynamic> _getEventsForDay(DateTime day, CalendarViewModel vm) {
    return vm.notes.where((note) => _isSameDay(note.date, day)).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildNotesList(CalendarViewModel vm) {
    return Expanded(
      child: ListView.builder(
        itemCount: vm.notes.length,
        itemBuilder: (context, index) => _buildNoteItem(vm.notes[index], vm),
      ),
    );
  }

  Widget _buildNoteItem(CalendarNote note, CalendarViewModel vm) {
    return ListTile(
      leading: const Icon(Icons.notes, color: Colors.pinkAccent),
      title: Text(note.noteText),
      subtitle: Text(DateFormat.yMMMd().format(note.date)),
      trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () => vm.deleteNote(note.id!),
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }
}