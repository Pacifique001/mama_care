import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:mama_care/presentation/screen/article_screen.dart';
import 'package:mama_care/presentation/viewmodel/article_list_viewmodel.dart';
import '../widgets/mama_care_app_bar.dart';
import 'package:mama_care/utils/asset_helper.dart';
import 'package:mama_care/navigation/router.dart';

class ArticleListView extends StatefulWidget {
  const ArticleListView({Key? key}) : super(key: key);

  @override
  State<ArticleListView> createState() => _ArticleListViewState();
}

class _ArticleListViewState extends State<ArticleListView> {
  @override
  void initState() {
    super.initState();
    Provider.of<ArticleListViewModel>(context, listen: false).fetchArticles();
  }

  @override
  Widget build(BuildContext context) {
    final articleViewModel = Provider.of<ArticleListViewModel>(context);

    return Scaffold(
      appBar: MamaCareAppBar(
        title: "Articles",
        trailingWidget: const Icon(Icons.more_vert, color: Colors.pinkAccent),
      ),
      body: articleViewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: articleViewModel.articles.length,
              itemBuilder: (context, index) {
                final article = articleViewModel.articles[index];
                return ArticleListCard(
                  title: article.title,
                  detail: article.detail,
                  image: article.image,
                  index: index,
                );
              },
            ),
    );
  }
}

class ArticleListCard extends StatelessWidget {
  final String title;
  final String detail;
  final String image;
  final int index;

  const ArticleListCard({
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
              ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: Image.asset(
                  image,
                  height: 30.h,
                  fit: BoxFit.cover,
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
                      final articleViewModel = Provider.of<ArticleListViewModel>(context, listen: false);
                      await articleViewModel.toggleBookmark(articleViewModel.articles[index].id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Article saved to favorites!"),
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