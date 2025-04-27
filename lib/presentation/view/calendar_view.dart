// lib/presentation/view/calendar_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mama_care/navigation/router.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:mama_care/domain/entities/calendar_notes_model.dart';
import 'package:mama_care/domain/entities/appointment.dart'; // Import Appointment
import 'package:mama_care/presentation/viewmodel/calendar_viewmodel.dart';
import 'package:mama_care/presentation/widgets/appointment_card.dart'; // Import AppointmentCard
import 'package:mama_care/utils/app_colors.dart'; // Import colors
import 'package:mama_care/utils/text_styles.dart'; // Import text styles
import 'package:mama_care/domain/entities/user_role.dart'; // Import UserRole
import 'package:mama_care/presentation/viewmodel/auth_viewmodel.dart'; // To get userId
import 'package:logger/logger.dart'; // For logging
import 'package:mama_care/injection.dart'; // For logger locator

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late final CalendarViewModel _vm;
  final TextEditingController _noteController = TextEditingController();
  final Logger _logger = locator<Logger>(); // Use logger

  @override
  void initState() {
    super.initState();
    // Get ViewModel using read for initState
    _vm = context.read<CalendarViewModel>();
    // Load initial data after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _vm.loadDataForSelectedDate(); // Load data for the initial date
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer to rebuild when ViewModel changes
    return Consumer<CalendarViewModel>(
      builder: (context, vm, _) {
        return Column(
          children: [
            // Calendar Widget
            _buildCalendar(vm),
            const SizedBox(height: 8), // Reduced spacing

            // Error Display
            if (vm.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  "Error: ${vm.error}",
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ),

            // Loading Indicator (subtle)
            if (vm.isLoading)
               const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.0),
                  child: LinearProgressIndicator(minHeight: 2, color: AppColors.primaryLight),
               ),

            // Section Header for Selected Day
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                "Events for ${DateFormat.yMMMd().format(vm.selectedDate)}",
                style: TextStyles.title.copyWith(fontSize: 14.sp),
              ),
            ),
            const Divider(height: 1),

            // List of Events (Notes and Appointments)
            _buildEventsList(vm),

             // Optional: Add Note Input Field (Can be moved to a separate screen/dialog)
             //_buildAddNoteField(context, vm),
          ],
        );
      },
    );
  }

  // Builds the TableCalendar widget
  Widget _buildCalendar(CalendarViewModel vm) {
    return TableCalendar<dynamic>( // Use dynamic for event loader type
      focusedDay: vm.focusedDate, // Use focusedDate from VM
      selectedDayPredicate: (day) => isSameDay(vm.selectedDate, day),
      firstDay: DateTime.utc(DateTime.now().year - 1, 1, 1), // Example range: 1 year back
      lastDay: DateTime.utc(DateTime.now().year + 1, 12, 31), // Example range: 1 year forward
      calendarFormat: CalendarFormat.month, // Default to month view
      availableCalendarFormats: const { // Limit available formats
          CalendarFormat.month: 'Month',
          CalendarFormat.twoWeeks: '2 Weeks',
          CalendarFormat.week: 'Week',
      },
      // Load events (notes + appointments) using getter from VM
      eventLoader: (day) => vm.eventsForSelectedDate.where((event) {
          if (event is CalendarNote) return isSameDay(event.date, day);
          if (event is Appointment) return isSameDay(event.appointmentDateTime, day);
          return false;
      }).toList(),
      // Update selected and focused day in VM
      onDaySelected: (selectedDay, focusedDay) {
          // Check if already selected to avoid redundant loads
          if (!isSameDay(vm.selectedDate, selectedDay)) {
             vm.updateSelectedDate(selectedDay, focusedDay);
          }
      },
      onPageChanged: (focusedDay) {
         // Update only the focused day in VM when page changes
         vm.updateFocusedDate(focusedDay); // Requires updateFocusedDate in VM
      },
      // --- Styling ---
      headerStyle: HeaderStyle(
          formatButtonVisible: true, // Show format button
          titleCentered: true,
          titleTextStyle: TextStyles.title.copyWith(fontSize: 15.sp),
          formatButtonTextStyle: TextStyle(fontSize: 11.sp),
          formatButtonDecoration: BoxDecoration(
             border: Border.all(color: AppColors.primaryLight),
             borderRadius: BorderRadius.circular(12.0),
          ),
           leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.primary),
           rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.primary),
      ),
      calendarStyle: CalendarStyle(
        // Highlight today
        todayDecoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        // Highlight selected day
        selectedDecoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
         selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
         todayTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        // Style for event markers
        markerDecoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.8), // Use a different color for markers
          shape: BoxShape.circle,
        ),
         markersMaxCount: 3, // Show max 3 dots
         markerSize: 5.0,
         markerMargin: const EdgeInsets.symmetric(horizontal: 0.5),
         outsideDaysVisible: false, // Hide days outside the current month
      ),
       daysOfWeekStyle: DaysOfWeekStyle(
         weekdayStyle: TextStyle(fontSize: 11.sp, color: Colors.black54),
         weekendStyle: TextStyle(fontSize: 11.sp, color: AppColors.primary),
      ),
    );
  }

  // Builds the list showing notes and appointments for the selected day
  Widget _buildEventsList(CalendarViewModel vm) {
    final events = vm.eventsForSelectedDate; // Get combined list

    if (vm.isLoading) {
       return const Expanded(child: Center(child: Text("Loading events..."))); // Show text while loading list
    }

    if (events.isEmpty) {
      return Expanded(
        child: Center(
          child: Text(
            'No events or notes for this day.',
            style: TextStyles.bodyGrey,
          ),
        ),
      );
    }

    // Get necessary context for AppointmentCard actions
    final authViewModel = context.read<AuthViewModel>();
    final userId = authViewModel.currentUser?.uid;
    final userRole = authViewModel.userRole;


    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];

          if (event is CalendarNote) {
            return _buildNoteItem(event, vm); // Use existing note item builder
          } else if (event is Appointment) {
            // Use the AppointmentCard, passing required info
            return AppointmentCard(
               appointment: event,
               // Determine role and ID (assuming this view is for the logged-in user)
               userRole: userRole, // Get role from AuthViewModel
               currentUserId: userId ?? '', // Get ID from AuthViewModel
               onTap: () {
                  _logger.d("Tapped appointment ${event.id} from calendar");
                  // TODO: Navigate to appointment detail
                   Navigator.pushNamed(context, NavigationRoutes.appointmentDetail, arguments: event.id);
               },
            );
          } else {
            return const SizedBox.shrink(); // Should not happen
          }
        },
      ),
    );
  }

  // Builds a list item for a CalendarNote
  Widget _buildNoteItem(CalendarNote note, CalendarViewModel vm) {
    return Card( // Wrap note in a card for better separation
       margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
       elevation: 1,
       child: ListTile(
         leading: const Icon(Icons.note_alt_outlined, color: AppColors.secondary),
         title: Text(note.noteText, style: TextStyles.body),
         // subtitle: Text(DateFormat.yMMMd().format(note.date)), // Date already shown in header
         trailing: IconButton(
           icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
           tooltip: "Delete Note",
           iconSize: 20,
           onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Delete Note?"),
                  content: const Text("Are you sure you want to delete this note?"),
                  actions: [
                     TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text("Cancel")),
                     TextButton(onPressed: ()=> Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                  ],
                )
              );
              if(confirm ?? false) {
                 vm.deleteNote(note.id!);
              }
           },
         ),
       ),
    );
  }


  // Optional: Widget to add a new note (can be moved to a Dialog)
  Widget _buildAddNoteField(BuildContext context, CalendarViewModel vm) {
      final authViewModel = context.read<AuthViewModel>();
      final userId = authViewModel.currentUser?.uid;

     return Padding(
       padding: const EdgeInsets.all(16.0),
       child: Row(
         children: [
           Expanded(
             child: TextField(
               controller: _noteController,
               decoration: InputDecoration(
                 hintText: 'Add a note for ${DateFormat.yMd().format(vm.selectedDate)}...',
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                 contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
               ),
               textCapitalization: TextCapitalization.sentences,
               onSubmitted: (text) { // Add on enter key press
                  if(userId != null) {
                     vm.addNote(text, userId);
                     _noteController.clear();
                     FocusScope.of(context).unfocus(); // Hide keyboard
                  }
               },
             ),
           ),
           IconButton(
             icon: const Icon(Icons.add_circle, color: AppColors.primary),
             tooltip: "Save Note",
             onPressed: () {
               if (_noteController.text.isNotEmpty && userId != null) {
                 vm.addNote(_noteController.text, userId);
                 _noteController.clear();
                 FocusScope.of(context).unfocus(); // Hide keyboard
               } else if (userId == null){
                  ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("Please log in to add notes."))
                  );
               }
             },
           ),
         ],
       ),
     );
   }


  @override
  void dispose() {
    _noteController.dispose();
    // No need to dispose _vm if provided by Provider higher up
    super.dispose();
  }
 
}


