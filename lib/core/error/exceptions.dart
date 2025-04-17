import 'package:flutter/foundation.dart'; // For @immutable

/// Base class for all custom exceptions in the application.
@immutable // Exceptions should generally be immutable
abstract class AppException implements Exception {
  /// A user-friendly message describing the error.
  final String message;

  /// The original error/exception that caused this AppException, if any.
  /// Useful for logging and debugging.
  final Object? cause;

  /// The stack trace associated with the original error, if available.
  final StackTrace? stackTrace;

  const AppException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() {
    String result = '$runtimeType: $message';
    // Optional: Include cause details only in debug mode or specific logging
    // if (kDebugMode && cause != null) {
    //   result += '\nCause: $cause';
    // }
    return result;
  }
}

// --- Specific Exception Types ---

/// Exception related to authentication operations (login, signup, token issues, permissions).
class AuthException extends AppException {
  /// Indicates if the exception was due to user cancellation (e.g., Google Sign-In).
  final bool isCancelled;

  /// Specific error code from the authentication provider (e.g., FirebaseAuth).
  final String? code;

  const AuthException(
    super.message, {
    this.code,
    this.isCancelled = false,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() =>
      'AuthException: $message ${isCancelled ? "(Cancelled by user)" : ""}${code != null ? " (Code: $code)" : ""}';
}

/// Exception related to local database operations (SQLite failures, constraint violations).
class DatabaseException extends AppException {
  const DatabaseException(
    super.message, {
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() => 'DatabaseException: $message';
}

/// Exception related to network operations (connectivity, timeouts, DNS issues).
class NetworkException extends AppException {
  const NetworkException(
    super.message, {
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() => 'NetworkException: $message';
}

/// Exception related to API calls (non-2xx responses, specific backend errors).
class ApiException extends AppException {
  /// HTTP status code from the API response, if available.
  final int? statusCode;

  const ApiException(
    super.message, {
    this.statusCode,
    super.cause, // Often the DioException or http.Response
    super.stackTrace,
  });

  @override
  String toString() {
    String result = 'ApiException: $message';
    if (statusCode != null) {
      result += ' (Status Code: $statusCode)';
    }
    return result;
  }
}

/// Exception when data fetched or received cannot be parsed, decoded, or processed correctly.
class DataProcessingException extends AppException {
  const DataProcessingException(
    super.message, {
    super.cause, // e.g., FormatException during jsonDecode
    super.stackTrace,
  });

  @override
  String toString() => 'DataProcessingException: $message';
}

/// Exception when a specific resource (e.g., user, article, video) is not found.
/// Can be used for both local DB (e.g., query returns empty) and API (e.g., 404 status).
class NotFoundException extends AppException {
  /// Optional identifier of the resource that was not found.
  final String? resourceId;

  const NotFoundException(
    super.message, {
    this.resourceId,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() => 'NotFoundException: $message${resourceId != null ? " (ID: $resourceId)" : ""}';
}

/// Exception for errors specifically during caching operations (saving/loading from cache).
/// Might overlap with DatabaseException if the cache is the DB. Use if distinguishing is helpful.
class CacheException extends AppException {
  const CacheException(
    super.message, {
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() => 'CacheException: $message';
}

/// Exception related to application configuration issues (e.g., missing keys, invalid settings).
class ConfigurationException extends AppException {
  const ConfigurationException(
    super.message, {
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() => 'ConfigurationException: $message';
}


/// Exception specifically for unimplemented features or methods.
class UnimplementedFeatureException extends AppException {
  const UnimplementedFeatureException(String featureName)
      : super("$featureName is not implemented yet.");

  @override
  String toString() => 'UnimplementedFeatureException: $message';
}


// --- Refined Usage in Repositories ---

// How the exceptions would now be thrown in the repositories:

// LoginRepositoryImpl:
// throw AuthException(_parseFirebaseErrorMsg(e.code, "Login failed"), code: e.code, cause: e, stackTrace: stackTrace);
// throw AuthException("Google Sign-In cancelled.", isCancelled: true);
// throw AuthException("An unexpected error occurred during login.", cause: e, stackTrace: stackTrace);
// throw UnimplementedFeatureException("OTP sending/verification (must be backend)");

// NotificationRepositoryImpl:
// throw DatabaseException("Failed to save notification.", cause: e, stackTrace: stackTrace);
// throw DatabaseException("Failed to load notifications.", cause: e, stackTrace: stackTrace);
// throw UnimplementedFeatureException("Client-side notification sending");

// VideoRepositoryImpl:
// throw DatabaseException('Article not found, cannot update bookmark.', cause: e); // If count == 0 in toggleBookmark DB update
// throw NetworkException("Network error during fetching videos...", cause: e, stackTrace: stackTrace); // from DioException catch
// throw ApiException("API Error (fetching videos): ${e.response?.statusCode}...", cause: e, stackTrace: stackTrace);
// throw NotFoundException("fetching video $id target not found.", resourceId: id, cause: e); // from 404
// throw DataProcessingException('Could not process video data.', cause: e, stackTrace: stackTrace); // Generic catch