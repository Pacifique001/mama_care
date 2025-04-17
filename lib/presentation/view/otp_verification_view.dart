// lib/presentation/view/otp_verification_view.dart

import 'dart:async'; // For Timer
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/injection.dart'; // Assuming locator for Logger
import 'package:mama_care/navigation/router.dart'; // For navigation
import 'package:mama_care/presentation/viewmodel/auth_viewmodel.dart'; // Import AuthViewModel
import 'package:mama_care/presentation/widgets/custom_button.dart';
import 'package:mama_care/presentation/widgets/mama_care_app_bar.dart'; // Assuming shared AppBar
import 'package:mama_care/utils/app_colors.dart';
import 'package:mama_care/utils/text_styles.dart';
import 'package:mama_care/core/error/exceptions.dart'; // Import custom exceptions
import 'package:pin_code_fields/pin_code_fields.dart'; // Using package for OTP fields
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart'; // Assuming Sizer is used in TextStyles

class OtpVerificationView extends StatefulWidget {
  final String? email; // Receive email used for OTP

  const OtpVerificationView({super.key, this.email});

  @override
  State<OtpVerificationView> createState() => _OtpVerificationViewState();
}

class _OtpVerificationViewState extends State<OtpVerificationView> {
  final _formKey = GlobalKey<FormState>(); // Optional form key
  final _otpController = TextEditingController();
  StreamController<ErrorAnimationType>? _errorController;

  final Logger _logger = locator<Logger>();

