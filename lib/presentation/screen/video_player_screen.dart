// lib/presentation/screen/video_player_screen.dart (NEW FILE - Example using youtube_player_flutter)
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:mama_care/presentation/widgets/mama_care_app_bar.dart'; // Optional AppBar

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl; // Expect the full URL or just the ID

  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late YoutubePlayerController _controller;
  bool _showPlayer = false;

  @override
  void initState() {
    super.initState();
    final String? videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);

    if (videoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          // Add other flags as needed
        ),
      );
      _showPlayer = true; // Only show player if ID is valid
    } else {
      // Handle invalid URL - maybe show error or pop back?
      print("Error: Invalid YouTube URL provided: ${widget.videoUrl}");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Invalid video link."),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  void dispose() {
    if (_showPlayer) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use a specific AppBar for the player or make it minimal
      appBar: const MamaCareAppBar(title: "Video Player"),
      body: Center(
        child:
            _showPlayer
                ? YoutubePlayer(
                  controller: _controller,
                  showVideoProgressIndicator: true,
                  // Add progress indicator colors, etc.
                  // onReady: () { print('Player is ready.'); },
                )
                : const Text(
                  "Invalid Video URL",
                ), // Fallback if ID extraction failed
      ),
    );
  }
}
