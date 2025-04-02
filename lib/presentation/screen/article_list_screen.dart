import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/presentation/view/article_list_view.dart';
import 'package:mama_care/presentation/viewmodel/article_list_viewmodel.dart';
import 'package:mama_care/domain/usecases/article_usecase.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/injection.dart';

class ArticleListScreen extends StatelessWidget {
  const ArticleListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ArticleListViewModel(
        locator<ArticleUseCase>(),
        locator<DatabaseHelper>(),
      ),
      child: const Scaffold(
        body: ArticleListView(),
      ),
    );
  }
}