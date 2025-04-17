// lib/presentation/view/dashboard_view.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:mama_care/navigation/router.dart';
import 'package:mama_care/presentation/viewmodel/dashboard_viewmodel.dart';
import 'package:mama_care/presentation/widgets/dashboard_card.dart';
import 'package:mama_care/presentation/widgets/mama_care_app_bar.dart';
import 'package:mama_care/utils/asset_helper.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:mama_care/presentation/viewmodel/auth_viewmodel.dart'; // Import AuthViewModel for logout
import 'package:mama_care/domain/entities/pregnancy_details.dart';
import 'package:mama_care/domain/entities/appointment.dart';
import 'package:mama_care/utils/app_colors.dart';
import 'package:mama_care/utils/text_styles.dart';
import 'package:mama_care/injection.dart'; // For locator
import 'package:mama_care/presentation/widgets/appointment_card.dart'; // Import renamed card

// Main Dashboard View for Patients (likely wrapped by MamaCareScreen)
class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  DateTime _focusedCalendarDate = DateTime.now();
  int _drawerIndex = 0; // Default to Dashboard item index
  final Logger _logger = locator<Logger>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
      _setupFirebaseMessaging();
    });
  }

  // Fetch data using the ViewModel
  Future<void> _loadDashboardData() async {
     _logger.d("DashboardView: Requesting data load from ViewModel.");
     // ViewModel should get the userId internally from Auth state
     await context.read<DashboardViewModel>().loadData();
  }

  // Setup Firebase Cloud Messaging listeners
  void _setupFirebaseMessaging() async {
     _logger.d("DashboardView: Setting up Firebase Messaging...");
     try {
        NotificationSettings settings = await _firebaseMessaging.requestPermission(
          alert: true, badge: true, sound: true, provisional: false,
        );
        _logger.i("DashboardView: Notification permission status: ${settings.authorizationStatus}");
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
        _logger.d("DashboardView: Firebase Messaging listeners attached.");
     } catch (e, stackTrace) {
        _logger.e("DashboardView: Firebase Messaging setup failed", error: e, stackTrace: stackTrace);
     }
  }

  // Handle FCM when app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    _logger.d("DashboardView: Foreground FCM received: ${message.messageId}");
    final notification = message.notification;
    if (notification != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${notification.title ?? 'Notification'}: ${notification.body ?? ''}'),
          backgroundColor: AppColors.primary.withOpacity(0.9), // Use theme color
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
     // Optional: Refresh data based on payload
     if (message.data['refresh'] == 'appointments') {
        context.read<DashboardViewModel>().loadData(); // Example refresh trigger
     }
  }

  // Handle FCM when app is opened from background/terminated
  void _handleMessageOpenedApp(RemoteMessage message) {
     _logger.i("DashboardView: FCM message opened app: ${message.messageId}");
    final route = message.data['route'] as String?;
    if (route != null && mounted) {
      _logger.i("DashboardView: Navigating via FCM data: $route");
      context.read<DashboardViewModel>().navigateToRoute(route, arguments: message.data);
    } else {
      // Fallback or handle other actions if no specific route
       _logger.w("FCM opened app message has no 'route' data or widget not mounted.");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer to react to ViewModel changes for the main scaffold build
    return Consumer<DashboardViewModel>(
      builder: (context, vm, child) {
        // Determine title based on drawer selection or keep static
        final String currentScreenTitle = _getScreenTitleFromDrawerIndex(_drawerIndex);

        return Scaffold(
          // Use Key for drawer if needed for state preservation across rebuilds
          // key: const ValueKey('dashboardDrawer'),
          drawer: _buildNavigationDrawer(context, vm),
          appBar: MamaCareAppBar(
            // Use context.read inside build methods if needed for one-off actions
            // leadingWidget: Builder(builder: (context) => IconButton(icon: Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer())), // Standard drawer opener
            title: currentScreenTitle, // Title changes based on drawer
            trailingWidget: _buildUserAvatar(vm), // Avatar in AppBar
          ),
          floatingActionButton: _buildFab(context, vm), // Conditional FAB
          body: _buildBodyContent(context, vm),
        );
      },
    );
  }

  // Determine screen title based on drawer index
  String _getScreenTitleFromDrawerIndex(int index) {
    switch (index) {
      case 0: return "Dashboard";
      case 1: return "Calendar";
      case 2: return "Timeline";
      case 3: return "Profile";
      default: return "MamaCare";
    }
  }

  // Build Floating Action Button conditionally
  Widget? _buildFab(BuildContext context, DashboardViewModel vm) {
    // Show FAB only on Dashboard or Calendar screen (example)
    if (_drawerIndex == 0 || _drawerIndex == 1) {
       return FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          tooltip: 'Add Appointment',
          onPressed: vm.navigateToAddAppointment, // Use VM method
          child: const Icon(Icons.add),
        );
     }
     return null; // No FAB on other screens
  }


  // Build main body content based on VM state
  Widget _buildBodyContent(BuildContext context, DashboardViewModel vm) {
    if (vm.isLoading && vm.user == null) {
      _logger.d("DashboardView: Displaying initial loading indicator.");
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (vm.error != null && vm.user == null) {
      _logger.w("DashboardView: Displaying error screen - ${vm.error}");
      return _buildErrorWidget(context, vm.error!, vm.loadData); // Pass refresh action
    }

    // Display content with pull-to-refresh
    return RefreshIndicator(
      onRefresh: vm.loadData, // Use VM's loadData for refresh
      color: AppColors.primary,
      child: ListView( // Use ListView to allow RefreshIndicator to work
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0), // Consistent padding
        children: [
          _buildWelcomeHeader(vm),
          const SizedBox(height: 16),
          vm.pregnancyDetails == null
              ? _buildAddDetailsCard(context, vm)
              : _buildPregnancyContent(context, vm),
          const SizedBox(height: 24),
          _buildAppointmentsSection(context, vm),
          const SizedBox(height: 24),
          _buildDashboardGrid(context, vm),
          const SizedBox(height: 80), // Padding below FAB
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildUserAvatar(DashboardViewModel vm) {
    // Use user data from ViewModel
    final photoUrl = vm.user?.profileImageUrl;
    final fallbackImage = Image.asset(AssetsHelper.stretching, fit: BoxFit.cover).image; // Use correct default

    return Padding(
      padding: const EdgeInsets.only(right: 10.0), // Add padding
      child: CircleAvatar(
        radius: 18, // Slightly smaller
        backgroundColor: Colors.grey.shade200,
        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
            ? NetworkImage(photoUrl)
            : fallbackImage, // Use fallback ImageProvider
      ),
    );
  }

  Widget _buildWelcomeHeader(DashboardViewModel vm) {
    final name = vm.user?.name.split(' ').first ?? "User";
    return Text( "Hi $name 👋,", style: TextStyles.headline2.copyWith(fontWeight: FontWeight.w600), );
  }

  Widget _buildAddDetailsCard(BuildContext context, DashboardViewModel vm) {
    return Card(
      color: AppColors.secondary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2,
      child: InkWell(
         onTap: vm.navigateToPregnancyDetails, borderRadius: BorderRadius.circular(12),
         child: Padding(
           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
           child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               Flexible( child: Text( "Track your pregnancy journey!", style: TextStyles.titleWhite, ), ), // Updated text
               const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
             ],
           ),
         ),
      ),
    );
  }

  Widget _buildPregnancyContent(BuildContext context, DashboardViewModel vm) {
    if (vm.pregnancyDetails == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWeekInfo(context, vm.pregnancyDetails!),
        const SizedBox(height: 20),
        _buildCalendar(context, vm),
        const SizedBox(height: 20),
        _buildBabyInfoCard(context, vm.pregnancyDetails!),
      ],
    );
  }

  Widget _buildWeekInfo(BuildContext context, PregnancyDetails details) {
    final weekNumber = context.read<DashboardViewModel>().currentWeek;
    return Text(
      "$weekNumber${_getDaySuffix(weekNumber)} Week of Pregnancy",
      style: TextStyles.headline1.copyWith(color: AppColors.primary),
    );
  }

  Widget _buildCalendar(BuildContext context, DashboardViewModel vm) {
    // Ensure TableCalendar uses the ViewModel data correctly
    return TableCalendar<Appointment>(
      focusedDay: _focusedCalendarDate,
      firstDay: DateTime.utc(DateTime.now().year, DateTime.now().month - 3, 1),
      lastDay: DateTime.utc(DateTime.now().year, DateTime.now().month + 6, 0),
      calendarFormat: CalendarFormat.week,
      headerVisible: false,
      daysOfWeekVisible: true,
      rowHeight: 75, // Adjust height as needed
      currentDay: DateTime.now(),
      selectedDayPredicate: (day) => isSameDay(_focusedCalendarDate, day),
      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(_focusedCalendarDate, selectedDay)) {
          setState(() => _focusedCalendarDate = focusedDay);
           _logger.d("Calendar day selected/focused: $_focusedCalendarDate");
        }
      },
      onPageChanged: (focusedDay) => _focusedCalendarDate = focusedDay,
      eventLoader: (day) => vm.appointments.where((appt) => isSameDay(appt.requestedTime, day)).toList(),
      calendarBuilders: CalendarBuilders<Appointment>(
         defaultBuilder: (_, day, __) => _CalendarDayWidget(day: day),
         todayBuilder: (_, day, __) => _CalendarDayWidget(day: day, isToday: true),
         selectedBuilder:(_, day, __) => _CalendarDayWidget(day: day, isSelected: true),
         outsideBuilder: (_, day, __) => _CalendarDayWidget(day: day, isOutside: true),
         markerBuilder: (_, day, events) => _buildEventMarker(events), // Pass events directly
      ),
       calendarStyle: CalendarStyle(
         todayDecoration: BoxDecoration(color: AppColors.primary.withOpacity(0.3), shape: BoxShape.circle),
         selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
         outsideDaysVisible: false,
       ),
       daysOfWeekStyle: DaysOfWeekStyle(
         weekdayStyle: TextStyles.smallGrey,
         weekendStyle: TextStyles.smallGrey.copyWith(color: AppColors.primary), // Bolder weekends
       ),
    );
  }

  // Refined Event Marker Builder
  Widget? _buildEventMarker(List<Appointment> appointments) { // Accepts Appointment list
      if (appointments.isEmpty) return null;
      return Positioned(
        right: 5, bottom: 5,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration( shape: BoxShape.circle, color: Colors.redAccent[100], ), // Softer red
          constraints: const BoxConstraints(minWidth: 14, minHeight: 14), // Min size
          child: Text(
             '${appointments.length}',
             style: TextStyle(color: Colors.black87, fontSize: 9.sp, fontWeight: FontWeight.bold),
             textAlign: TextAlign.center,
           ),
        ),
      );
    }

  Widget _buildBabyInfoCard(BuildContext context, PregnancyDetails details) {
    final weekNumber = context.read<DashboardViewModel>().currentWeek;
    String babySizeComparison = _getBabySizeComparison(weekNumber);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration( color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [ BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)), ], ),
      child: Column( children: [
          Row( children: [
              Container( padding: const EdgeInsets.all(12), width: 60, height: 60, decoration: BoxDecoration( shape: BoxShape.circle, color: AppColors.secondary.withOpacity(0.1), ), child: SvgPicture.asset(AssetsHelper.maternalImage, colorFilter: const ColorFilter.mode(AppColors.secondary, BlendMode.srcIn)), ),
              const SizedBox(width: 16),
              Expanded( child: Text( "Baby is about the size of a $babySizeComparison", style: TextStyles.bodyBold, ), ),
            ],
          ),
          const Divider(height: 24, thickness: 1),
          Row( mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _BabyInfoColumnWidget( title: "Est. Height", value: details.babyHeight != null ? "${details.babyHeight.toStringAsFixed(1)} cm" : "--", ),
              _BabyInfoColumnWidget( title: "Est. Weight", value: details.babyWeight != null ? "${details.babyWeight.toStringAsFixed(1)} kg" : "--", ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsSection(BuildContext context, DashboardViewModel vm) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Upcoming Appointments', style: TextStyles.title),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
              tooltip: 'Add Appointment',
              onPressed: vm.navigateToAddAppointment,
            ),
          ],
        ),
      ),
      vm.appointments.isEmpty // Access the correct getter `appointments`
          ? _buildNoAppointmentsPlaceholder(context, vm)
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vm.appointments.length, // Access the length of `appointments`
              itemBuilder: (context, index) {
                final appt = vm.appointments[index]; // Access the list item correctly
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppointmentCard(appointment: appt, onTap: () {  },),
                );
              },
            ),
    ],
  );
}

  Widget _buildNoAppointmentsPlaceholder(BuildContext context, DashboardViewModel vm) {
    return InkWell( onTap: vm.navigateToAddAppointment, borderRadius: BorderRadius.circular(12), child: Container( width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24), decoration: BoxDecoration( color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300, width: 1) ), child: Column( children: [ Icon(Icons.edit_calendar_outlined, size: 48, color: Colors.grey.shade400), const SizedBox(height: 16), Text( 'No upcoming appointments', style: TextStyles.bodyGrey ), const SizedBox(height: 8), Text( 'Tap here or use the + button to add one', style: TextStyles.smallGrey, textAlign: TextAlign.center ), ], ), ), );
  }

  Widget _buildDashboardGrid(BuildContext context, DashboardViewModel vm) {
    // Define grid items using the top-level class _DashboardGridItemData
    final List<_DashboardGridItemData> gridItems = [
       _DashboardGridItemData(icon: Icons.monitor_heart_outlined, label: "Prediction", route: NavigationRoutes.predictor),
       _DashboardGridItemData(icon: Icons.local_hospital_outlined, label: "Hospitals", route: NavigationRoutes.map),
       _DashboardGridItemData(icon: Icons.fitness_center_outlined, label: "Exercises", route: NavigationRoutes.exercise),
       _DashboardGridItemData(icon: Icons.article_outlined, label: "Articles", route: NavigationRoutes.articleList),
       _DashboardGridItemData(icon: Icons.play_circle_outline, label: "Videos", route: NavigationRoutes.video_list),
       _DashboardGridItemData(icon: Icons.restaurant_menu_outlined, label: "Food Guide", route: NavigationRoutes.food),
    ];
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(vertical: 10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount( crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.2, ),
      itemCount: gridItems.length,
      itemBuilder: (context, index) { final item = gridItems[index]; return _DashboardGridItemWidget( icon: item.icon, label: item.label, onTap: () => vm.navigateToRoute(item.route), ); },
    );
  }
  Widget _buildNavigationDrawer(BuildContext context, DashboardViewModel vm) {
    // Define drawer items including routes
     final List<_DrawerItemData> drawerItems = [
       _DrawerItemData(index: 0, icon: Icons.dashboard_outlined, label: "Dashboard", route: NavigationRoutes.dashboard),
       _DrawerItemData(index: 1, icon: Icons.calendar_today_outlined, label: "Calendar", route: NavigationRoutes.calendar),
       _DrawerItemData(index: 2, icon: Icons.view_timeline_outlined, label: "Timeline", route: NavigationRoutes.timeline),
       _DrawerItemData(index: 3, icon: Icons.person_outline_rounded, label: "Profile", route: NavigationRoutes.profile),
       _DrawerItemData(index: 4, icon: Icons.logout, label: "Logout", route: null), // Logout action
     ];
     final userName = vm.user?.name ?? "MamaCare User";
     final userEmail = vm.user?.email ?? "";
     final userPhotoUrl = vm.user?.profileImageUrl ?? FirebaseAuth.instance.currentUser?.photoURL;

    return Drawer(
      child: ListView( padding: EdgeInsets.zero, children: [
          UserAccountsDrawerHeader(
            accountName: Text(userName, style: TextStyles.titleWhite),
            accountEmail: Text(userEmail, style: TextStyles.bodyWhite),
            currentAccountPicture: CircleAvatar( backgroundColor: Colors.white, backgroundImage: (userPhotoUrl != null && userPhotoUrl.isNotEmpty) ? NetworkImage(userPhotoUrl) : Image.asset(AssetsHelper.stretching).image, ),
            decoration: const BoxDecoration( color: AppColors.primary ),
           ),
          ...drawerItems.map((item) {
             return ListTile(
                 leading: Icon(item.icon, color: _drawerIndex == item.index ? AppColors.primary : Colors.grey.shade600),
                 title: Text(item.label, style: TextStyle(fontWeight: _drawerIndex == item.index ? FontWeight.bold : FontWeight.normal)),
                 selected: _drawerIndex == item.index,
                 selectedTileColor: AppColors.primary.withOpacity(0.1),
                 onTap: () {
                   Navigator.pop(context); // Close drawer
                   if (_drawerIndex != item.index) {
                      // Note: This only updates the *highlight* state.
                      // Actual navigation between main sections might be handled
                      // by the MamaCareScreen's PageController/BottomNavBar
                      // if DashboardView is just one page within it.
                      // If these are truly separate routes, navigation is correct.
                      setState(() => _drawerIndex = item.index);
                      if (item.route != null) {
                           // Use pushReplacementNamed if these are top-level sections
                           // to avoid building up a stack within the drawer.
                           // Navigator.pushReplacementNamed(context, item.route!);
                           // Or use the VM navigation helper if preferred
                           vm.navigateToRoute(item.route!);
                      } else if (item.label == "Logout") {
                            // Use AuthViewModel for logout
                            context.read<AuthViewModel>().logout().then((_) {
                               // Optional: Navigate explicitly to login after logout confirmation
                               // if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, NavigationRoutes.login, (route) => false);
                            });
                      }
                   }
                 },
               );
             }
          ),
        ],
      ),
    );
  }

  // --- Calculation and Formatting Helpers ---
  String _getDaySuffix(int day) { if (day >= 11 && day <= 13) return 'th'; switch (day % 10) { case 1: return 'st'; case 2: return 'nd'; case 3: return 'rd'; default: return 'th'; } }
  String _getBabySizeComparison(int week) { if (week <= 6) return "Poppy Seed"; if (week <= 8) return "Raspberry"; if (week <= 10) return "Prune"; if (week <= 12) return "Lime"; if (week <= 14) return "Lemon"; if (week <= 16) return "Avocado"; if (week <= 18) return "Sweet Potato"; if (week <= 20) return "Banana"; if (week <= 24) return "Corn Cob"; if (week <= 28) return "Eggplant"; if (week <= 32) return "Squash"; if (week <= 36) return "Honeydew Melon"; return "Watermelon"; }
}

