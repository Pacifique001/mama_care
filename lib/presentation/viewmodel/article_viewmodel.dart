import 'package:flutter/material.dart';
import 'package:mama_care/domain/usecases/article_usecase.dart';
import 'package:mama_care/domain/entities/article_model.dart';
import 'package:mama_care/utils/asset_helper.dart';

class ArticleViewModel extends ChangeNotifier {
  final ArticleUseCase _articleUseCase;
  final String articleId;

  ArticleViewModel(this._articleUseCase, this.articleId);

  // State variables
  ArticleModel? _article;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isBookmarked = false;

  // Getters
  ArticleModel? get article => _article;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isBookmarked => _isBookmarked;

  String get articleImage {
    return AssetsHelper.prenatalYogaArticle; // Example asset
  }

  // Load article by ID
  Future<void> getArticleById() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _article = await _articleUseCase.getArticleById(articleId);
      _isBookmarked = _article?.isBookmarked ?? false;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load article: ${e.toString()}';
      _article = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Toggle bookmark status
  Future<void> toggleBookmark() async {
    if (_article == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final updatedArticle = await _articleUseCase.toggleBookmark(_article!);
      _article = updatedArticle;
      _isBookmarked = updatedArticle.isBookmarked;
    } catch (e) {
      _errorMessage = 'Failed to update bookmark status: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Share article
  Future<void> shareArticle() async {
    if (_article == null) return;

    try {
      // Implement sharing functionality
      //Share.share('Check out this article: ${_article!['title']}');
    } catch (e) {
      _errorMessage = 'Failed to share article: ${e.toString()}';
      notifyListeners();
    }
  }

  // Add comment
  Future<void> addComment(String comment) async {
    if (_article == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      // Implement comment functionality
     // await _articleUseCase.addComment(_article!['id'], comment);
    } catch (e) {
      _errorMessage = 'Failed to add comment: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 