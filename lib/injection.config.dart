// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:dio/dio.dart' as _i361;
import 'package:firebase_auth/firebase_auth.dart' as _i59;
import 'package:firebase_messaging/firebase_messaging.dart' as _i892;
import 'package:get_it/get_it.dart' as _i174;
import 'package:google_sign_in/google_sign_in.dart' as _i116;
import 'package:injectable/injectable.dart' as _i526;

import 'data/local/database_helper.dart' as _i441;
import 'data/repositories/article_repository.dart' as _i11;
import 'data/repositories/calendar_repository.dart' as _i879;
import 'data/repositories/dashboard_repository.dart' as _i1059;
import 'data/repositories/food_repository.dart' as _i865;
import 'data/repositories/hospital_repository.dart' as _i343;
import 'data/repositories/login_repository.dart' as _i48;
import 'data/repositories/notification_repository.dart' as _i718;
import 'data/repositories/pregnancy_detail_repository.dart' as _i993;
import 'data/repositories/profile_repository.dart' as _i1011;
import 'data/repositories/risk_detector_repository.dart' as _i844;
import 'data/repositories/signup_repository.dart' as _i771;
import 'data/repositories/timeline_repository.dart' as _i625;
import 'data/repositories/video_repository.dart' as _i1010;
import 'domain/repositories/article_repository_impl.dart' as _i1026;
import 'domain/repositories/calendar_repository_impl.dart' as _i350;
import 'domain/repositories/dashboard_repository_impl.dart' as _i909;
import 'domain/repositories/firebase_auth_repository.dart' as _i964;
import 'domain/repositories/food_repository_impl.dart' as _i531;
import 'domain/repositories/hospital_repository_impl.dart' as _i49;
import 'domain/repositories/login_repository_impl.dart' as _i389;
import 'domain/repositories/notification_repository_impl.dart' as _i792;
import 'domain/repositories/pregnancy_detail_repository_impl.dart' as _i947;
import 'domain/repositories/profile_repository_impl.dart' as _i125;
import 'domain/repositories/risk_detector_repository_impl.dart' as _i224;
import 'domain/repositories/timeline_repository_impl.dart' as _i878;
import 'domain/repositories/video_repository_impl.dart' as _i1041;
import 'domain/usecases/article_usecase.dart' as _i160;
import 'domain/usecases/calendar_use_case.dart' as _i65;
import 'domain/usecases/dashboard_use_case.dart' as _i736;
import 'domain/usecases/food_usecase.dart' as _i59;
import 'domain/usecases/hospital_use_case.dart' as _i157;
import 'domain/usecases/login_use_case.dart' as _i1005;
import 'domain/usecases/notification_use_case.dart' as _i356;
import 'domain/usecases/pregnancy_detail_use_case.dart' as _i870;
import 'domain/usecases/profile_use_case.dart' as _i808;
import 'domain/usecases/risk_detector_use_case.dart' as _i850;
import 'domain/usecases/signup_use_case.dart' as _i829;
import 'domain/usecases/timeline_use_case.dart' as _i1011;
import 'domain/usecases/video_usecase.dart' as _i155;
import 'injection.dart' as _i464;
import 'presentation/viewmodel/auth_viewmodel.dart' as _i785;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt $initGetIt(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  final registerModule = _$RegisterModule();
  gh.factory<_i964.FirebaseAuthRepository>(
    () => _i964.FirebaseAuthRepository(),
  );
  gh.singleton<_i59.FirebaseAuth>(() => registerModule.firebaseAuth);
  gh.singleton<_i974.FirebaseFirestore>(() => registerModule.firebaseFirestore);
  gh.singleton<_i892.FirebaseMessaging>(() => registerModule.firebaseMessaging);
  gh.singleton<_i116.GoogleSignIn>(() => registerModule.googleSignIn);
  gh.singleton<_i361.Dio>(() => registerModule.dio);
  gh.singleton<_i441.DatabaseHelper>(() => registerModule.databaseHelper);
  gh.factory<_i865.FoodRepository>(() => _i531.FoodRepositoryImpl());
  gh.factory<_i59.FoodUseCase>(
    () => _i59.FoodUseCase(gh<_i865.FoodRepository>()),
  );
  gh.factory<_i625.TimelineRepository>(
    () => _i878.TimelineRepositoryImpl(
      gh<_i59.FirebaseAuth>(),
      gh<_i974.FirebaseFirestore>(),
      gh<_i441.DatabaseHelper>(),
      gh<_i892.FirebaseMessaging>(),
    ),
  );
  gh.factory<_i879.CalendarRepository>(
    () => _i350.CalendarRepositoryImpl(gh<_i441.DatabaseHelper>()),
  );
  gh.factory<_i993.PregnancyDetailRepository>(
    () => _i947.PregnancyDetailRepositoryImpl(
      gh<_i59.FirebaseAuth>(),
      gh<_i974.FirebaseFirestore>(),
      gh<_i441.DatabaseHelper>(),
      gh<_i892.FirebaseMessaging>(),
    ),
  );
  gh.factory<_i1059.DashboardRepository>(
    () => _i909.DashboardRepositoryImpl(
      gh<_i441.DatabaseHelper>(),
      gh<_i892.FirebaseMessaging>(),
    ),
  );
  gh.factory<_i11.ArticleRepository>(
    () => _i1026.ArticleRepositoryImpl(
      gh<_i441.DatabaseHelper>(),
      gh<_i892.FirebaseMessaging>(),
    ),
  );
  gh.factory<_i771.SignupRepository>(
    () => _i771.SignupRepository(gh<_i441.DatabaseHelper>()),
  );
  gh.factory<_i718.NotificationRepository>(
    () => _i792.NotificationRepositoryImpl(
      gh<_i892.FirebaseMessaging>(),
      gh<_i441.DatabaseHelper>(),
    ),
  );
  gh.factory<_i343.HospitalRepository>(
    () => _i49.HospitalRepositoryImpl(
      gh<_i361.Dio>(),
      gh<_i441.DatabaseHelper>(),
      gh<_i892.FirebaseMessaging>(),
    ),
  );
  gh.factory<_i736.DashboardUseCase>(
    () => _i736.DashboardUseCase(gh<_i1059.DashboardRepository>()),
  );
  gh.factory<_i1011.ProfileRepository>(
    () => _i125.ProfileRepositoryImpl(
      gh<_i441.DatabaseHelper>(),
      gh<_i892.FirebaseMessaging>(),
    ),
  );
  gh.factory<_i1010.VideoRepository>(
    () =>
        _i1041.VideoRepositoryImpl(gh<_i361.Dio>(), gh<_i441.DatabaseHelper>()),
  );
  gh.factory<_i48.LoginRepository>(
    () => _i389.LoginRepositoryImpl(
      gh<_i441.DatabaseHelper>(),
      gh<_i892.FirebaseMessaging>(),
    ),
  );
  gh.factory<_i844.RiskDetectorRepository>(
    () => _i224.RiskDetectorRepositoryImpl(
      gh<_i361.Dio>(),
      gh<_i441.DatabaseHelper>(),
      gh<_i892.FirebaseMessaging>(),
    ),
  );
  gh.factory<_i1011.TimelineUseCase>(
    () => _i1011.TimelineUseCase(gh<_i625.TimelineRepository>()),
  );
  gh.factory<_i829.SignupUseCase>(
    () => _i829.SignupUseCase(gh<_i771.SignupRepository>()),
  );
  gh.factory<_i160.ArticleUseCase>(
    () => _i160.ArticleUseCase(gh<_i11.ArticleRepository>()),
  );
  gh.factory<_i870.PregnancyDetailUseCase>(
    () => _i870.PregnancyDetailUseCase(gh<_i993.PregnancyDetailRepository>()),
  );
  gh.factory<_i356.NotificationUseCase>(
    () => _i356.NotificationUseCase(gh<_i718.NotificationRepository>()),
  );
  gh.factory<_i157.HospitalUseCase>(
    () => _i157.HospitalUseCase(gh<_i343.HospitalRepository>()),
  );
  gh.factory<_i1005.LoginUseCase>(
    () => _i1005.LoginUseCase(gh<_i48.LoginRepository>()),
  );
  gh.factory<_i65.CalendarUseCase>(
    () => _i65.CalendarUseCase(gh<_i879.CalendarRepository>()),
  );
  gh.factory<_i155.VideoUseCase>(
    () => _i155.VideoUseCase(gh<_i1010.VideoRepository>()),
  );
  gh.factory<_i808.ProfileUseCase>(
    () => _i808.ProfileUseCase(gh<_i1011.ProfileRepository>()),
  );
  gh.factory<_i850.RiskDetectorUseCase>(
    () => _i850.RiskDetectorUseCase(gh<_i844.RiskDetectorRepository>()),
  );
  gh.factory<_i785.AuthViewModel>(
    () => _i785.AuthViewModel(
      gh<_i1005.LoginUseCase>(),
      gh<_i441.DatabaseHelper>(),
      gh<_i892.FirebaseMessaging>(),
      gh<_i964.FirebaseAuthRepository>(),
    ),
  );
  return getIt;
}

class _$RegisterModule extends _i464.RegisterModule {}
