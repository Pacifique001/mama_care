import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:mama_care/presentation/viewmodel/article_viewmodel.dart';
import 'package:mama_care/utils/asset_helper.dart';
import 'package:mama_care/presentation/widgets/mama_care_app_bar.dart';

class ArticleView extends StatelessWidget {
  const ArticleView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final articleViewModel = Provider.of<ArticleViewModel>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: MamaCareAppBar(
        trailingWidget: const Icon(Icons.more_vert, color: Colors.white),
        title: "Article",
        backgroundColor: Colors.transparent,
      ),
      body: articleViewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildArticleImage(articleViewModel),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                articleViewModel.article?.title ?? 'No Title',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: const Color(0xFFE91E63),
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                articleViewModel.isBookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border_rounded,
                                color: const Color(0xFFE91E63),
                              ),
                              onPressed: articleViewModel.toggleBookmark,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          articleViewModel.article?.detail ?? 'No Content',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[800],
                                fontSize: 14.sp,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildArticleImage(ArticleViewModel articleViewModel) {
    return Image.network(
      articleViewModel.article?.image ?? AssetsHelper.maternalImage,
      height: 30.h,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }
}