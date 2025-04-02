import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/presentation/viewmodel/timeline_viewmodel.dart';
import 'package:mama_care/presentation/widgets/mama_care_app_bar.dart';
import 'package:mama_care/utils/asset_helper.dart';
import 'package:sizer/sizer.dart';

class TimelineView extends StatefulWidget {
  const TimelineView({Key? key}) : super(key: key);

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  @override
  void initState() {
    super.initState();
    final timelineViewModel =
        Provider.of<TimelineViewModel>(context, listen: false);
    timelineViewModel.getPregnancyDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TimelineViewModel>(
      builder: (context, timelineViewModel, _) => Scaffold(
        appBar: MamaCareAppBar(
          title: "Timeline",
          trailingWidget: const Icon(Icons.more_vert, color: Colors.pinkAccent),
        ),
        body: ListView.builder(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          itemCount: timelineViewModel.weeks.length,
          itemBuilder: (context, index) {
            final isCurrentWeek = index ==
                ((DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(
                            timelineViewModel.pregnancyDetails?.startingDay ?? 0))
                        .inDays) ~/
                    7);

            return Padding(
              padding: EdgeInsets.symmetric(vertical: 1.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 5.w,
                    child: SvgPicture.asset(
                      AssetsHelper.timelineIndicator,
                      color: isCurrentWeek ? Colors.pinkAccent : Color(0xFFFFCDD2),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timelineViewModel.weeks[index][0],
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.pinkAccent,
                            ),
                      ),
                      SizedBox(height: 0.5.h),
                      Container(
                        width: 83.w,
                        child: Text(
                          timelineViewModel.weeks[index][1],
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
