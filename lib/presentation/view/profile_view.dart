// lib/presentation/view/profile_view.dart

import 'dart:io'; // For File type
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart'; // Import image_picker
import 'package:mama_care/domain/entities/user_role.dart';
import 'package:mama_care/navigation/router.dart';
import 'package:mama_care/presentation/widgets/appointment_card.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:cached_network_image/cached_network_image.dart'; // For profile image
import 'package:mama_care/presentation/viewmodel/profile_viewmodel.dart';
import 'package:mama_care/presentation/viewmodel/auth_viewmodel.dart'; // Import AuthViewModel
import 'package:mama_care/utils/asset_helper.dart';
import 'package:mama_care/presentation/widgets/mama_care_app_bar.dart';
import 'package:mama_care/domain/entities/pregnancy_details.dart'; // Keep for type hinting
import 'package:mama_care/domain/entities/user_model.dart'; // Import UserModel
import 'package:mama_care/utils/app_colors.dart';
import 'package:mama_care/utils/text_styles.dart';
//import 'package:mama_care/presentation/widgets/custom_button.dart'; // For Save/Cancel
import 'package:mama_care/presentation/widgets/custom_text_field.dart'; // For editable fields
import 'package:logger/logger.dart'; // Import logger
import 'package:mama_care/injection.dart';
import 'package:table_calendar/table_calendar.dart'; // Import locator

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  // Removed ScrollController, use ListView directly for simplicity now
  final Logger _logger = locator<Logger>(); // Get logger

  @override
  void initState() {
    super.initState();
    // Initial data load is triggered by the ViewModel constructor/listener now
  }

  // --- Image Picking Logic ---
  Future<void> _pickImage(ProfileViewModel viewModel) async {
    final picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery, // Or ImageSource.camera
        imageQuality: 70, // Compress image slightly
        maxWidth: 800, // Resize image
      );
      if (pickedFile != null) {
        viewModel.setImageFilePath(pickedFile.path); // Update VM state
      } else {
        _logger.i("Image picking cancelled by user.");
      }
    } catch (e, s) {
      _logger.e("Error picking image", error: e, stackTrace: s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not pick image."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer2 to listen to both ViewModels
    return Consumer2<ProfileViewModel, AuthViewModel>(
      builder: (context, profileViewModel, authViewModel, child) {
        // Get the user data from AuthViewModel
        final user = authViewModel.localUser;

        return Scaffold(
          appBar: _buildAppBar(
            context,
            profileViewModel,
            authViewModel,
          ), // Pass VMs
          body: _buildContent(
            context,
            profileViewModel,
            authViewModel,
            user,
          ), // Pass VMs and user
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ProfileViewModel profileVm,
    AuthViewModel authVm,
  ) {
    return MamaCareAppBar(
      title: "My Profile",
      automaticallyImplyLeading: true, // Show back button
      actions: [
        // Show Edit/Cancel button based on edit mode
        if (profileVm.isEditing)
          TextButton(
            onPressed: profileVm.isLoading ? null : profileVm.cancelEditing,
            child: Text(
              "Cancel",
              style: TextStyle(
                color: authVm.isLoading ? Colors.grey : AppColors.primary,
              ),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: "Edit Profile",
            onPressed:
                authVm.localUser == null
                    ? null
                    : profileVm.startEditing, // Only allow edit if user loaded
          ),
        // Add Save button only in edit mode
        if (profileVm.isEditing)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed:
                  authVm.isLoading
                      ? null
                      : () async {
                        // Use AuthVM loading here
                        final success =
                            await profileVm.saveUserProfileChanges();
                        if (mounted && !success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                profileVm.errorMessage ??
                                    "Failed to save changes",
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        } else if (mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Profile updated!"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
              child: Text(
                "Save",
                style: TextStyle(
                  color: authVm.isLoading ? Colors.grey : AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    ProfileViewModel profileVm,
    AuthViewModel authVm,
    UserModel? user,
  ) {
    // Handle global loading/error states first (e.g., initial user load)
    if (authVm.isLoading && user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (authVm.errorMessage != null && user == null) {
      return _buildErrorWidget(
        "Error loading profile: ${authVm.errorMessage}",
        authVm.clearError,
      ); // Allow clearing global error
    }
    if (user == null) {
      // This should ideally not happen if AuthWrapper is working, but handle defensively
      return _buildErrorWidget(
        "User data not available. Please log in again.",
        () {
          authVm.logout();
          Navigator.pushNamedAndRemoveUntil(
            context,
            NavigationRoutes.login,
            (route) => false,
          );
        },
      );
    }

    // --- Build Profile Content ---
    return RefreshIndicator(
      onRefresh: profileVm.refreshData, // Refresh only pregnancy details now
      color: AppColors.primary,
      child: ListView(
        // Use ListView for scrollability
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // --- User Profile Section ---
          _buildUserProfileHeader(context, profileVm, authVm, user),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // --- Pregnancy Details Section (Conditionally Shown) ---
          _buildPregnancySection(context, profileVm), // Pass profileVm
          // Add other sections as needed (e.g., Saved Articles/Videos link)
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(
              Icons.bookmark_border,
              color: AppColors.primary,
            ),
            title: Text("My Saved Content", style: TextStyles.bodyBold),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to a screen showing saved articles/videos
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Saved Content screen not implemented."),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(
              Icons.settings_outlined,
              color: AppColors.textGrey,
            ),
            title: Text("Settings", style: TextStyles.body),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, NavigationRoutes.editScreen);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Settings screen not implemented."),
                ),
              );
            },
          ),
          const Divider(),
          // Logout button could be here or in AppBar/Drawer
        ],
      ),
    );
  }

  // --- User Profile Header Widget ---
  Widget _buildUserProfileHeader(
    BuildContext context,
    ProfileViewModel profileVm,
    AuthViewModel authVm,
    UserModel user,
  ) {
    final bool isEditing = profileVm.isEditing;
    final imagePath = profileVm.selectedImageFilePath;
    final imageUrl = user.profileImageUrl;
    File? imageFile = imagePath != null ? File(imagePath) : null;

    return Column(
      children: [
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 55.sp,
                backgroundColor: AppColors.primaryLight.withOpacity(0.2),
                backgroundImage:
                    imageFile != null
                        ? FileImage(imageFile) as ImageProvider
                        : (imageUrl != null && imageUrl.isNotEmpty
                            ? CachedNetworkImageProvider(imageUrl)
                            : null),
                child:
                    (imageFile == null &&
                            (imageUrl == null || imageUrl.isEmpty))
                        ? Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 40.sp,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                        : null,
              ),
              if (isEditing)
                Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    onTap: () => _pickImage(profileVm),
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(6.0),
                      child: Icon(Icons.edit, color: Colors.white, size: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!isEditing) ...[
          // --- Display Mode ---
          Text(
            user.name,
            style: TextStyles.headline2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: TextStyles.bodyGrey,
            textAlign: TextAlign.center,
          ),
          if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              user.phoneNumber!,
              style: TextStyles.bodyGrey,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            user.role.name.capitalize(),
            style: TextStyles.smallPrimary.copyWith(
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          // --- Editing Mode ---
          // Ensure controllers are non-null here because isEditing is true
          // If they *could* still be null (unlikely with current logic), add checks:
          // if (profileVm.nameController != null)
          CustomTextField(
            // controller requires non-null, VM guarantees it in edit mode now
            controller:
                profileVm
                    .nameController!, // Use non-null assertion (!) or ensure non-null before build
            hint: "Full Name", // Use hint instead of labelText
            prefixIcon: const Icon(Icons.person_outline),
            validator:
                (v) => v == null || v.isEmpty ? "Name cannot be empty" : null,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          // if (profileVm.phoneController != null)
          CustomTextField(
            controller:
                profileVm.phoneController!, // Use non-null assertion (!)
            hint: "Phone Number", // Use hint instead of labelText
            prefixIcon: const Icon(Icons.phone_outlined),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  // --- Pregnancy Details Section Widget ---
  // --- Pregnancy Details Section Widget ---
  Widget _buildPregnancySection(
    BuildContext context,
    ProfileViewModel profileVm,
  ) {
    // Get access to AuthViewModel to check user role
    final authVm = Provider.of<AuthViewModel>(context, listen: false);
    final user = authVm.localUser;

    // Don't show pregnancy section if user is a doctor
    if (user?.role != UserRole.patient) {
      return const SizedBox.shrink(); // Return empty widget for doctors
    }

    // Use Selector for specific parts of ProfileViewModel state
    return Selector<ProfileViewModel, ViewState>(
      selector: (_, vm) => vm.viewState,
      builder: (context, state, _) {
        // Show loading specifically for pregnancy details
        if (state == ViewState.loading && profileVm.pregnancyDetails == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Loading pregnancy details..."),
            ),
          );
        }

        // Get details after loading/error checks
        final details = profileVm.pregnancyDetails;

        if (details == null) {
          // Offer to add details if none exist (and not editing profile)
          if (!profileVm.isEditing) {
            return Card(
              elevation: 1,
              child: ListTile(
                leading: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.primary,
                ),
                title: const Text("Track Your Pregnancy"),
                subtitle: const Text("Add your details to get started."),
                onTap:
                    () => Navigator.pushNamed(
                      context,
                      NavigationRoutes.pregnancy_detail,
                    ),
              ),
            );
          } else {
            // Don't show add button while editing profile
            return const SizedBox.shrink();
          }
        }

        // --- Display Pregnancy Details (similar to your previous ProfileView) ---
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Pregnancy Progress", style: TextStyles.title),
            const SizedBox(height: 10),
            // Use your existing widgets or build them here
            _PregnancyCalendarWidget(details: details), // Pass details
            const SizedBox(height: 16),
            _BabyInfoCardWidget(details: details), // Pass details
            const SizedBox(height: 16),
            // Button to edit pregnancy details (navigates)
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text("Update Pregnancy Details"),
                onPressed:
                    () => Navigator.pushNamed(
                      context,
                      NavigationRoutes.pregnancy_detail,
                    ), // Navigate to edit/add screen
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Helper Widgets ---
  // Error widget (simplified for this context)
  Widget _buildErrorWidget(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyles.bodyGrey,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
} // End of _ProfileViewState

// --- Re-usable Widgets (Extracted from original ProfileView) ---
// You can keep these separate or integrate them further

class _PregnancyCalendarWidget extends StatelessWidget {
  final PregnancyDetails details;
  const _PregnancyCalendarWidget({required this.details});

  @override
  Widget build(BuildContext context) {
    // Use details.startingDay directly as it's DateTime now
    final startDate = details.startingDay;
    final today = DateTime.now();
    final focusedDay =
        (today.isAfter(startDate) && today.isBefore(details.dueDate))
            ? today
            : startDate;

    return Card(
      // Wrap in card for better visual separation
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0), // Add padding
        child: TableCalendar(
          headerVisible: false,
          daysOfWeekVisible: true, // Show days of week
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyles.smallGrey,
            weekendStyle: TextStyles.smallGrey.copyWith(
              color: AppColors.primary,
            ),
          ),
          focusedDay: focusedDay,
          firstDay: startDate,
          lastDay: details.dueDate, // Use calculated due date
          calendarFormat: CalendarFormat.week, // Show only one week
          startingDayOfWeek:
              StartingDayOfWeek.monday, // Optional: Set start day
          calendarBuilders: CalendarBuilders(
            // Highlight today within the pregnancy range
            todayBuilder:
                (context, day, _) => _CalendarDayWidget(
                  day: day,
                  startDate: startDate,
                  isToday: true,
                ),
            // Default style for other days
            defaultBuilder:
                (context, day, _) => _CalendarDayWidget(
                  day: day,
                  startDate: startDate,
                  isToday: false,
                ),
            // Style for days outside the current month (not relevant for week view)
            outsideBuilder:
                (context, day, _) => Opacity(
                  opacity: 0.5,
                  child: _CalendarDayWidget(
                    day: day,
                    startDate: startDate,
                    isToday: false,
                  ),
                ),
            // Optional: Style for selected day if you add selection logic
            // selectedBuilder: ...
            // Optional: Add markers for appointments/events if needed
            // markerBuilder: ...
          ),
          calendarStyle: const CalendarStyle(
            // Remove default decorations if using builders
            todayDecoration: BoxDecoration(shape: BoxShape.circle),
            selectedDecoration: BoxDecoration(shape: BoxShape.circle),
            outsideDaysVisible: false,
          ),
        ),
      ),
    );
  }
}

class _CalendarDayWidget extends StatelessWidget {
  final DateTime day;
  final DateTime startDate; // Not needed if just displaying day number
  final bool isToday;

  const _CalendarDayWidget({
    required this.day,
    required this.startDate, // Keep or remove based on final design
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    // final daysDifference = day.difference(startDate).inDays; // Calculation removed if not displaying diff
    final Color textColor = isToday ? Colors.white : Colors.black87;
    final Color backgroundColor =
        isToday ? AppColors.primary : Colors.transparent;

    return Container(
      margin: const EdgeInsets.all(3.0), // Reduced margin
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border:
            isToday
                ? null
                : Border.all(
                  color: AppColors.greyLight,
                  width: 0.5,
                ), // Subtle border for non-today
      ),
      child: Text(
        '${day.day}', // Just display the day number
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _BabyInfoCardWidget extends StatelessWidget {
  final PregnancyDetails details;
  const _BabyInfoCardWidget({required this.details});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.07),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withOpacity(0.1),
            ),
            child: SvgPicture.asset(
              AssetsHelper.maternalImage,
              height: 40,
              width: 40,
            ), // Ensure SVG path is correct
          ),
          const SizedBox(width: 16),
          // Metrics Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Use your existing _MetricRow or similar
                _MetricRowWidget(
                  label: "Baby Weight Est.",
                  value: details.babyWeight.toStringAsFixed(1),
                  unit: "kg",
                ),
                const SizedBox(height: 10),
                _MetricRowWidget(
                  label: "Baby Height Est.",
                  value: details.babyHeight.toStringAsFixed(1),
                  unit: "cm",
                ),
                const SizedBox(height: 10),
                // Use your existing _TimeRemainingMetrics or similar
                _TimeRemainingMetricsWidget(details: details),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Re-usable Metric Row Widget ---
class _MetricRowWidget extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _MetricRowWidget({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyles.smallGrey.copyWith(fontSize: 10.sp)),
        Text(
          "$value $unit",
          style: TextStyles.bodyBold.copyWith(fontSize: 13.sp),
        ),
      ],
    );
  }
}

// --- Re-usable Time Remaining Widget ---
class _TimeRemainingMetricsWidget extends StatelessWidget {
  final PregnancyDetails details;
  const _TimeRemainingMetricsWidget({required this.details});

  @override
  Widget build(BuildContext context) {
    // Calculate days remaining based on the dueDate from details
    final daysRemaining =
        details.daysRemaining ?? 0; // Use getter, default to 0 if null
    final weeksRemaining = (daysRemaining / 7).floor();

    return Row(
      // Ensure this row doesn't overflow, adjust spacing or use Expanded if needed
      // mainAxisAlignment: MainAxisAlignment.spaceBetween, // Use spaceBetween if layout allows
      children: [
        _TimeMetricWidget(label: "Days Left", value: daysRemaining.toString()),
        SizedBox(width: 4.w), // Add spacing
        _TimeMetricWidget(
          label: "Weeks Left",
          value: weeksRemaining.toString(),
        ),
      ],
    );
  }
}

class _TimeMetricWidget extends StatelessWidget {
  final String label;
  final String value;

  const _TimeMetricWidget({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyles.smallGrey.copyWith(fontSize: 10.sp)),
        Text(value, style: TextStyles.bodyBold.copyWith(fontSize: 13.sp)),
      ],
    );
  }
}

// Removed _SavedContentSection and its dependencies as they were placeholders
// using static data and likely belong in a separate feature/screen.
