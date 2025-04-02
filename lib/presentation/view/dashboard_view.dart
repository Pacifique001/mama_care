import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:mama_care/navigation/router.dart';
import 'package:mama_care/presentation/viewmodel/dashboard_viewmodel.dart';
import 'package:mama_care/presentation/widgets/dashboard_card.dart';
import 'package:mama_care/presentation/widgets/mama_care_app_bar.dart';
import 'package:mama_care/utils/asset_helper.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:get_it/get_it.dart';
import 'package:mama_care/domain/entities/pregnancy_details.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({Key? key}) : super(key: key);

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  DateTime date = DateTime.now();
  int selectedIndex = 0;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final DatabaseHelper _dbHelper = GetIt.I<DatabaseHelper>();

  @override
  void initState() {
    super.initState();
    _initializeFirebaseMessaging();
    _initializeData();
  }

  void _initializeFirebaseMessaging() {
    _firebaseMessaging.requestPermission();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotification(message.notification?.title, message.notification?.body);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationNavigation(message.data);
    });
  }

  void _showNotification(String? title, String? body) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title: $body'),
        backgroundColor: Colors.pinkAccent,
      ),
    );
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    if (data['route'] != null) {
      Navigator.pushNamed(context, data['route']);
    }
  }

  void _initializeData() {
    final dashboardViewModel =
        Provider.of<DashboardViewModel>(context, listen: false);
    _loadLocalData(dashboardViewModel);
    dashboardViewModel.getUserDetail();
    dashboardViewModel.getPregnancyDetails();
  }

  Future<void> _loadLocalData(DashboardViewModel viewModel) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final details = await _dbHelper.getPregnancyDetails(user.uid);
      if (details.isNotEmpty) {
        final pregnancyDetails = PregnancyDetails.fromJson(details.first);
        viewModel.updatePregnancyDetailsFromLocal(pregnancyDetails);
      }
    }
  }

  Future<void> _savePregnancyDetails(Map<String, dynamic> details) async {
    await _dbHelper.insertPregnancyDetail(details);
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      drawer: _buildNavigationDrawer(),
      appBar: MamaCareAppBar(
        trailingWidget: CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage(
              user?.photoURL ?? "https://picsum.photos/200"),
        ),
        title: "Home",
      ),
      body: Consumer<DashboardViewModel>(
        builder: (context, dashboardViewModel, child) {
          if (dashboardViewModel.pregnancyDetails != null) {
            _savePregnancyDetails({
              'babyHeight': dashboardViewModel.pregnancyDetails!.babyHeight,
              'babyWeight': dashboardViewModel.pregnancyDetails!.babyWeight,
              'startingDay': dashboardViewModel.pregnancyDetails!.startingDay,
            });
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeMessage(dashboardViewModel),
                  const SizedBox(height: 10),
                  dashboardViewModel.pregnancyDetails == null
                      ? _buildAddPregnancyDetailsCard()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPregnancyWeekInfo(dashboardViewModel),
                            const SizedBox(height: 20),
                            _buildCalendar(),
                            const SizedBox(height: 20),
                            _buildBabyInfoCard(dashboardViewModel),
                          ],
                        ),
                  const SizedBox(height: 20),
                  _buildDashboardGrid(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavigationDrawer() {
    return NavigationDrawer(
      backgroundColor: Colors.grey.shade50,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => setState(() => selectedIndex = index),
      children: [
        const DrawerHeader(
          child: CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage("https://picsum.photos/200"),
          ),
        ),
        _buildDrawerItem(Icons.dashboard_outlined, "Dashboard", isSelected: selectedIndex == 0),
        _buildDrawerItem(Icons.calendar_today_outlined, "Calendar", isSelected: selectedIndex == 1),
        _buildDrawerItem(Icons.view_timeline_outlined, "Timeline", isSelected: selectedIndex == 2),
        _buildDrawerItem(Icons.person_outline_rounded, "Profile", isSelected: selectedIndex == 3),
      ],
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, {bool isSelected = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Colors.white : Colors.pinkAccent),
        title: Text(title, 
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
        tileColor: isSelected ? Colors.pinkAccent : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildWelcomeMessage(DashboardViewModel dashboardViewModel) {
    return Text(
      "Hi ${dashboardViewModel.user?.name ?? "User"}",
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey,
            fontSize: 14.sp,
          ),
    );
  }

  Widget _buildAddPregnancyDetailsCard() {
    return Card(
      color: Colors.pinkAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Add Pregnancy Details!!",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
            IconButton(
              onPressed: () {
                Navigator.pushNamed(context, NavigationRoutes.pregnancy_detail);
              },
              icon: const Icon(
                Icons.arrow_circle_right,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPregnancyWeekInfo(DashboardViewModel dashboardViewModel) {
    final weekNumber = ((DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(
                dashboardViewModel.pregnancyDetails?.startingDay ?? 1))
            .inDays) ~/
        7) +
        1;
    final suffix = _getDayOfMonthSuffix(weekNumber);

    return Text(
      "$weekNumber$suffix Week of Pregnancy",
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.pinkAccent,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      focusedDay: date,
      firstDay: date.subtract(Duration(days: date.weekday - 1)),
      lastDay: date.add(Duration(days: DateTime.daysPerWeek - date.weekday)),
      calendarFormat: CalendarFormat.week,
      headerVisible: false,
      daysOfWeekVisible: false,
      rowHeight: 80,
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Container(
            padding: const EdgeInsets.all(10),
            height: 40.h,
            width: 20.w,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('EEE').format(day),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  day.day.toString(),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        todayBuilder: (context, day, focusedDay) => Padding(
          padding: const EdgeInsets.all(3.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            height: 40.h,
            width: 20.w,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('EEE').format(day),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                      ),
                ),
                Text(
                  day.day.toString(),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ],
            ),
            decoration: BoxDecoration(
              color: Colors.pinkAccent,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBabyInfoCard(DashboardViewModel dashboardViewModel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                width: 70,
                height: 70,
                child: SvgPicture.asset(AssetsHelper.maternalImage),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.shade100,
                ),
              ),
              const SizedBox(width: 20),
              Text(
                "Baby is size of pear",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBabyInfoColumn(
                  "Baby Height", "${dashboardViewModel.pregnancyDetails?.babyHeight ?? "N/A"}"),
              _buildBabyInfoColumn(
                  "Baby Weight", "${dashboardViewModel.pregnancyDetails?.babyWeight ?? "N/A"}"),
              _buildBabyInfoColumn("Baby Length", "17 cm"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBabyInfoColumn(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildDashboardGrid() {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      children: [
        _buildGridItem(
          icon: Icons.medical_information,
          label: "Prediction",
          route: NavigationRoutes.predictor,
        ),
        _buildGridItem(
          icon: Icons.local_hospital,
          label: "Hospitals",
          route: NavigationRoutes.map,
        ),
        _buildGridItem(
          icon: Icons.fitness_center,
          label: "Exercises",
          route: NavigationRoutes.exercise,
        ),
        _buildGridItem(
          icon: Icons.article,
          label: "Articles",
          route: NavigationRoutes.articleList,
        ),
        _buildGridItem(
          icon: Icons.video_collection,
          label: "Videos",
          route: NavigationRoutes.video_list,
        ),
        _buildGridItem(
          icon: Icons.food_bank,
          label: "Food",
          route: NavigationRoutes.food,
        ),
      ],
    );
  }

  Widget _buildGridItem({
    required IconData icon,
    required String label,
    required String route,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: DashboardCard(
        icon: icon,
        name: label,
      ),
    );
  }

  String _getDayOfMonthSuffix(int dayNum) {
    if (!(dayNum >= 1 && dayNum <= 31)) {
      return 'th';
    }

    if (dayNum >= 11 && dayNum <= 13) {
      return 'th';
    }

    switch (dayNum % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}