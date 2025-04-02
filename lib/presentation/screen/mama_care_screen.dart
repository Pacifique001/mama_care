import 'package:flutter/material.dart';
import 'package:mama_care/presentation/screen/calendar_screen.dart';
import 'package:mama_care/presentation/screen/dashboard_screen.dart';
import 'package:mama_care/presentation/screen/profile_screen.dart';
import 'package:mama_care/presentation/screen/timeline_screen.dart';

class MamaCareScreen extends StatefulWidget {
  const MamaCareScreen({Key? key}) : super(key: key);

  @override
  State<MamaCareScreen> createState() => _MamaCareScreenState();
}

class _MamaCareScreenState extends State<MamaCareScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const CalendarScreen(),
    const TimelineScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedIconTheme: const IconThemeData(color: Colors.pinkAccent),
        unselectedIconTheme: const IconThemeData(color: Colors.black),
        items: const [
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.all(20.0),
              child: Icon(Icons.dashboard_outlined),
            ),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.all(20.0),
              child: Icon(Icons.calendar_today_outlined),
            ),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.all(20.0),
              child: Icon(Icons.view_timeline_outlined),
            ),
            label: 'Timeline',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.all(20.0),
              child: Icon(Icons.person_outline_rounded),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}