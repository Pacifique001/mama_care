import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final String id;
  String name;
  String email;
  String? phoneNumber;
  String? password;
  String? profileImageUrl;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.password,
    this.profileImageUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      password: json['password'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'password': password,
      'profileImageUrl': profileImageUrl,
    };
  }

  void updateProfile({
    String? name,
    String? email,
    String? phoneNumber,
    String? password,
    String? profileImageUrl,
  }) {
    if (name != null) this.name = name;
    if (email != null) this.email = email;
    if (password != null) this.password = password;
    if (phoneNumber != null) this.phoneNumber = phoneNumber;
    if (profileImageUrl != null) this.profileImageUrl = profileImageUrl;
  }
}
