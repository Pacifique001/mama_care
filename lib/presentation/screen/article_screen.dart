import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/presentation/view/article_view.dart';
import 'package:mama_care/presentation/viewmodel/article_viewmodel.dart';
import 'package:mama_care/domain/usecases/article_usecase.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/injection.dart';

class ArticleScreen extends StatelessWidget {
  final String articleId;

  const ArticleScreen({Key? key, required this.articleId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ArticleViewModel(
        locator<ArticleUseCase>(),
        articleId,
      ),
      child: const ArticleView(),
    );
  }
}