import 'package:mama_care/injection.config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:mama_care/data/repositories/calendar_repository.dart';
import 'package:mama_care/data/repositories/dashboard_repository.dart';
import 'package:mama_care/data/repositories/hospital_repository.dart';
import 'package:mama_care/data/repositories/login_repository.dart';
import 'package:mama_care/data/repositories/notification_repository.dart';
import 'package:mama_care/data/repositories/pregnancy_detail_repository.dart';
import 'package:mama_care/data/repositories/profile_repository.dart';
import 'package:mama_care/data/repositories/risk_detector_repository.dart';
import 'package:mama_care/data/repositories/timeline_repository.dart';
import 'package:mama_care/data/repositories/video_repository.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:mama_care/domain/usecases/calendar_use_case.dart';
import 'package:mama_care/domain/usecases/dashboard_use_case.dart';
import 'package:mama_care/domain/usecases/hospital_use_case.dart';
import 'package:mama_care/domain/usecases/login_use_case.dart';
import 'package:mama_care/domain/usecases/notification_use_case.dart';
import 'package:mama_care/domain/usecases/pregnancy_detail_use_case.dart';
import 'package:mama_care/domain/usecases/profile_use_case.dart';
import 'package:mama_care/domain/usecases/risk_detector_use_case.dart';
import 'package:mama_care/domain/usecases/timeline_use_case.dart';
import 'package:mama_care/domain/usecases/video_usecase.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'injection.config.dart';

final locator = GetIt.instance;

@InjectableInit(
  initializerName: r'$initGetIt',
  preferRelativeImports: true,
  asExtension: false,
)
Future<void> configureDependencies() async => $initGetIt(locator);

// External dependencies need to be registered
@module
abstract class RegisterModule {
  @singleton
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;
  
  @singleton
  FirebaseFirestore get firebaseFirestore => FirebaseFirestore.instance;
  
  @singleton
  FirebaseMessaging get firebaseMessaging => FirebaseMessaging.instance;
  
  @singleton
  GoogleSignIn get googleSignIn => GoogleSignIn();
  
  @singleton
  Dio get dio => Dio();
  
  @singleton
  DatabaseHelper get databaseHelper => DatabaseHelper();


}