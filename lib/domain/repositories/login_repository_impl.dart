import 'dart:math';
import 'package:injectable/injectable.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:mama_care/data/repositories/login_repository.dart';
import 'package:mama_care/data/local/database_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mama_care/domain/entities/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@Injectable(as: LoginRepository)
class LoginRepositoryImpl implements LoginRepository {
  final DatabaseHelper _databaseHelper;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseMessaging _firebaseMessaging;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _smtpUsername = 'tzrpcfq@gmail.com';
  String _smtpPassword = 'aola bptx psyz rvfw';

  LoginRepositoryImpl(this._databaseHelper, this._firebaseMessaging) {
    _initializeEmailCredentials();
  }

  Future<void> _initializeEmailCredentials() async {
    final smtpCredentials = await _databaseHelper.query('smtp_credentials');
    if (smtpCredentials.isNotEmpty) {
      _smtpUsername = smtpCredentials.first['username'] ?? 'tzrpcfq@gmail.com';
      _smtpPassword = smtpCredentials.first['password'] ?? 'aola bptx psyz rvfw';
    }
  }

  @override
  Future<UserCredential?> login(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        final token = await _firebaseMessaging.getToken();
        if (token != null) {
          await _updateUserFCMToken(userCredential.user!.uid, token);
        }
      }
      
      final user = await _databaseHelper.getUserByEmail(email);
      if (user == null) {
        await _databaseHelper.insertUser({
          'email': email,
          'password': '',
          'name': userCredential.user?.displayName ?? 'User',
          'phoneNumber': userCredential.user?.phoneNumber ?? '',
          'profileImageUrl': userCredential.user?.photoURL ?? '',
          'firebaseUid': userCredential.user?.uid ?? '',
          'lastLoginTime': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        await _databaseHelper.updateUserLastLogin(email);
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Login error: ${e.code} - ${e.message}');
      if (e.code == 'user-not-found') {
        throw Exception('No account found with this email');
      } else if (e.code == 'wrong-password') {
        throw Exception('Incorrect password');
      } else if (e.code == 'user-disabled') {
        throw Exception('This account has been disabled');
      } else if (e.code == 'too-many-requests') {
        throw Exception('Too many failed login attempts. Try again later');
      }
      throw Exception('Login failed: ${e.message}');
    } catch (e) {
      print('Login error: $e');
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  @override
  Future<UserCredential> googleLogin() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign-In was canceled');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _firebaseAuth.signInWithCredential(credential);
    } catch (e) {
      print('Google login error: $e');
      rethrow;
    }
  }

  Future<void> _updateUserFCMToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  @override
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
    required String profileImageUrl,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      await userCredential.user?.updateDisplayName(name);
      if (profileImageUrl.isNotEmpty) {
        await userCredential.user?.updatePhotoURL(profileImageUrl);
      }
      
      if (userCredential.user != null) {
        final token = await _firebaseMessaging.getToken();
        if (token != null) {
          await _updateUserFCMToken(userCredential.user!.uid, token);
        }
      }
      
      await _databaseHelper.insertUser({
        'email': email,
        'password': '',
        'name': name,
        'phoneNumber': phoneNumber,
        'profileImageUrl': profileImageUrl,
        'firebaseUid': userCredential.user?.uid ?? '',
        'lastLoginTime': DateTime.now().millisecondsSinceEpoch,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      
      await _firebaseMessaging.subscribeToTopic('general');
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Sign-up error: ${e.code} - ${e.message}');
      if (e.code == 'email-already-in-use') {
        throw Exception('An account already exists with this email');
      } else if (e.code == 'weak-password') {
        throw Exception('The password is too weak');
      } else if (e.code == 'invalid-email') {
        throw Exception('The email address is not valid');
      }
      throw Exception('Sign-up failed: ${e.message}');
    } catch (e) {
      print('Sign-up error: $e');
      throw Exception('Sign-up failed: ${e.toString()}');
    }
  }

  @override
  Future<void> sendEmailOTP(String email) async {
    final otp = _generateOTP();
    final expiryTime = DateTime.now().add(Duration(minutes: 30)).millisecondsSinceEpoch;
    await _databaseHelper.insertOrUpdateOTP(email, otp, expiryTime);

    if (_smtpUsername == null || _smtpPassword == null) {
      await _initializeEmailCredentials();
    }

    final smtpServer = gmail(_smtpUsername!, _smtpPassword!);
    final message = Message()
      ..from = Address(_smtpUsername!, 'MamaCare')
      ..recipients.add(email)
      ..subject = 'Your OTP for MamaCare'
      ..html = '''
        <div style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 5px;">
          <h2 style="color: #4a4a4a;">MamaCare Verification</h2>
          <p>Hello,</p>
          <p>Your one-time password (OTP) for MamaCare is:</p>
          <div style="background-color: #f5f5f5; padding: 15px; text-align: center; font-size: 24px; font-weight: bold; margin: 20px 0; letter-spacing: 5px;">
            $otp
          </div>
          <p>This OTP will expire in 30 minutes.</p>
          <p>If you didn't request this OTP, please ignore this email.</p>
          <p>Thank you,<br>MamaCare Team</p>
        </div>
      ''';

    try {
      final sendReport = await send(message, smtpServer);
      print('OTP sent to $email: ${sendReport.toString()}');
    } on MailerException catch (e) {
      print('Failed to send OTP: $e');
      throw Exception('Failed to send OTP. Please try again.');
    } catch (e) {
      print('Email error: $e');
      throw Exception('Error sending email: ${e.toString()}');
    }
  }

  @override
  Future<bool> verifyEmailOTP(String email, String otp) async {
    final otpData = await _databaseHelper.getOTPWithExpiry(email);
    if (otpData == null) {
      return false;
    }
    
    final storedOTP = otpData['otp'];
    final expiryTime = otpData['expiryTime'];
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    if (currentTime > expiryTime) {
      await _databaseHelper.deleteOTP(email);
      return false;
    }

    if (storedOTP == otp) {
      await _databaseHelper.deleteOTP(email);
      return true;
    }
    return false;
  }

  @override
  Future<void> logout() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        try {
          await _firebaseMessaging.unsubscribeFromTopic('general');
        } catch (e) {
          print('Error unsubscribing from topics: $e');
        }
      }
      await _firebaseAuth.signOut();
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      print('Logout error: $e');
      throw Exception('Logout failed: ${e.toString()}');
    }
  }

  @override
  Future<void> saveUserToLocalDatabase(Map<String, dynamic> userData) async {
    try {
      await _databaseHelper.insert('users', userData);
    } catch (e) {
      print('Error saving user to local database: $e');
      rethrow;
    }
  }

  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }
}