// --- Helper Widgets ---
class _CalendarDayWidget extends StatelessWidget {
  final DateTime day; final bool isToday; final bool isSelected; final bool isOutside;
  const _CalendarDayWidget({ required this.day, this.isToday = false, this.isSelected = false, this.isOutside = false });
  @override Widget build(BuildContext context) { final Color textColor = isSelected || isToday ? Colors.white : (isOutside ? Colors.grey.shade400 : Colors.black87); final Color backgroundColor = isSelected ? AppColors.primary : (isToday ? AppColors.primary.withOpacity(0.3) : Colors.transparent); return Container( margin: const EdgeInsets.all(4.0), alignment: Alignment.center, decoration: BoxDecoration( color: backgroundColor, shape: BoxShape.circle), child: Text('${day.day}', style: TextStyle(color: textColor, fontSize: 11.sp)), ); } // Adjusted font size
}
class _BabyInfoColumnWidget extends StatelessWidget {
  final String title; final String value;
  const _BabyInfoColumnWidget({required this.title, required this.value});
  @override Widget build(BuildContext context) { return Column( crossAxisAlignment: CrossAxisAlignment.center, children: [ Text(title, style: TextStyles.smallGrey), const SizedBox(height: 4), Text(value, style: TextStyles.bodyBold), ], ); }
}
// Assuming AppointmentCardWidget is defined elsewhere and handles its own actions
// Assuming DashboardCard is defined elsewhere
class _DashboardGridItemWidget extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _DashboardGridItemWidget({ required this.icon, required this.label, required this.onTap });
  @override Widget build(BuildContext context) { return InkWell( onTap: onTap, borderRadius: BorderRadius.circular(16), child: DashboardCard(icon: icon, name: label), ); }
}
// Helper Data Class for Drawer
class _DrawerItemData { final int index; final IconData icon; final String label; final String? route; const _DrawerItemData({ required this.index, required this.icon, required this.label, this.route }); }

