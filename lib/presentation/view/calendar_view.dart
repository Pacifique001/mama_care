import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:mama_care/presentation/viewmodel/calendar_viewmodel.dart';
import '../widgets/mama_care_app_bar.dart';
import '../widgets/custom_text_field.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({Key? key}) : super(key: key);

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final calendarViewModel =
        Provider.of<CalendarViewModel>(context, listen: false);
    calendarViewModel.onSelectedDateChanged(DateTime.now());
    calendarViewModel.loadNotes(); // Fixed: removed the parameter
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarViewModel>(
      builder: (context, calendarViewModel, child) {
        if (calendarViewModel.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return Scaffold(
          drawer: _buildNavigationDrawer(),
          appBar: MamaCareAppBar(
            trailingWidget: IconButton(
              onPressed: () => _showAddNotesDialog(calendarViewModel),
              icon: const Icon(Icons.add, color: Colors.white),
            ),
            title: "Calendar",
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCalendar(calendarViewModel),
                  const SizedBox(height: 20),
                  _buildNotesSection(calendarViewModel),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationDrawer() {
    return NavigationDrawer(
      backgroundColor: Colors.grey.shade50,
      children: [
        _buildDrawerItem(Icons.dashboard_outlined, "Dashboard"),
        _buildDrawerItem(Icons.calendar_today_outlined, "Calendar"),
        _buildDrawerItem(Icons.view_timeline_outlined, "Timeline"),
        _buildDrawerItem(Icons.person_outline_rounded, "Profile"),
      ],
    );
  }

  Widget _buildDrawerItem(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: Icon(icon, color: Colors.pinkAccent),
        title: Text(title, style: const TextStyle(color: Colors.black87)),
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        onTap: () {
          // Add navigation logic here
        },
      ),
    );
  }

  Widget _buildCalendar(CalendarViewModel calendarViewModel) {
    return TableCalendar(
      daysOfWeekStyle: DaysOfWeekStyle(
        dowTextFormatter: (day, _) => DateFormat.E().format(day)[0],
        weekdayStyle: TextStyle(color: Colors.pinkAccent),
        weekendStyle: TextStyle(color: Colors.pinkAccent),
      ),
      headerStyle: HeaderStyle(
        titleCentered: true,
        formatButtonShowsNext: false,
        formatButtonVisible: false,
        titleTextStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.pinkAccent,
              fontWeight: FontWeight.bold,
            ) as TextStyle,
        leftChevronIcon: Container(
          decoration: BoxDecoration(
            border: Border.fromBorderSide(
              BorderSide(width: 2, color: Colors.pinkAccent),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.pinkAccent),
        ),
        rightChevronIcon: Container(
          decoration: BoxDecoration(
            border: Border.fromBorderSide(
              BorderSide(width: 2, color: Colors.pinkAccent),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_forward, color: Colors.pinkAccent),
        ),
      ),
      focusedDay: calendarViewModel.focusedDate ?? DateTime.now(),
      firstDay: DateTime.utc(2010, 10, 16),
      lastDay: DateTime.utc(2030, 3, 14),
      currentDay: calendarViewModel.selectedDate,
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Colors.pinkAccent,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Colors.pinkAccent.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
      ),
      onDaySelected: (selectedDay, focusedDay) {
        calendarViewModel.onSelectedDateChanged(selectedDay);
        calendarViewModel.onFocusedDateChanged(focusedDay);
        calendarViewModel.getCalendarNotes();
      },
    );
  }

  Widget _buildNotesSection(CalendarViewModel calendarViewModel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Notes Created",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.pinkAccent,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 20.h,
            child: calendarViewModel.notesList.isEmpty
                ? Center(
                    child: Text(
                      "No notes for this date",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: calendarViewModel.notesList.length,
                    itemBuilder: (context, index) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.circle,
                                color: Colors.pinkAccent,
                                size: 15,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  calendarViewModel.notesList[index],
                                  style: const TextStyle(color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => calendarViewModel.deleteNotes(index),
                          icon: const Icon(
                            Icons.remove_circle_rounded,
                            color: Colors.pinkAccent,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddNotesDialog(CalendarViewModel calendarViewModel) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(Icons.note, color: Colors.pinkAccent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: const Text('Add Notes', style: TextStyle(color: Colors.pinkAccent)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Selected Date: ${DateFormat('yyyy-MM-dd').format(calendarViewModel.selectedDate!)}",
                  style: const TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: _notesController,
                  hint: "Enter Notes",
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.pinkAccent)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('OK', style: TextStyle(color: Colors.pinkAccent)),
              onPressed: () {
                _addNote();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _addNote() {
    if (_notesController.text.trim().isNotEmpty) {
      final calendarViewModel = Provider.of<CalendarViewModel>(context, listen: false);
      calendarViewModel.addNotes(_notesController.text);
      _notesController.clear();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}