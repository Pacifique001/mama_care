// lib/domain/entities/user_model.dart

import 'dart:convert'; // For jsonEncode/Decode
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart'; // For @immutable
import 'package:mama_care/domain/entities/user_role.dart'; // Import UserRole enum
import 'package:json_annotation/json_annotation.dart'; // If using generator

part 'user_model.g.dart'; // If using generator

@immutable // Mark class as immutable
@JsonSerializable(explicitToJson: true, anyMap: true) // If using generator
class UserModel extends Equatable {
  // --- Core Identifiers ---
  final String id; // Local DB/Primary ID (often same as firebaseId)
  final String firebaseId; // Firebase Auth UID (should be non-nullable after auth)

  // --- Profile Info ---
  final String name;
  final String email;
  final String? phoneNumber;
  final String? profileImageUrl;
  final bool verified; // Email verification status from Firebase Auth

  // --- Authentication/Metadata ---
  final String? password; // Hashed password (ONLY for purely local auth, usually null)
  final int createdAt; // Timestamp ms (non-nullable, set on creation)
  final int? lastLogin; // Timestamp ms (nullable)

  // --- App-Specific ---
  final UserRole role;
  final List<String> permissions;

  // --- Sync Status (If using local DB sync) ---
  final int syncStatus; // 0=Synced, 1=NeedsPush, 2=NeedsPull, 3=Error
  final int? lastSynced; // Timestamp ms

  // --- Constructor ---
  const UserModel({
    required this.id,
    required this.firebaseId,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.password, // Keep nullable
    this.profileImageUrl,
    required this.verified, // Required from Firebase Auth
    required this.createdAt, // Required, set on creation
    this.lastLogin,
    required this.role, // Make role required
    this.permissions = const [], // Default permissions
    this.syncStatus = 0,
    this.lastSynced,
  });

  // --- Factory Constructors ---

  /// Creates a UserModel from a Firebase Auth User object.
  /// **IMPORTANT:** This assigns a DEFAULT role/permissions.
  /// The actual role/permissions must be fetched from Firestore/Backend afterwards.
  factory UserModel.fromFirebaseAuth(User firebaseUser, {UserRole defaultRole = UserRole.patient}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return UserModel(
      id: firebaseUser.uid, // Use Firebase UID as the primary ID
      firebaseId: firebaseUser.uid,
      email: firebaseUser.email ?? '', // Handle null email defensively
      name: firebaseUser.displayName ?? 'New User', // Default if no display name
      phoneNumber: firebaseUser.phoneNumber,
      profileImageUrl: firebaseUser.photoURL,
      verified: firebaseUser.emailVerified,
      createdAt: firebaseUser.metadata.creationTime?.millisecondsSinceEpoch ?? now,
      lastLogin: firebaseUser.metadata.lastSignInTime?.millisecondsSinceEpoch ?? now,
      role: defaultRole, // Assign default role, MUST be updated from Firestore/Backend
      permissions: [], // Assign empty permissions, MUST be updated
      password: null, // No password needed from Firebase Auth
      syncStatus: 0, // Assume synced initially when created from Firebase
      lastSynced: now,
    );
  }

   /// Creates a UserModel from a Map (e.g., from Firestore or local DB).
   /// Parses role and permissions.
   factory UserModel.fromMap(Map<String, dynamic> map) {
     final now = DateTime.now().millisecondsSinceEpoch; // Fallback timestamp
     return UserModel(
       id: map['id'] as String? ?? map['firebaseId'] as String? ?? '', // Use id or firebaseId
       firebaseId: map['firebaseId'] as String? ?? map['id'] as String? ?? '', // Use firebaseId or id
       email: map['email'] as String? ?? '',
       name: map['name'] as String? ?? 'Unknown User',
       password: map['password'] as String?, // Load hashed password if exists
       phoneNumber: map['phoneNumber'] as String?,
       profileImageUrl: map['profileImageUrl'] as String?,
       verified: (map['verified'] == 1 || map['verified'] == true), // Handle int/bool
       createdAt: map['createdAt'] as int? ?? now, // Provide default
       lastLogin: map['lastLogin'] as int?,
       syncStatus: map['syncStatus'] as int? ?? 0,
       lastSynced: map['lastSynced'] as int?,
       // --- Load Role and Permissions ---
       role: userRoleFromString(map['role'] as String?), // Parse role from String
       permissions: _parsePermissions(map['permissions']), // Parse permissions
     );
   }

   // Alias for consistency if using json_serializable elsewhere
   factory UserModel.fromJson(Map<String, dynamic> json) => UserModel.fromMap(json);

