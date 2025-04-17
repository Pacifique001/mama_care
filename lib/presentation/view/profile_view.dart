import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:mama_care/navigation/router.dart';
import 'package:mama_care/presentation/viewmodel/profile_viewmodel.dart';
import 'package:mama_care/utils/asset_helper.dart';
import 'package:mama_care/presentation/widgets/mama_care_app_bar.dart';
import 'package:mama_care/domain/entities/pregnancy_details.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Trigger initial data load
    Future.microtask(() => context.read<ProfileViewModel>().getPregnancyDetails());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    await context.read<ProfileViewModel>().refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _buildContent(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
  return MamaCareAppBar(
    title: Provider.of<ProfileViewModel>(context).pregnancyDetails?.weeksPregnant != null
        ? "Week: ${Provider.of<ProfileViewModel>(context).pregnancyDetails!.weeksPregnant}"
        : "Week: 0",
  );
}

  Widget _buildContent() {
    return Selector<ProfileViewModel, ViewState>(
      selector: (_, vm) => vm.viewState,
      builder: (context, state, _) {
        switch (state) {
          case ViewState.loading:
            return _buildLoading();
          case ViewState.error:
            return _buildError();
          case ViewState.success:
            return _buildSuccessContent();
          case ViewState.initial:
          default:
            return _buildInitial();
        }
      },
    );
  }

  Widget _buildLoading() => const Center(child: CircularProgressIndicator());

  Widget _buildInitial() => const Center(child: Text('Start tracking your pregnancy journey!'));

  Widget _buildError() {
    return Center(
      child: Selector<ProfileViewModel, String?>(
        selector: (_, vm) => vm.errorMessage,
        builder: (_, error, __) => Text(
          error ?? 'Unknown error occurred',
          style: TextStyle(color: Colors.red, fontSize: 14.sp),
        ),
      ),
    );
  }

  Widget _buildSuccessContent() {
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PregnancyCalendar(),
              SizedBox(height: 3.h),
              _BabyInfoCard(),
              SizedBox(height: 3.h),
              _SavedContentSection(type: ContentType.videos),
              SizedBox(height: 3.h),
              _SavedContentSection(type: ContentType.articles),
            ],
          ),
        ),
      ),
    );
  }
}
class _PregnancyCalendar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Selector<ProfileViewModel, PregnancyDetails?>(
      selector: (_, vm) => vm.pregnancyDetails,
      builder: (context, details, _) {
        final startDate = details?.startDate ?? DateTime.now();
        return TableCalendar(
          headerVisible: false,
          daysOfWeekVisible: false,
          focusedDay: DateTime.now(),
          firstDay: startDate,
          lastDay: startDate.add(const Duration(days: 280)),
          calendarFormat: CalendarFormat.week,
          calendarBuilders: CalendarBuilders(
            todayBuilder: (context, day, _) => _CalendarDay(
              day: day,
              startDate: startDate,
              isToday: true,
            ),
            defaultBuilder: (context, day, _) => _CalendarDay(
              day: day,
              startDate: startDate,
              isToday: false,
            ),
          ),
        );
      },
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final DateTime day;
  final DateTime startDate;
  final bool isToday;

  const _CalendarDay({
    required this.day,
    required this.startDate,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final daysDifference = day.difference(startDate).inDays;
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isToday ? Colors.pinkAccent : Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$daysDifference',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isToday ? Colors.white : Colors.black87,
                ),
          ),
        ),
      ),
    );
  }
}

class _BabyInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Selector<ProfileViewModel, PregnancyDetails?>(
      selector: (_, vm) => vm.pregnancyDetails,
      builder: (context, details, _) {
        return Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 10,
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BabyAvatar(),
              const SizedBox(width: 20),
              Expanded(child: _BabyMetrics(details: details)),
            ],
          ),
        );
      },
    );
  }
}

class _BabyAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red.shade100,
      ),
      child: SvgPicture.asset(AssetsHelper.maternalImage),
    );
  }
}

class _BabyMetrics extends StatelessWidget {
  final PregnancyDetails? details;

  const _BabyMetrics({this.details});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetricRow(
          label: "Baby Weight",
          value: details?.babyWeight.toStringAsFixed(2) ?? "N/A",
          unit: "kg",
        ),
        SizedBox(height: 2.h),
        _MetricRow(
          label: "Baby Height",
          value: details?.babyHeight.toStringAsFixed(1) ?? "N/A",
          unit: "cm",
        ),
        SizedBox(height: 2.h),
        _TimeRemainingMetrics(details: details),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text("$value $unit", style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ],
    );
  }
}

class _TimeRemainingMetrics extends StatelessWidget {
  final PregnancyDetails? details;

  const _TimeRemainingMetrics({this.details});

  @override
  Widget build(BuildContext context) {
    final daysSinceStart = details != null 
        ? DateTime.now().difference(details!.startDate).inDays
        : 0;
    final daysRemaining = 280 - daysSinceStart;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _TimeMetric(
          label: "Days Left",
          value: daysRemaining.toString(),
        ),
        _TimeMetric(
          label: "Weeks Left",
          value: (daysRemaining ~/ 7).toString(),
        ),
      ],
    );
  }
}

class _TimeMetric extends StatelessWidget {
  final String label;
  final String value;

  const _TimeMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _SavedContentSection extends StatelessWidget {
  final ContentType type;

  const _SavedContentSection({required this.type});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          type == ContentType.videos ? "Saved Videos" : "Saved Articles",
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        SizedBox(
          height: 30.h,
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: 2,
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: type == ContentType.videos
                    ? _SavedVideoCard(index: index)
                    : _SavedArticleCard(index: index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SavedVideoCard extends StatelessWidget {
  final int index;

  const _SavedVideoCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final data = AssetsHelper.articleData[index + 3];
    return SavedContentCard(
      image: data['image'],
      isVideo: true,
      onTap: () => Navigator.pushNamed(context, NavigationRoutes.video_list),
    );
  }
}

class _SavedArticleCard extends StatelessWidget {
  final int index;

  const _SavedArticleCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final data = AssetsHelper.articleData[index];
    return SavedContentCard(
      image: data['image'],
      onTap: () => Navigator.pushNamed(context, NavigationRoutes.articleList),
    );
  }
}

class SavedContentCard extends StatelessWidget {
  final String image;
  final bool isVideo;
  final VoidCallback onTap;

  const SavedContentCard({
    super.key,
    required this.image,
    this.isVideo = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 10,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(image, fit: BoxFit.cover, height: 30.h),
              if (isVideo)
                const Icon(Icons.play_circle_filled,
                    size: 40, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

enum ContentType { videos, articles }