  // Resend Timer logic
  Timer? _resendTimer;
  int _resendCooldown = 60; // Cooldown duration in seconds
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _errorController = StreamController<ErrorAnimationType>.broadcast(); // Use broadcast stream if needed elsewhere
    if (widget.email == null || widget.email!.isEmpty) {
        _logger.e("OtpVerificationView initiated without a valid email address.");
        // Optionally show an immediate error or pop the screen if email is critical
    } else {
       _logger.i("OTP Verification for: ${widget.email}");
    }
    _startResendTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _errorController?.close();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _canResend = false; // Ensure cannot resend immediately
    _resendCooldown = 60; // Reset duration
    _resendTimer?.cancel(); // Cancel previous timer

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { // Safety check
          timer.cancel();
          return;
      }
      if (_resendCooldown <= 0) { // Use <= 0
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      } else {
        setState(() {
          _resendCooldown--;
        });
      }
    });
     // Initial state update if timer starts immediately
     if (mounted) {
        setState(() {});
     }
  }

  Future<void> _verifyOtp() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final enteredOtp = _otpController.text.trim();

    if (enteredOtp.length != 6) {
      _errorController?.add(ErrorAnimationType.shake);
      _showErrorSnackbar("Please enter the complete 6-digit OTP.");
      return;
    }

     if (widget.email == null || widget.email!.isEmpty) {
        _showErrorSnackbar("Cannot verify OTP: Email address is missing.");
        return;
     }

     _logger.i("Verifying OTP: $enteredOtp for email: ${widget.email}");
     // Access ViewModel using context.read as it's an action
     final authViewModel = context.read<AuthViewModel>();

     try {
        // --- Assume ViewModel returns Map on success, throws on error ---
        final result = await authViewModel.verifyEmailOTP(widget.email!, enteredOtp);

        // Check mounted state *after* await
        if (!mounted) return;

        // ViewModel now returns Map on success as well
        if (result['status'] == 'success') {
           _logger.i("OTP verification successful for ${widget.email}.");
           _showSuccessSnackbar("Verification successful!");
           // Navigate to the next screen (e.g., Main Screen or Set Password)
           Navigator.pushNamedAndRemoveUntil(
               context,
               NavigationRoutes.mainScreen, // TODO: Adjust route based on context (signup vs password reset)
               (route) => false // Remove all previous routes
           );
        } else {
           // Handle error map returned by ViewModel
            _logger.w("OTP verification failed (ViewModel returned error map): ${result['message']}");
            _errorController?.add(ErrorAnimationType.shake);
            _otpController.clear(); // Clear field on failure
            _showErrorSnackbar(result['message'] ?? "Invalid or expired OTP.");
        }

     } catch (e) { // --- Catch exceptions thrown by ViewModel ---
        _logger.e("Error verifying OTP", error: e);
        if (!mounted) return; // Check mounted state again
         _errorController?.add(ErrorAnimationType.shake);
         _otpController.clear(); // Clear field on failure
        // Use a user-friendly message from custom exceptions or generic one
        _showErrorSnackbar(e is AppException ? e.message : "OTP Verification failed. Please try again.");
     }
  }

   Future<void> _resendOtp() async {
     if (!_canResend || widget.email == null || widget.email!.isEmpty) return;

     FocusManager.instance.primaryFocus?.unfocus();
     _logger.i("Resending OTP for email: ${widget.email}");
     final authViewModel = context.read<AuthViewModel>();

     try {
        // --- Assume VM returns Map on success, throws on error ---
        final result = await authViewModel.sendEmailOTP(widget.email!);

        if (!mounted) return;

         if (result['status'] == 'success') {
           _showSuccessSnackbar("New OTP sent to ${widget.email}.");
           _startResendTimer(); // Restart cooldown timer
         } else {
             // Handle error map returned by ViewModel
             _logger.w("Resend OTP failed (ViewModel returned error map): ${result['message']}");
             _showErrorSnackbar(result['message'] ?? "Failed to resend OTP.");
         }

     } catch (e) { // --- Catch exceptions thrown by ViewModel ---
         _logger.e("Error resending OTP", error: e);
         if (!mounted) return;
         _showErrorSnackbar(e is AppException ? e.message : "Failed to resend OTP. Please try again.");
     }
   }

    // --- Snackbar Helpers ---
    void _showErrorSnackbar(String message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating, // Consider floating for less intrusion
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Rounded corners
        ),
      );
    }

   void _showSuccessSnackbar(String message) {
     if (!mounted) return;
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text(message),
         backgroundColor: Colors.green,
         behavior: SnackBarBehavior.floating,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
       ),
     );
   }

  @override
  Widget build(BuildContext context) {
     // Use context.watch ONLY if the UI needs to react to isLoading changes
     // Otherwise, context.read inside button onPressed is sufficient.
     final authViewModel = context.watch<AuthViewModel>(); // Watching isLoading for overlay

    return Scaffold(
      appBar: const MamaCareAppBar(title: "Verify Email"),
      body: Stack( // Use stack for loading overlay
        children: [
          // Main Content
          SafeArea( // Ensure content avoids system UI
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      "Enter Verification Code",
                      style: TextStyles.headline2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Enter the 6-digit code sent to\n${widget.email ?? 'your email address'}",
                      style: TextStyles.bodyGrey,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // OTP Input Field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0), // Adjust padding
                      child: PinCodeTextField(
                        appContext: context,
                        length: 6,
                        obscureText: false,
                        animationType: AnimationType.fade,
                        pinTheme: PinTheme(
                          shape: PinCodeFieldShape.box,
                          borderRadius: BorderRadius.circular(10),
                          fieldHeight: 55, // Adjust size as needed
                          fieldWidth: 45, // Adjust size as needed
                          activeFillColor: Colors.white,
                          inactiveFillColor: AppColors.background.withOpacity(0.5), // Lighter inactive fill
                          selectedFillColor: Colors.white,
                          activeColor: AppColors.primary, // Border color when active
                          inactiveColor: Colors.grey.shade300, // Border color when inactive
                          selectedColor: AppColors.primaryLight, // Border color when selected (focused)
                           borderWidth: 1,
                        ),
                        animationDuration: const Duration(milliseconds: 300),
                        backgroundColor: Colors.transparent,
                        enableActiveFill: true,
                        errorAnimationController: _errorController,
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Ensure only digits
                        onCompleted: (v) {
                          _logger.d("OTP field completed");
                          // Only verify if not currently loading
                          if (!authViewModel.isLoading) {
                             _verifyOtp(); // Auto-verify on completion
                          }
                        },
                        onChanged: (value) {
                          // Can potentially clear error state on change
                          // if (authViewModel.error != null) { authViewModel.clearError(); }
                        },
                        beforeTextPaste: (text) {
                           _logger.d("Attempting to paste OTP: $text");
                           // Basic validation before pasting
                           return text != null && text.length == 6 && int.tryParse(text) != null;
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Verify Button
                    SizedBox( // Give button full width or defined width
                      width: double.infinity,
                      child: CustomButton(
                        label: "Verify Code",
                        // Disable button when loading
                        onPressed: authViewModel.isLoading ? null : _verifyOtp,
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Resend OTP Link/Button
                    Row(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                          Text("Didn't receive the code?", style: TextStyles.bodyGrey),
                          TextButton(
                            onPressed: (_canResend && !authViewModel.isLoading) ? _resendOtp : null, // Also disable if loading
                            child: Text(
                               _canResend ? "Resend OTP" : "Resend in $_resendCooldown s",
                               style: _canResend
                                  ? TextStyles.linkText // Use defined link style
                                  : TextStyles.bodyGrey.copyWith(fontSize: 13.sp), // Use grey when disabled
                            ),
                          ),
                       ],
                    ),
                     const SizedBox(height: 20), // Bottom padding
                  ],
                ),
            ),
          ),
          // Loading Overlay
          if (authViewModel.isLoading)
             const Opacity(
               opacity: 0.6, // Slightly less opaque
               child: ModalBarrier(dismissible: false, color: Colors.black),
             ),
           if (authViewModel.isLoading)
             const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      ),
    );
  }
}

// Make sure you have imported or defined:
// - locator (from injection.dart)
// - NavigationRoutes (from router.dart)
// - AuthViewModel (from auth_viewmodel.dart)
// - CustomButton (from widgets)
// - MamaCareAppBar (from widgets)
// - AppColors (from utils)
// - TextStyles (from utils)
// - AppException (from core/error/exceptions.dart)
// - Added pin_code_fields to pubspec.yaml