   /// Provides an empty UserModel, useful for initial states.
   factory UserModel.empty() => UserModel(
       id: '',
       firebaseId: '',
       name: '',
       email: '',
       verified: false,
       createdAt: DateTime.now().millisecondsSinceEpoch, // Set creation time
       role: UserRole.unknown, // Explicitly unknown
     );


  // --- Serialization ---

  /// Converts the UserModel instance into a map suitable for Firestore or local DB.
  /// Encodes permissions list into a JSON string for DB compatibility.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firebaseId': firebaseId,
      'email': email.toLowerCase(), // Store email consistently
      'name': name,
      //'password': password, // Exclude password unless explicitly needed for storage
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'verified': verified, // Store as bool (Firestore) or int (SQLite - handled below)
      'createdAt': createdAt,
      'lastLogin': lastLogin,
      'syncStatus': syncStatus,
      'lastSynced': lastSynced,
      'role': userRoleToString(role), // Store role as String
      'permissions': permissions, // Store permissions as List<String> in Firestore
      // Add lastUpdated timestamp for Firestore sync trigger if needed
      // 'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

   /// Converts to a map suitable for SQLite storage (bools as ints, lists as JSON).
   Map<String, dynamic> toSqliteMap() {
     return {
       'id': id,
       'firebaseId': firebaseId,
       'email': email.toLowerCase(),
       'name': name,
       'password': password, // Include password hash for local DB if used
       'phoneNumber': phoneNumber,
       'profileImageUrl': profileImageUrl,
       'verified': verified ? 1 : 0, // Convert bool to int
       'createdAt': createdAt,
       'lastLogin': lastLogin,
       'syncStatus': syncStatus,
       'lastSynced': lastSynced,
       'role': userRoleToString(role),
       'permissions': jsonEncode(permissions), // Encode list to JSON string
     };
   }

  // Alias for consistency if using json_serializable elsewhere
  Map<String, dynamic> toJson() => toMap(); // Default to Firestore map


  // --- Equatable Overrides ---
  @override
  List<Object?> get props => [
        id, firebaseId, name, email, phoneNumber, profileImageUrl, verified,
        createdAt, lastLogin, syncStatus, lastSynced,
        role, permissions // Include role and permissions
        // Exclude password from equality check
      ];

  @override
  bool get stringify => true; // Generate helpful toString

  // --- CopyWith Method ---
  UserModel copyWith({
    String? id,
    String? firebaseId,
    String? name,
    String? email,
    String? Function()? phoneNumber, // Use function type directly
    String? Function()? password,
    String? Function()? profileImageUrl,
    bool? verified,
    int? createdAt,
    ValueGetter<int?>? lastLogin,
    int? syncStatus,
    ValueGetter<int?>? lastSynced,
    UserRole? role,
    List<String>? permissions,
  }) {
    return UserModel(
      id: id ?? this.id,
      firebaseId: firebaseId ?? this.firebaseId,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber != null ? phoneNumber() : this.phoneNumber,
      password: password != null ? password() : this.password,
      profileImageUrl: profileImageUrl != null ? profileImageUrl() : this.profileImageUrl,
      verified: verified ?? this.verified,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin != null ? lastLogin() : this.lastLogin,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSynced: lastSynced != null ? lastSynced() : this.lastSynced,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
    );
  }

  // --- Helper Methods ---

   /// Helper to parse permissions list from DB (handles String or List).
   static List<String> _parsePermissions(dynamic dbValue) {
      if (dbValue is List) {
         // If it's already a list (e.g., from Firestore), ensure elements are strings
         return List<String>.from(dbValue.map((p) => p.toString()));
      }
      if (dbValue is String) { // If it's a JSON string (from SQLite)
         try {
           final decoded = jsonDecode(dbValue);
           if (decoded is List) {
              return List<String>.from(decoded.map((p) => p.toString()));
           }
         } catch (_) {
            print("Warning: Failed to decode permissions JSON string: $dbValue");
         }
      }
      return const []; // Default empty list
   }

   // --- Convenience Getters (Removed mutator methods) ---
   bool get isVerified => verified; // Direct access
   bool get hasCompleteProfile => name.isNotEmpty && email.isNotEmpty; // Simplified example
   DateTime? get lastLoginDate => lastLogin != null ? DateTime.fromMillisecondsSinceEpoch(lastLogin!) : null;
   DateTime get creationDate => DateTime.fromMillisecondsSinceEpoch(createdAt);

  void updateProfile({required String name, required String email, required String phoneNumber, String? password, String? profileImageUrl}) {}

}


// Ensure user_role.dart exists with the enum and helper functions:
/*
// lib/domain/entities/user_role.dart
enum UserRole { patient, nurse, doctor, admin, unknown }

UserRole userRoleFromString(String? roleString) { ... }
String userRoleToString(UserRole role) { ... }
*/