// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  id: json['id'] as String,
  name: json['name'] as String,
  email: json['email'] as String,
  phoneNumber: json['phoneNumber'] as String?,
  password: json['password'] as String?,
  profileImageUrl: json['profileImageUrl'] as String?,
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'email': instance.email,
  'phoneNumber': instance.phoneNumber,
  'password': instance.password,
  'profileImageUrl': instance.profileImageUrl,
};
