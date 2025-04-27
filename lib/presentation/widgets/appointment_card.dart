// lib/presentation/widgets/appointment_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mama_care/domain/entities/appointment_status.dart'; // Import enum + helpers
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/domain/entities/appointment.dart';
import 'package:mama_care/domain/entities/user_role.dart';
// Import relevant ViewModels - CHOOSE THE RIGHT ONE based on where this card is USED
// Option A: If used ONLY in Doctor's view
// import 'package:mama_care/presentation/viewmodel/doctor_appointments_viewmodel.dart';
// Option B: If used ONLY in Patient's view
// import 'package:mama_care/presentation/viewmodel/patient_appointments_viewmodel.dart';
// Option C: If used ONLY in Nurse's view
// import 'package:mama_care/presentation/viewmodel/nurse_dashboard_viewmodel.dart';
// Option D: If potentially used in MULTIPLE views, you might need a more generic approach
// or pass the specific ViewModel interaction logic via callbacks from the parent view.
// For this example, let's assume it might be used by Doctor or Patient, needing AuthViewModel
import 'package:mama_care/presentation/viewmodel/auth_viewmodel.dart';
// We also need the specific VM to call update actions if we don't pass callbacks
import 'package:mama_care/presentation/viewmodel/doctor_appointments_viewmodel.dart'; // Example for doctor actions
import 'package:mama_care/presentation/viewmodel/patient_appointments_viewmodel.dart'; // Example for patient actions

