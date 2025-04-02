import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:mama_care/presentation/viewmodel/video_list_viewmodel.dart';
import 'package:mama_care/utils/asset_helper.dart';
import 'package:mama_care/navigation/router.dart';
import 'package:mama_care/presentation/widgets/mama_care_app_bar.dart';

class VideoListView extends StatefulWidget {
  const VideoListView({Key? key}) : super(key: key);

  @override
  State<VideoListView> createState() => _VideoListViewState();
}

class _VideoListViewState extends State<VideoListView> {
  @override
  void initState() {
    super.initState();
    // Fetch video data when the view is initialized
    Provider.of<VideoListViewModel>(context, listen: false).loadVideos();
  }

  @override
  Widget build(BuildContext context) {
    final videoViewModel = Provider.of<VideoListViewModel>(context);

    return Scaffold(
      appBar: MamaCareAppBar(
        title: "Videos",
        trailingWidget: const Icon(Icons.more_vert, color: Colors.pinkAccent),
      ),
      body: videoViewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: videoViewModel.videos.length,
              itemBuilder: (context, index) {
                final video = videoViewModel.videos[index];
                return VideoListCard(
                  title: video.title,
                  detail: video.description,
                  image: video.thumbnailUrl,
                  index: index,
                );
              },
            ),
    );
  }
}

class VideoListCard extends StatelessWidget {
  final String title;
  final String detail;
  final String image;
  final int index;

  const VideoListCard({
    Key? key,
    required this.title,
    required this.detail,
    required this.image,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, NavigationRoutes.article);
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10.0),
                      child: Image.asset(
                        image,
                        height: 30.h,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const Card(
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: 50,
                        color: Colors.pinkAccent,
                      ),
                      shape: CircleBorder(),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.pinkAccent,
                    ),
              ),
              SizedBox(height: 1.h),
              Text(
                '${detail.substring(0, 50)}...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SizedBox(height: 1.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Save for Later",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.pinkAccent,
                        ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final videoViewModel = Provider.of<VideoListViewModel>(context, listen: false);
                      await videoViewModel.toggleFavorite(videoViewModel.videos[index].id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Video saved to favorites!"),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.bookmark_border_rounded,
                      color: Colors.pinkAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