// Error Widget Helper
Widget _buildErrorWidget(BuildContext context, String errorMsg, VoidCallback onRetry) {
   return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisSize: MainAxisSize.min, children: [ const Icon(Icons.error_outline, color: Colors.redAccent, size: 50), const SizedBox(height: 16), Text("Error Loading Data", style: TextStyles.title.copyWith(color: Colors.redAccent)), const SizedBox(height: 8), Text(errorMsg, style: TextStyles.bodyGrey, textAlign: TextAlign.center), const SizedBox(height: 20), ElevatedButton( onPressed: onRetry, child: const Text("Retry") ) ], ), ), );
}
// Empty List Widget Helper
Widget _buildEmptyListWidget({ required BuildContext context, required String message, required Future<void> Function() onRefresh }) {
   return LayoutBuilder( builder: (context, constraints) => RefreshIndicator( onRefresh: onRefresh, child: SingleChildScrollView( physics: const AlwaysScrollableScrollPhysics(), child: ConstrainedBox( constraints: BoxConstraints(minHeight: constraints.maxHeight), child: Center(child: Padding( padding: const EdgeInsets.all(20.0), child: Text(message, style: TextStyles.bodyGrey, textAlign: TextAlign.center,), ) ), ), ), ), );
}
class _DashboardGridItemData {
  final IconData icon;
  final String label;
  final String route;

  const _DashboardGridItemData({
    required this.icon,
    required this.label,
    required this.route,
  });
}