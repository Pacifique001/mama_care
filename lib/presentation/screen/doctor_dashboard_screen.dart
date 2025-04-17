
import 'package:flutter/material.dart';
//import 'package:intl/intl.dart'; // For DateFormat if used in cards
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/presentation/viewmodel/doctor_dashboard_viewmodel.dart';
import 'package:mama_care/presentation/widgets/appointment_card.dart'; // Use your existing AppointmentCard
import 'package:mama_care/presentation/widgets/nurse_assignment_card.dart';
//import 'package:mama_care/domain/entities/nurse_assignment.dart';
import 'package:mama_care/domain/entities/appointment.dart';
import 'package:mama_care/presentation/widgets/nurse_assignment_header.dart';
import 'package:mama_care/utils/app_colors.dart';
import 'package:mama_care/utils/text_styles.dart';
import 'package:mama_care/injection.dart'; // For locator
import 'package:mama_care/navigation/router.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To get doctor ID
import 'package:sizer/sizer.dart';

// Main screen for the Doctor Dashboard with Tabs
class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  final Logger _logger = locator<Logger>();
  String? _doctorId; // Store doctorId

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialDataWithCheck();
    });
  }

  // Helper to get doctorId and load data
  void _loadInitialDataWithCheck() {
    _doctorId = FirebaseAuth.instance.currentUser?.uid;
    if (_doctorId != null) {
      _logger.d("DoctorDashboardScreen: Triggering initial data load for doctor $_doctorId.");
      // Use context.read as it's called once in initState callback
      context.read<DoctorDashboardViewModel>().loadData(_doctorId!);
    } else {
      _logger.e("DoctorDashboardScreen: Cannot load data, doctorId is null.");
      // Show error or navigate away
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Error: Could not verify doctor identity."), backgroundColor: Colors.red),
         );
         // Consider Navigator.pop(context) or navigation to login
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Doctor Dashboard'),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? AppColors.primary,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
          bottom: TabBar(
            indicatorColor: AppColors.accent,
            labelColor: Theme.of(context).tabBarTheme.labelColor ?? AppColors.accent,
            unselectedLabelColor: Theme.of(context).tabBarTheme.unselectedLabelColor ?? Colors.white70,
            labelStyle: TextStyles.bodyBold.copyWith(fontSize: 12.sp),
            unselectedLabelStyle: TextStyles.body.copyWith(fontSize: 12.sp),
            tabs: const [
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.calendar_today_outlined, size: 18), SizedBox(width: 8), Text('Appointments')])),
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.people_outline, size: 18), SizedBox(width: 8), Text('Nurses')])),
            ],
          ),
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: [
            AppointmentManagementTab(),
            NurseManagementTab(),
          ],
        ),
        floatingActionButton: Builder(builder: (context) {
          final tabIndex = DefaultTabController.of(context).index;
          return FloatingActionButton(
            onPressed: () => _onFabPressed(context, tabIndex),
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black87,
            tooltip: tabIndex == 0 ? 'Block Schedule' : 'Assign Nurse',
            child: Icon(tabIndex == 0 ? Icons.event_note_outlined : Icons.person_add_alt),
          );
        }),
      ),
    );
  }

  // FAB action handler (remains mostly the same)
  void _onFabPressed(BuildContext context, int tabIndex) {
     if (tabIndex == 0) {
        _logger.i("FAB tapped: Action for Appointments tab (e.g., Block Schedule)");
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Schedule blocking feature not implemented.")));
     } else {
        _logger.i("FAB tapped: Navigate to Assign Nurse screen");
        // Ensure route exists
        Navigator.pushNamed(context, NavigationRoutes.assignNurse); // CREATE THIS ROUTE/SCREEN
     }
  }
}

// --- Tab 1: Appointment Management ---
class AppointmentManagementTab extends StatelessWidget {
  const AppointmentManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Use watch to rebuild when filteredAppointments or selectedFilterStatus changes
    final viewModel = context.watch<DoctorDashboardViewModel>();