import 'package:mama_care/utils/app_colors.dart';
import 'package:mama_care/utils/text_styles.dart';
import 'package:mama_care/injection.dart';
import 'package:mama_care/navigation/router.dart';
import 'package:sizer/sizer.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for Timestamp type

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final UserRole userRole; // The role of the person VIEWING the card
  final String currentUserId; // The ID of the person VIEWING the card
  final VoidCallback? onTap; // Optional callback for tapping the whole card

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.userRole,
    required this.currentUserId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormat = DateFormat('EEE, MMM d, yyyy');
    final DateFormat timeFormat = DateFormat('h:mm a');

    // Use the enum status directly from the appointment object
    final AppointmentStatus status = appointment.status;
    // Convert Timestamp to DateTime for display formatting
    final DateTime apptDateTime = appointment.dateTime.toDate();

    // Determine background color based on enum status
    Color cardColor = _getCardBackgroundColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300, width: 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Patient/Doctor Name & Status Chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    // Wrap name in Expanded
                    child: Text(
                      // Show the other party's name
                      userRole == UserRole.doctor
                          ? 'Patient: ${appointment.patientName}'
                          : 'Doctor: ${appointment.doctorName}',
                      style: TextStyles.bodyBold.copyWith(
                        color: AppColors.textDark,
                      ),
                      overflow: TextOverflow.ellipsis, // Prevent overflow
                    ),
                  ),
                  const SizedBox(width: 8), // Add spacing
                  _buildStatusChip(status), // Use enum status
                ],
              ),
              const SizedBox(height: 8),
              // Reason
              Text(
                appointment.reason,
                style: TextStyles.body.copyWith(fontSize: 11.sp),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              // Date & Time Info
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Date: ${dateFormat.format(apptDateTime)}', // Format DateTime
                    style: TextStyles.bodySmall.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Time: ${timeFormat.format(apptDateTime)}', // Format DateTime
                    style: TextStyles.bodySmall.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              // Notes
              if (appointment.notes != null &&
                  appointment.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start, // Align icon nicely
                  children: [
                    Icon(
                      Icons.notes_outlined,
                      size: 14,
                      color: Colors.grey.shade700,
                    ), // Use outlined icon
                    const SizedBox(width: 6),
                    Expanded(
                      // Allow notes to wrap
                      child: Text(
                        'Notes: ${appointment.notes}',
                        style: TextStyles.bodySmall.copyWith(
                          color: Colors.grey.shade700,
                        ),
                        // maxLines: 2, // Allow more lines if needed
                        // overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Divider(height: 1, color: Colors.grey.shade300),
              const SizedBox(height: 4),
              // Action Buttons Row (conditionally built)
              _buildActionButtonsRow(
                context,
                status,
              ), // Pass context and enum status
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper methods ---

  // Get background color based on enum status
  Color _getCardBackgroundColor(AppointmentStatus status) {
    return switch (status) {
      AppointmentStatus.pending => Colors.orange.shade50,
      AppointmentStatus.confirmed ||
      AppointmentStatus.scheduled => Colors.blue.shade50, // Group similar
      AppointmentStatus.completed => Colors.green.shade50,
      AppointmentStatus.cancelled ||
      AppointmentStatus.declined => Colors.red.shade50, // Group similar
    };
  }

  // Build status chip using enum status
  Widget _buildStatusChip(AppointmentStatus status) {
    Color chipColor = switch (status) {
      AppointmentStatus.pending => Colors.orange.shade700,
      AppointmentStatus.confirmed => Colors.blue.shade700,
      AppointmentStatus.cancelled => Colors.grey.shade700,
      AppointmentStatus.completed => Colors.green.shade700,
      AppointmentStatus.scheduled => Colors.purple.shade700,
      AppointmentStatus.declined => Colors.red.shade700,
    };

    IconData chipIcon = switch (status) {
      AppointmentStatus.pending => Icons.hourglass_empty_rounded,
      AppointmentStatus.confirmed => Icons.check_circle_outline_rounded,
      AppointmentStatus.cancelled => Icons.cancel_outlined,
      AppointmentStatus.completed => Icons.task_alt_rounded,
      AppointmentStatus.scheduled => Icons.event_available_rounded,
      AppointmentStatus.declined =>
        Icons.do_not_disturb_on_outlined, // More distinct icon
    };

    return Chip(
      avatar: Icon(chipIcon, size: 14, color: chipColor),
      label: Text(status.name.capitalize()), // Capitalize enum name
      labelStyle: TextStyle(
        fontSize: 9.sp,
        color: chipColor,
        fontWeight: FontWeight.w500,
      ),
      backgroundColor: chipColor.withOpacity(0.1),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      side: BorderSide.none,
    );
  }

  // Builds the row containing appropriate action buttons based on role and status
  Widget _buildActionButtonsRow(
    BuildContext context,
    AppointmentStatus status,
  ) {
    // Delegate based on the role passed to the widget
    switch (userRole) {
      case UserRole.doctor:
        return _buildDoctorActionButtons(context, status);
      case UserRole.patient:
        return _buildPatientActionButtons(context, status);
      case UserRole.nurse:
        // Nurses might complete confirmed appointments or add notes
        return _buildNurseActionButtons(context, status);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Doctor Specific Actions ---
  Widget _buildDoctorActionButtons(
    BuildContext context,
    AppointmentStatus status,
  ) {
    final logger = locator<Logger>();
    // Read the specific ViewModel needed to perform the update action
    final viewModel = context.read<DoctorAppointmentsViewModel>();

    List<Widget> actions = [];

    // --- Actions for PENDING status ---
    if (status == AppointmentStatus.pending) {
      actions.addAll([
        _actionButton(
          context: context,
          icon: Icons.check_circle_outline_rounded,
          label: 'Confirm',
          color: Colors.green.shade700,
          onPressed: () async {
            logger.d(
              "Confirm button pressed for appointment ${appointment.id}",
            );
            final confirmed = await _showConfirmationDialog(
              context,
              title: 'Confirm Appointment',
              content: 'Confirm this appointment request?',
            );
            if (confirmed ?? false) {
              // Call VM method with ENUM value
              await viewModel.updateAppointmentStatus(
                appointment.id!,
                AppointmentStatus.confirmed,
              );
              // Snackbar feedback is handled within the ViewModel's update method now
            }
          },
        ),
        _actionButton(
          context: context,
          icon: Icons.cancel_outlined,
          label: 'Decline', // Changed label
          color: Colors.red.shade700,
          onPressed: () async {
            logger.d(
              "Decline button pressed for appointment ${appointment.id}",
            );
            final confirmed = await _showConfirmationDialog(
              context,
              title: 'Decline Appointment',
              content: 'Are you sure you want to decline this request?',
              confirmText: 'Yes, Decline',
              confirmColor: Colors.red,
            );
            if (confirmed ?? false) {
              // Call VM method with ENUM value
              await viewModel.updateAppointmentStatus(
                appointment.id!,
                AppointmentStatus.declined,
              );
            }
          },
        ),
      ]);
    }
    // --- Actions for CONFIRMED status ---
    else if (status == AppointmentStatus.confirmed ||
        status == AppointmentStatus.scheduled) {
      actions.addAll([
        // Mark as completed action
        _actionButton(
          context: context,
          icon: Icons.task_alt_rounded,
          label: 'Complete',
          color: Colors.blue.shade700,
          onPressed: () async {
            logger.d(
              "Complete button pressed for appointment ${appointment.id}",
            );
            final confirmed = await _showConfirmationDialog(
              context,
              title: 'Mark as Completed',
              content: 'Mark this appointment as completed?',
            );
            if (confirmed ?? false) {
              // Call VM method with ENUM value
              await viewModel.updateAppointmentStatus(
                appointment.id!,
                AppointmentStatus.completed,
              );
            }
          },
        ),
        // Option to Cancel even if confirmed (Maybe only if far enough in future?)
        _actionButton(
          context: context,
          icon: Icons.cancel_outlined,
          label: 'Cancel',
          color: Colors.red.shade700,
          onPressed: () async {
            logger.d(
              "Cancel (confirmed) button pressed for appointment ${appointment.id}",
            );
            final confirmed = await _showConfirmationDialog(
              context,
              title: 'Cancel Confirmed Appointment',
              content:
                  'Cancel this confirmed appointment? The patient will be notified.',
              confirmText: 'Yes, Cancel',
              confirmColor: Colors.red,
            );
            if (confirmed ?? false) {
              // Call VM method with ENUM value
              await viewModel.updateAppointmentStatus(
                appointment.id!,
                AppointmentStatus.cancelled,
              );
            }
          },
        ),
        // TODO: Add Reschedule Action
        // _actionButton(context: context, icon: Icons.edit_calendar_outlined, label: 'Reschedule', color: Colors.orange.shade800, onPressed: () { /* ... */ }),
      ]);
    }
    // --- No actions for completed/cancelled/declined ---
    else {
      return const SizedBox(height: 8); // Maintain some padding
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        alignment: WrapAlignment.end,
        children: actions,
      ),
    );
  }

  // --- Patient Specific Actions ---
  Widget _buildPatientActionButtons(
    BuildContext context,
    AppointmentStatus status,
  ) {
    final viewModel =
        context.read<PatientAppointmentsViewModel>(); // Read Patient VM
    final logger = locator<Logger>();

    // Patient can cancel if pending or confirmed (maybe add time limit logic here)
    if (status == AppointmentStatus.pending ||
        status == AppointmentStatus.confirmed ||
        status == AppointmentStatus.scheduled) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end, // Align button to the right
          children: [
            _actionButton(
              context: context,
              icon: Icons.cancel_outlined,
              label: 'Cancel Request',
              color: Colors.red.shade700,
              onPressed: () async {
                logger.d("Patient cancel request for ${appointment.id}");
                final confirmed = await _showConfirmationDialog(
                  context,
                  title: 'Cancel Appointment',
                  content: 'Are you sure you want to cancel this appointment?',
                  confirmText: 'Yes, Cancel',
                  confirmColor: Colors.red,
                );
                if (confirmed ?? false) {
                  // Call Patient ViewModel's cancel method
                  await viewModel.cancelAppointment(appointment.id!);
                  // Snackbar feedback handled by VM now
                }
              },
            ),
          ],
        ),
      );
    }
    return const SizedBox(height: 8); // Maintain padding
  }

  // --- Nurse Specific Actions (Example) ---
  Widget _buildNurseActionButtons(
    BuildContext context,
    AppointmentStatus status,
  ) {
    // Example: Nurses can only add notes or maybe complete?
    // This depends heavily on your app's specific workflow for nurses.
    List<Widget> actions = [];

    if (status == AppointmentStatus.confirmed ||
        status == AppointmentStatus.scheduled) {
      // Example: Button to add notes (assuming a separate screen/dialog)
      actions.add(
        _actionButton(
          context: context,
          icon: Icons.note_add_outlined,
          label: 'Add Notes',
          color: AppColors.primary,
          onPressed: () {
            locator<Logger>().d("Nurse add notes for ${appointment.id}");
            // TODO: Navigate to Add Notes screen/dialog, passing appointment.id
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Add Notes not implemented.")),
            );
          },
        ),
      );
      // Example: Button to mark as complete (if nurses can do this)
      // actions.add(
      //   _actionButton(
      //     context: context, icon: Icons.check_circle, label: 'Complete',
      //     color: Colors.blue.shade700,
      //     onPressed: () async { /* ... call appropriate VM method ... */ },
      //   ),
      // );
    }

    if (actions.isEmpty) {
      return const SizedBox(height: 8); // Maintain padding if no actions
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        alignment: WrapAlignment.end,
        children: actions,
      ),
    );
  }

  // Helper to build styled action buttons consistently
  Widget _actionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed, // Allow null onPressed
  }) {
    return TextButton.icon(
      icon: Icon(
        icon,
        size: 16,
        color: onPressed == null ? Colors.grey : color,
      ), // Grey out icon if disabled
      label: Text(
        label,
        style: TextStyle(
          color: onPressed == null ? Colors.grey : color,
          fontSize: 11.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
      onPressed: onPressed, // Pass onPressed directly
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        // Maybe add a minimum size if needed
      ),
    );
  }

  // REMOVED _updateStatus - Actions now call ViewModel methods directly

  // Helper for confirmation dialog
  Future<bool?> _showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color confirmColor = AppColors.primary,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must explicitly choose an action
      builder:
          (ctx) => AlertDialog(
            title: Text(title, style: TextStyles.title),
            content: Text(content, style: TextStyles.body),
            actions: <Widget>[
              TextButton(
                child: Text(cancelText),
                onPressed:
                    () =>
                        Navigator.of(ctx).pop(false), // Return false on cancel
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: confirmColor),
                child: Text(confirmText),
                onPressed:
                    () => Navigator.of(ctx).pop(true), // Return true on confirm
              ),
            ],
          ),
    );
  }
} // End AppointmentCard

// Helper extension for capitalizing strings (place in a utility file ideally)
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
