import 'package:flutter/material.dart';
//import 'package:flutter/semantics.dart';
import 'package:mama_care/presentation/screen/calendar_screen.dart';
import 'package:mama_care/presentation/screen/dashboard_screen.dart';
import 'package:mama_care/presentation/screen/profile_screen.dart';
import 'package:mama_care/presentation/screen/timeline_screen.dart';
import 'package:mama_care/utils/app_colors.dart';

class MamaCareScreen extends StatefulWidget {
  const MamaCareScreen({super.key});

  @override
  State<MamaCareScreen> createState() => _MamaCareScreenState();
}

class _MamaCareScreenState extends State<MamaCareScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late List<AnimationController> _animationControllers;
  final List<Widget> _screens = [
    const DashboardScreen(),
    const CalendarScreen(),
    const TimelineScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationControllers = List.generate(
      4,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      ),
    );
    _animationControllers[_currentIndex].forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
    
    // Haptic feedback
    Feedback.forTap(context);
    
    // Animation handling
    for (var controller in _animationControllers) {
      controller.reverse();
    }
    _animationControllers[index].forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: _screens,
      ),
      bottomNavigationBar: _buildFancyNavBar(),
    );
  }

  Widget _buildFancyNavBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.primary,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white.withOpacity(0.5),
          elevation: 0,
          items: [
            _buildNavItem(Icons.dashboard_outlined, 'Dashboard', 0),
            _buildNavItem(Icons.calendar_today_outlined, 'Calendar', 1),
            _buildNavItem(Icons.view_timeline_outlined, 'Timeline', 2),
            _buildNavItem(Icons.person_outline_rounded, 'Profile', 3),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return BottomNavigationBarItem(
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _animationControllers[index],
            child: Icon(icon, size: isSelected ? 28 : 24),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 20 : 0,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
      label: label,
      tooltip: label,
    );
  }
}