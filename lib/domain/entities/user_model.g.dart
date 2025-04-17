// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map json) => UserModel(
  id: json['id'] as String,
  firebaseId: json['firebaseId'] as String,
  name: json['name'] as String,
  email: json['email'] as String,
  phoneNumber: json['phoneNumber'] as String?,
  password: json['password'] as String?,
  profileImageUrl: json['profileImageUrl'] as String?,
  verified: json['verified'] as bool,
  createdAt: (json['createdAt'] as num).toInt(),
  lastLogin: (json['lastLogin'] as num?)?.toInt(),
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  permissions:
      (json['permissions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  syncStatus: (json['syncStatus'] as num?)?.toInt() ?? 0,
  lastSynced: (json['lastSynced'] as num?)?.toInt(),
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.id,
  'firebaseId': instance.firebaseId,
  'name': instance.name,
  'email': instance.email,
  'phoneNumber': instance.phoneNumber,
  'profileImageUrl': instance.profileImageUrl,
  'verified': instance.verified,
  'password': instance.password,
  'createdAt': instance.createdAt,
  'lastLogin': instance.lastLogin,
  'role': _$UserRoleEnumMap[instance.role]!,
  'permissions': instance.permissions,
  'syncStatus': instance.syncStatus,
  'lastSynced': instance.lastSynced,
};

const _$UserRoleEnumMap = {
  UserRole.patient: 'patient',
  UserRole.nurse: 'nurse',
  UserRole.doctor: 'doctor',
  UserRole.admin: 'admin',
  UserRole.unknown: 'unknown',
};
