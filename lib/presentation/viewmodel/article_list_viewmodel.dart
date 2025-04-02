import 'package:flutter/material.dart';
import 'package:mama_care/domain/usecases/article_usecase.dart';
import 'package:mama_care/domain/entities/article_model.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/utils/asset_helper.dart';

class ArticleListViewModel extends ChangeNotifier {
  final ArticleUseCase _articleUseCase;
  final DatabaseHelper _databaseHelper;

  ArticleListViewModel(this._articleUseCase, this._databaseHelper);

  List<ArticleModel> _articles = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _searchQuery;

  final List<Map<String, dynamic>> _articleData = [];

  List<ArticleModel> get articles => _articles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get searchQuery => _searchQuery;

  List<Map<String, dynamic>> get articleData => _articleData;

  List<Map<String, dynamic>> get articleList {
    return [
      {
        'title': 'Article 1',
        'description': 'Read this article for more information',
        'image': AssetsHelper.pregnantWoman,
      },
    ];
  }

  Future<void> fetchArticles() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _articles = await _articleUseCase.getArticles();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load articles: ${e.toString()}';
      _articles = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchArticles(String query) async {
    _isLoading = true;
    _searchQuery = query;
    notifyListeners();

    try {
      _articles = await _articleUseCase.searchArticles(query);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Search failed: ${e.toString()}';
      _articles = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshArticles() async {
    await fetchArticles();
  }

  ArticleModel? getArticleById(String id) {
    return _articles.firstWhere((article) => article.id == id);
  }

  Future<void> toggleBookmark(String articleId) async {
    try {
      final article = _articles.firstWhere((a) => a.id == articleId);
      final updatedArticle = await _articleUseCase.toggleBookmark(article);
      
      final index = _articles.indexWhere((a) => a.id == articleId);
      _articles[index] = updatedArticle;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update bookmark status: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<List<ArticleModel>> getBookmarkedArticles() async {
    try {
      return await _articleUseCase.getBookmarkedArticles();
    } catch (e) {
      _errorMessage = 'Failed to get bookmarked articles: ${e.toString()}';
      return [];
    }
  }
}