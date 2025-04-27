// lib/presentation/view/doctor_appointments_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/domain/entities/appointment.dart';
import 'package:mama_care/domain/entities/appointment_status.dart';
import 'package:mama_care/navigation/router.dart';
import 'package:mama_care/presentation/viewmodel/doctor_appointments_viewmodel.dart';
import 'package:mama_care/presentation/viewmodel/auth_viewmodel.dart'; // Added import for AuthViewModel
import 'package:mama_care/presentation/widgets/mama_care_app_bar.dart';
import 'package:mama_care/utils/app_colors.dart';
import 'package:mama_care/utils/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Added for profile image
//import 'package:mama_care/utils/navigation_routes.dart'; // Added for navigation
import 'package:mama_care/utils/logger.dart'; // Added for logger

class DoctorAppointmentsView extends StatefulWidget {
  const DoctorAppointmentsView({super.key});

  @override
  State<DoctorAppointmentsView> createState() => _DoctorAppointmentsViewState();
}

class _DoctorAppointmentsViewState extends State<DoctorAppointmentsView> {
  final Logger _logger = Logger(); // Added logger

  @override
  void initState() {
    super.initState();
    // Load appointments when the screen initializes (ViewModel handles logic)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Check if still mounted
        context.read<DoctorAppointmentsViewModel>().loadDoctorAppointments();
      }
    });
  }

  // Added navigation helper method
  void _navigateTo(String route) {
    Navigator.of(context).pushReplacementNamed(route);
    _logger.i("Navigating to: $route");
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer for reactivity - now consuming both ViewModels
    return Consumer2<DoctorAppointmentsViewModel, AuthViewModel>(
      builder: (context, appointmentsViewModel, authViewModel, child) {
        return Scaffold(
          appBar: const MamaCareAppBar(title: "Manage Appointments"),
          drawer: _buildDrawer(context, authViewModel), // Added drawer
          body: Column(
            children: [
              // Status filter tabs using Enums
              _buildStatusFilter(appointmentsViewModel),

              // Conditional body content
              Expanded(
                child: _buildMainContent(context, appointmentsViewModel),
              ),
            ],
          ),
        );
      },
    );
  }

  // Drawer implementation integrated from the second document
  Widget _buildDrawer(BuildContext context, AuthViewModel authViewModel) {
    final doctorUser = authViewModel.localUser;
    final permissions = authViewModel.userPermissions;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text(
              doctorUser?.name ?? 'Doctor',
              style: TextStyles.title.copyWith(color: Colors.white),
            ),
            accountEmail: Text(
              doctorUser?.email ?? '',
              style: TextStyles.bodySmall.copyWith(color: Colors.white70),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: AppColors.accent.withOpacity(0.8),
              backgroundImage:
                  (doctorUser?.profileImageUrl != null &&
                          doctorUser!.profileImageUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(doctorUser.profileImageUrl!)
                      : null,
              child:
                  (doctorUser?.profileImageUrl == null ||
                          doctorUser!.profileImageUrl!.isEmpty)
                      ? Text(
                        doctorUser?.name.isNotEmpty == true
                            ? doctorUser!.name[0].toUpperCase()
                            : 'D',
                        style: TextStyle(
                          fontSize: 24.sp,
                          color: Colors.black87,
                        ),
                      )
                      : null,
            ),
            decoration: const BoxDecoration(color: AppColors.primaryDark),
            otherAccountsPictures: [
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: Colors.white70,
                ),
                tooltip: "Settings",
                onPressed: () {
                  _logger.i("Settings icon tapped in drawer");
                },
              ),
            ],
          ),

          if (permissions.contains('view_profile'))
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('My Profile'),
              onTap: () => _navigateTo(NavigationRoutes.profile),
            ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pop(context),
          ),

          // Highlight the current screen in drawer
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Manage Appointments'),
            selected: true,
            selectedTileColor: AppColors.primaryLight.withOpacity(0.15),
            selectedColor: AppColors.primary,
            onTap: () => Navigator.pop(context),
          ),

          if (permissions.contains('view_all_patients'))
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('View Patients'),
              onTap: () {
                _logger.i("Navigate to Patient List (Placeholder)");
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Patient list screen not implemented."),
                  ),
                );
              },
            ),

          if (permissions.contains('manage_nurses'))
            ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Manage Nurses'),
              onTap: () {
                _logger.i("Navigate to Nurse Management");
                _navigateTo(NavigationRoutes.nurseDetail);
              },
            ),

          if (permissions.contains('view_reports'))
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: const Text('View Reports'),
              onTap: () {
                _logger.i("Navigate to Reports (Placeholder)");
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Reports screen not implemented."),
                  ),
                );
              },
            ),

          if (permissions.contains('edit_articles') ||
              permissions.contains('edit_videos')) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(left: 16.0, top: 10.0, bottom: 5.0),
              child: Text(
                "Content Management",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (permissions.contains('edit_articles'))
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('Edit Articles'),
                onTap: () {
                  _logger.i("Navigate to Article Editor");
                  _navigateTo(NavigationRoutes.articleList);
                },
              ),
            if (permissions.contains('edit_videos'))
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Edit Videos'),
                onTap: () {
                  _logger.i("Navigate to Video Editor");
                  _navigateTo(NavigationRoutes.video_list);
                },
              ),
          ],

          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout_outlined),
            title: const Text('Logout'),
            onTap: () {
              _logger.i("Logout tapped");
              context.read<AuthViewModel>().logout();
              _navigateTo(NavigationRoutes.login);
            },
          ),
        ],
      ),
    );
  }

  // Builds the main content area based on ViewModel state
  Widget _buildMainContent(
    BuildContext context,
    DoctorAppointmentsViewModel viewModel,
  ) {
    if (viewModel.isLoading && viewModel.appointments.isEmpty) {
      // Show loading only if list is empty initially
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    } else if (viewModel.error != null) {
      // Show error view (pass the load function for retry)
      return _buildErrorView(
        context,
        viewModel.error!,
        () => viewModel.loadDoctorAppointments(),
      );
    } else if (viewModel.appointments.isEmpty) {
      // Show empty view based on the selected filter (nullable enum)
      return _buildEmptyView(viewModel.selectedStatusFilter);
    } else {
      // Show the list of appointments
      return _buildAppointmentsList(context, viewModel);
    }
  }

  // Builds the filter chips using AppointmentStatus enum
  Widget _buildStatusFilter(DoctorAppointmentsViewModel viewModel) {
    // Define the statuses to display in the filter
    final List<AppointmentStatus?> statuses = [
      null, // Represents 'All'
      AppointmentStatus.pending,
      AppointmentStatus.confirmed,
      AppointmentStatus.declined,
      AppointmentStatus.completed,
      AppointmentStatus.cancelled,
      AppointmentStatus.scheduled,
    ];

    return Container(
      color: Colors.white, // Or theme surface color
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children:
              statuses.map((status) {
                final String label =
                    status?.name.capitalize() ??
                    'All'; // Get capitalized name or 'All'
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _filterChip(
                    viewModel,
                    status,
                    label,
                  ), // Pass enum status (or null)
                );
              }).toList(),
        ),
      ),
    );
  }

  // Filter chip widget - now accepts AppointmentStatus?
  Widget _filterChip(
    DoctorAppointmentsViewModel viewModel,
    AppointmentStatus? statusValue, // Null represents 'all'
    String label,
  ) {
    // Check if this chip's status matches the VM's selected filter
    final bool isSelected = viewModel.selectedStatusFilter == statusValue;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          // Call VM with the AppointmentStatus? value
          viewModel.setStatusFilter(statusValue);
        }
      },
      backgroundColor: AppColors.backgroundLight, // Use theme color
      selectedColor: AppColors.primaryLight.withOpacity(0.2),
      labelStyle: TextStyle(
        fontSize: 11.sp, // Use Sizer
        color:
            isSelected
                ? AppColors.primary
                : AppColors.textGrey, // Use theme colors
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: AppColors.primary,
      shape: StadiumBorder(
        // Use StadiumBorder for rounded ends
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      showCheckmark: false, // Often looks cleaner without the default checkmark
      elevation: isSelected ? 1.0 : 0.0, // Add elevation when selected
      padding: EdgeInsets.symmetric(
        horizontal: 12.sp,
        vertical: 0.8.h,
      ), // Adjust padding
    );
  }

  // Empty view - accepts nullable enum status
  Widget _buildEmptyView(AppointmentStatus? status) {
    String message = "No appointments found"; // Default message
    if (status != null) {
      // Generate message based on the enum status name
      message = "No ${status.name} appointments";
    } else {
      message = "No appointments match the current filter";
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyles.bodyGrey.copyWith(fontSize: 16.sp),
          ), // Use theme style
        ],
      ),
    );
  }

  // Error view - accepts context, error message, and retry callback
  Widget _buildErrorView(
    BuildContext context,
    String error,
    VoidCallback onRetry,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              "Error Loading Appointments",
              style: TextStyles.title.copyWith(color: Colors.redAccent),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyles.body.copyWith(color: Colors.red),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              // Added icon to button
              icon: const Icon(Icons.refresh),
              label: const Text("Try Again"),
              onPressed: onRetry, // Use the passed callback
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the list of appointment cards
  Widget _buildAppointmentsList(
    BuildContext context,
    DoctorAppointmentsViewModel viewModel,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: viewModel.appointments.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final appointment = viewModel.appointments[index];
        // Pass the enum status values to the handlers
        return _AppointmentCard(
          appointment: appointment,
          onApprove:
              () => _handleUpdateStatus(
                context,
                viewModel,
                appointment.id!,
                AppointmentStatus.confirmed,
                "approved",
              ),
          onDecline:
              () => _handleUpdateStatus(
                context,
                viewModel,
                appointment.id!,
                AppointmentStatus.declined,
                "declined",
              ),
          onComplete:
              () => _handleUpdateStatus(
                context,
                viewModel,
                appointment.id!,
                AppointmentStatus.completed,
                "completed",
              ),
        );
      },
    );
  }

  // --- Generic Handler for Status Updates ---
  Future<void> _handleUpdateStatus(
    BuildContext context,
    DoctorAppointmentsViewModel viewModel,
    String appointmentId,
    AppointmentStatus newStatus,
    String actionVerb, // e.g., "approved", "declined", "completed"
  ) async {
    final success = await viewModel.updateAppointmentStatus(
      appointmentId,
      newStatus,
    );

    if (!context.mounted) return; // Check mounted after await

    if (success) {
      _showSuccessSnackbar(context, "Appointment ${actionVerb} successfully");
    } else {
      _showErrorSnackbar(
        context,
        viewModel.error ?? "Failed to $actionVerb appointment",
      );
    }
  }

  // --- Snackbar Helpers ---
  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
} // End of _DoctorAppointmentsViewState

