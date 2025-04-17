// lib/presentation/screen/nurse_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
// Import PatientSummary
import 'package:mama_care/injection.dart'; // Assuming locator for Logger and ViewModel
import 'package:mama_care/presentation/widgets/mama_care_app_bar.dart';
import 'package:mama_care/utils/app_colors.dart';
import 'package:mama_care/utils/text_styles.dart';
import 'package:mama_care/presentation/viewmodel/nurse_dashboard_viewmodel.dart'; // Import ViewModel
import 'package:mama_care/presentation/widgets/patient_summary_card.dart'; // TODO: Create this widget
import 'package:mama_care/presentation/widgets/appointment_card.dart'; // Reuse or create specific card
import 'package:mama_care/navigation/router.dart'; // For navigation
import 'package:provider/provider.dart';
// For default avatar

// Screen Wrapper to provide ViewModel
class NurseDashboardScreenWrapper extends StatelessWidget {
  const NurseDashboardScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => locator<NurseDashboardViewModel>(), // Provide VM via locator
      child: const NurseDashboardScreen(),
    );
  }
}


class NurseDashboardScreen extends StatelessWidget {
  const NurseDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use Consumer to listen to ViewModel state
    return Consumer<NurseDashboardViewModel>(
      builder: (context, viewModel, child) {
        final nurseName = viewModel.nurseProfile?.name.split(' ').first ?? "Nurse";

        return Scaffold(
          appBar: MamaCareAppBar(
             title: "Welcome, $nurseName!", // Personalized title
             actions: [ // Example actions
                IconButton(
                   icon: const Icon(Icons.refresh),
                   tooltip: "Refresh Data",
                   onPressed: viewModel.isLoading ? null : viewModel.refreshData,
                ),
                IconButton(
                   icon: const Icon(Icons.person_outline),
                   tooltip: "My Profile",
                   onPressed: () {
                      if (viewModel.nurseProfile != null) {
                          Navigator.pushNamed(context, NavigationRoutes.nurseDetail, arguments: viewModel.nurseProfile!.id);
                      }
                   },
                ),
             ],
          ),
          body: _buildBody(context, viewModel),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, NurseDashboardViewModel viewModel) {
     if (viewModel.isLoading && viewModel.nurseProfile == null) { // Show loader on initial load
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (viewModel.error != null && viewModel.nurseProfile == null) { // Show error if critical data failed
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
              SizedBox(height: 16),
              Text("Error Loading Dashboard", style: TextStyles.title.copyWith(color: Colors.redAccent)),
              SizedBox(height: 8),
              Text(viewModel.error!, style: TextStyles.bodyGrey, textAlign: TextAlign.center),
              SizedBox(height: 20),
              ElevatedButton( onPressed: viewModel.refreshData, child: const Text("Retry") )
            ],
          ),
        ),
      );
    }

     // Main content with Pull-to-Refresh
     return RefreshIndicator(
       onRefresh: viewModel.refreshData,
       color: AppColors.primary,
       child: ListView( // Use ListView for scrollable content sections
          padding: const EdgeInsets.all(16.0),
          children: [
             // Section 1: Assigned Patients
             _buildSectionHeader(context, "Assigned Patients", Icons.people_alt_outlined),
             _buildAssignedPatientsList(context, viewModel),
             const SizedBox(height: 24),

             // Section 2: Upcoming Appointments/Tasks for Nurse
             _buildSectionHeader(context, "Your Schedule", Icons.calendar_today_outlined),
             _buildUpcomingAppointmentsList(context, viewModel),
             const SizedBox(height: 24),

             // TODO: Add other sections like alerts, messages, quick actions etc.

          ],
       ),
     );
  }

  // Helper for section headers
  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
     return Padding(
       padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
       child: Row(
         children: [
           Icon(icon, color: AppColors.primary, size: 20),
           const SizedBox(width: 8),
           Text(title, style: TextStyles.title),
         ],
       ),
     );
  }

  // Builds the assigned patients list
  Widget _buildAssignedPatientsList(BuildContext context, NurseDashboardViewModel viewModel) {
      final patients = viewModel.assignedPatients;

       if (viewModel.isLoading && patients.isEmpty) { // Show small loader if refreshing this section
          return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)));
       }

      if (patients.isEmpty) {
         return Card( // Use a card for better visual grouping
           elevation: 0,
           color: Colors.grey.shade100,
           child: Padding(
             padding: const EdgeInsets.all(20.0),
             child: Text("No patients currently assigned.", style: TextStyles.bodyGrey, textAlign: TextAlign.center),
           ),
         );
      }

      return ListView.builder(
         shrinkWrap: true, // Important inside ListView
         physics: const NeverScrollableScrollPhysics(), // Disable internal scroll
         itemCount: patients.length,
         itemBuilder: (context, index) {
            final patient = patients[index];
             // TODO: Create PatientSummaryCard widget
            return PatientSummaryCard(
               patient: patient,
               onTap: () {
                  locator<Logger>().i("Tapped patient: ${patient.id}");
                  //Navigator.pushNamed(context, NavigationRoutes.patientDetail, arguments: patient.id); // Navigate to patient detail
               },
            );
         }
      );
  }

   // Builds the upcoming appointments list for the nurse
  Widget _buildUpcomingAppointmentsList(BuildContext context, NurseDashboardViewModel viewModel) {
      final appointments = viewModel.upcomingAppointments;

       if (viewModel.isLoading && appointments.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)));
       }

       if (appointments.isEmpty) {
          return Card(
             elevation: 0,
             color: Colors.grey.shade100,
             child: Padding(
               padding: const EdgeInsets.all(20.0),
               child: Text("No upcoming appointments or tasks.", style: TextStyles.bodyGrey, textAlign: TextAlign.center),
             ),
          );
       }

      return ListView.builder(
         shrinkWrap: true,
         physics: const NeverScrollableScrollPhysics(),
         itemCount: appointments.length,
         itemBuilder: (context, index) {
            final appointment = appointments[index];
            // Use AppointmentCardWidget or a nurse-specific version
            return AppointmentCard(
               appointment: appointment,
               onTap: () {
                  locator<Logger>().i("Tapped appointment: ${appointment.id}");
                   Navigator.pushNamed(context, NavigationRoutes.appointmentDetail, arguments: appointment.id);
               },
               // Nurse might not have actions here, or different ones (e.g., Add Note)
               // actions: [ TextButton(onPressed: (){}, child: Text("Add Note")) ],
            );
         }
      );
  }

}

// --- TODO: Create these Widgets ---
// 1. lib/presentation/widgets/patient_summary_card.dart
//    (Displays PatientSummary info: name, image, maybe due date/status)