    return Column(
      children: [
        // Filter widget
        _buildStatusFilter(context, viewModel),

        // List of appointments
        Expanded(
          // Cannot use RefreshIndicator easily as there's no simple loadAppointments method
          child: _buildAppointmentList(context, viewModel),
        ),
      ],
    );
  }

  // Builds the list or placeholder states
  Widget _buildAppointmentList(BuildContext context, DoctorDashboardViewModel viewModel) {
     // ViewModel doesn't have loading/error states, UI reflects stream directly
     final appointments = viewModel.filteredAppointments;

     if (appointments.isEmpty) {
        // Cannot reliably distinguish between "no appointments at all" vs "none match filter"
        // without access to the full `_appointments` list from the ViewModel.
        return Center(
             child: Padding(
               padding: const EdgeInsets.all(20.0),
               child: Text(
                  "No appointments found for the selected filter.", // Simplified message
                  style: TextStyles.bodyGrey,
                  textAlign: TextAlign.center,
               ),
             )
          );
     }

     // Display the list
     return ListView.builder(
       padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
       itemCount: appointments.length,
       itemBuilder: (context, index) {
         final appointment = appointments[index];
         // Use the provided AppointmentCard widget
         // Actions are now handled *within* AppointmentCard
         return AppointmentCard(
           appointment: appointment, onTap: () {  },
         );
       },
     );
  }

   // --- Status Filter Widget Implementation ---
   // Needs access to the *currently selected* filter status from VM
  Widget _buildStatusFilter(BuildContext context, DoctorDashboardViewModel viewModel) {
    final List<AppointmentStatus> allStatuses = AppointmentStatus.values;
    // Get current filter status from ViewModel (Needs a getter)
    final currentFilter = viewModel.selectedFilterStatus; // <--- ADD THIS GETTER TO VIEWMODEL

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: allStatuses.length + 1, // +1 for "All"
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            // "All" Chip
            if (index == 0) {
              final bool isSelected = currentFilter == null; // 'All' means null filter
              return FilterChip(
                label: const Text('All'),
                selected: isSelected,
                onSelected: (selected) { if (selected) viewModel.setFilterStatus(AppointmentStatus.pending); }, // Pass null
                // Styling... (use previous styling)
                 selectedColor: AppColors.primary.withOpacity(0.15), checkmarkColor: AppColors.primary,
                 labelStyle: TextStyle(fontSize: 11.sp, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primary : AppColors.textGrey),
                 shape: StadiumBorder(side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.shade300)), showCheckmark: false, backgroundColor: Colors.white, elevation: isSelected ? 1 : 0, padding: EdgeInsets.symmetric(horizontal: 10),
              );
            }
            // Status Chips
            final status = allStatuses[index - 1];
            final bool isSelected = currentFilter == status;
            return FilterChip(
              label: Text(status.name.capitalize()),
              selected: isSelected,
              onSelected: (selected) { if (selected) viewModel.setFilterStatus(status); }, // Pass the status enum
              // Styling... (use previous styling)
               selectedColor: AppColors.primary.withOpacity(0.15), checkmarkColor: AppColors.primary,
               labelStyle: TextStyle(fontSize: 11.sp, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primary : AppColors.textGrey),
               shape: StadiumBorder(side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.shade300)), showCheckmark: false, backgroundColor: Colors.white, elevation: isSelected ? 1 : 0, padding: EdgeInsets.symmetric(horizontal: 10),
            );
          },
        ),
      ),
    );
  }

   // Removed _buildAppointmentActions and _showCancelConfirmationDialog
   // This logic now resides within AppointmentCard
}

// Extension to capitalize string
extension StringExtension on String {
    String capitalize() {
      if (isEmpty) return this;
      return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
    }
}


// --- Tab 2: Nurse Management ---
class NurseManagementTab extends StatelessWidget {
  const NurseManagementTab({super.key});
  
  get nurse => null;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DoctorDashboardViewModel>();
    final Logger logger = locator<Logger>();

    return Column(
      children: [
        // Header
        NurseAssignmentHeader(
           totalAssignments: viewModel.nurseAssignments.length,
           onFilterPressed: () {
              logger.i("Nurse Filter action triggered.");
              _showNurseFilterDialog(context, viewModel); // Keep placeholder dialog
           },
        ),

        // List of nurse assignments
        Expanded(
          // Cannot easily add RefreshIndicator without a dedicated load method in VM
          child: _buildNurseList(context, viewModel),
        ),
      ],
    );
  }

   // Builds the nurse list or placeholder states
   Widget _buildNurseList(BuildContext context, DoctorDashboardViewModel viewModel) {
     // No loading/error state from VM, list updates via stream
     final assignments = viewModel.nurseAssignments;

     if (assignments.isEmpty) {
        // Cannot determine if list is truly empty or stream hasn't emitted yet without loading state
         return Center(child: Text("No nurses found or assigned.", style: TextStyles.bodyGrey));
     }

     // Display Nurse List
     return ListView.builder(
       padding: const EdgeInsets.only(bottom: 80.0, left: 0, right: 0),
       itemCount: assignments.length,
       itemBuilder: (context, index) {
         final assignment = assignments[index];
         final nurse = assignment.nurse;
         // Ensure NurseAssignment entity provides needed data for card
         return NurseAssignmentCard(
         nurse: nurse,
           
           // Actions are handled within the card's options menu
         );
       },
     );
   }

   // Placeholder for Nurse Filter Dialog
   void _showNurseFilterDialog(BuildContext context, DoctorDashboardViewModel viewModel) {
      final Logger logger = locator<Logger>();
      logger.d("Showing Nurse Filter Dialog (placeholder)");
     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         title: const Text("Filter Nurses"),
         content: const Text("Implement nurse filtering options here."),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
           TextButton(onPressed: () {
              // viewModel.filterNurses(...); // Apply filter (needs implementation in VM)
              Navigator.pop(ctx);
           }, child: const Text("Apply Filters")),
         ],
       ),
     );
   }
}

// --- NurseAssignmentHeader Widget ---
// (Ensure this widget exists and is imported)

// --- AppointmentCardWidget ---
// *** IMPORTANT: This widget NOW needs to handle its own actions ***
// It should use context.read<DoctorDashboardViewModel>() to call
// updateAppointmentStatus when its internal Check/Close buttons are pressed.
// Remove _buildActionButtons and _handleStatusUpdate from AppointmentCard.

// --- NurseAssignmentCard Widget ---
// (Ensure this widget exists and handles its own actions via options menu)