// --- Separate _AppointmentCard Widget ---
class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback? onApprove; // Made nullable
  final VoidCallback? onDecline; // Made nullable
  final VoidCallback? onComplete; // Made nullable

  const _AppointmentCard({
    required this.appointment,
    this.onApprove,
    this.onDecline,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    // Convert Timestamp to DateTime for formatting
    final DateTime apptDateTime = appointment.dateTime.toDate();

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero, // Use padding in ListView.separated instead
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        // Optional: Border color based on status
        side: BorderSide(
          color: _getStatusColor(appointment.status).withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: _getStatusColor(appointment.status).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  // Status Icon and Text
                  children: [
                    Icon(
                      _getStatusIcon(appointment.status),
                      size: 18,
                      color: _getStatusColor(appointment.status),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      appointment.status.name
                          .capitalize(), // Use enum name, capitalize
                      style: TextStyles.bodyBold.copyWith(
                        color: _getStatusColor(appointment.status),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Details Padding
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  Icons.calendar_today_outlined,
                  DateFormat('EEE, MMM dd, yyyy').format(apptDateTime),
                  isBold: true,
                ),
                const SizedBox(height: 6),
                _buildDetailRow(
                  Icons.access_time_outlined,
                  DateFormat('hh:mm a').format(apptDateTime),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.person_outline,
                  appointment.patientName,
                  label: "Patient",
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.medical_services_outlined,
                  appointment.reason,
                  label: "Reason",
                ),
                if (appointment.notes != null &&
                    appointment.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.notes_outlined,
                    appointment.notes!,
                    label: "Notes",
                  ),
                ],
              ],
            ),
          ),

          // Action Buttons (Conditional)
          _buildActionButtons(),
        ],
      ),
    );
  }

  // Helper for detail rows
  Widget _buildDetailRow(
    IconData icon,
    String text, {
    String? label,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment:
          label != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child:
              label != null
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyles.smallGrey.copyWith(fontSize: 10.sp),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text,
                        style: TextStyles.body.copyWith(
                          fontWeight:
                              isBold ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  )
                  : Text(
                    text,
                    style: TextStyles.body.copyWith(
                      fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
        ),
      ],
    );
  }

  // Build action buttons based on status
  Widget _buildActionButtons() {
    if (appointment.status == AppointmentStatus.pending &&
        onApprove != null &&
        onDecline != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onDecline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                child: const Text("Decline"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: onApprove,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Approve"),
              ),
            ),
          ],
        ),
      );
    } else if (appointment.status == AppointmentStatus.confirmed &&
        onComplete != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ElevatedButton(
          onPressed: onComplete,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text("Mark as Completed"),
        ),
      );
    }
    // Return empty space if no actions apply for other statuses
    return const SizedBox(height: 16); // Keep consistent bottom padding
  }

  // Helper methods now accept Enum
  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return Colors.orange.shade700;
      case AppointmentStatus.confirmed:
        return Colors.blue.shade700;
      case AppointmentStatus.declined:
        return Colors.redAccent;
      case AppointmentStatus.completed:
        return Colors.green.shade700;
      case AppointmentStatus.cancelled:
        return Colors.grey.shade600;
      case AppointmentStatus.scheduled:
        return Colors.purple.shade700;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return Icons.hourglass_empty_rounded;
      case AppointmentStatus.confirmed:
        return Icons.check_circle_outline_rounded;
      case AppointmentStatus.declined:
        return Icons.cancel_outlined;
      case AppointmentStatus.completed:
        return Icons.task_alt_rounded;
      case AppointmentStatus.cancelled:
        return Icons.highlight_off_rounded;
      case AppointmentStatus.scheduled:
        return Icons.event_available_rounded;
      default:
        return Icons.circle_outlined;
    }
  }
} // End _AppointmentCard

// Helper extension for capitalizing strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
