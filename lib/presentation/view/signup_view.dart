// lib/presentation/view/signup_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mama_care/presentation/screen/doctor_dashboard_screen.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/presentation/viewmodel/auth_viewmodel.dart';
import 'package:mama_care/presentation/viewmodel/signup_viewmodel.dart';
import 'package:mama_care/presentation/widgets/custom_button.dart';
import 'package:mama_care/presentation/widgets/custom_text_field.dart';
import 'package:mama_care/presentation/widgets/google_auth_button.dart';
import 'package:mama_care/navigation/router.dart';
import 'package:mama_care/utils/app_colors.dart';
import 'package:mama_care/utils/text_styles.dart';
import 'package:mama_care/domain/entities/user_role.dart';
import 'package:logger/logger.dart';
import 'package:mama_care/injection.dart';
import 'package:mama_care/presentation/widgets/mama_care_app_bar.dart';

// Screen Wrapper to provide ViewModel specifically for the SignUp screen
class SignUpScreenWrapper extends StatelessWidget {
  const SignUpScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create:
          (_) =>
              locator<
                SignupViewModel
              >(), // Create/provide SignupViewModel via locator
      child: const SignUpView(), // The actual view content
    );
  }
}

// The main SignUp View widget
class SignUpView extends StatefulWidget {
  const SignUpView({super.key});

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  UserRole _selectedRole = UserRole.patient; // Default role selection
  final Logger _logger = locator<Logger>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SignupViewModel>(
      builder: (context, SignupViewModel, child) {
        final authViewModel = context.watch<AuthViewModel>();
        final bool isOverallLoading =
            SignupViewModel.isSigningUp || authViewModel.isLoading;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: const MamaCareAppBar(
            title: "Create Account",
            automaticallyImplyLeading: true,
          ),
          body: GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Stack(
              children: [
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 20.0,
                      ),
                      child: _buildSignupForm(
                        context,
                        SignupViewModel,
                        authViewModel,
                        isOverallLoading,
                      ),
                    ),
                  ),
                ),
                if (isOverallLoading)
                  const Opacity(
                    opacity: 0.7,
                    child: ModalBarrier(
                      color: Colors.black,
                      dismissible: false,
                    ),
                  ),
                if (isOverallLoading)
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Main Signup Form Structure
  Widget _buildSignupForm(
    BuildContext context,
    SignupViewModel signupViewModel,
    AuthViewModel authViewModel,
    bool isLoading,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create Your Account',
            style: TextStyles.headline1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your details below',
            style: TextStyles.bodyGrey,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildNameField(context),
                const SizedBox(height: 16),
                _buildEmailField(context),
                const SizedBox(height: 16),
                _buildPasswordField(context),
                const SizedBox(height: 16),
                _buildConfirmPasswordField(context),
                const SizedBox(height: 16),
                _buildPhoneField(context),
                const SizedBox(height: 16),
                _buildRoleSelection(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSignUpButton(signupViewModel, isLoading),
                const SizedBox(height: 16),
                _buildLoginLink(context),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: Divider(endIndent: 10)),
                    Text("OR", style: TextStyles.bodyGrey),
                    const Expanded(child: Divider(indent: 10)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGoogleSignUpButton(authViewModel, isLoading),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- Field Builder Methods ---
  Widget _buildFormField({
    required BuildContext context,
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyles.textFieldLabel),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildNameField(BuildContext context) {
    return _buildFormField(
      context: context,
      label: "Full Name",
      child: CustomTextField(
        controller: _nameController,
        hint: "Enter your full name",
        prefixIcon: const Icon(
          Icons.person_outline_rounded,
          color: AppColors.primaryLight,
        ),
        validator:
            (value) =>
                (value?.trim().isEmpty ?? true) ? 'Name cannot be empty' : null,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget _buildEmailField(BuildContext context) {
    return _buildFormField(
      context: context,
      label: "Email Address",
      child: CustomTextField(
        controller: _emailController,
        hint: "Enter your email",
        prefixIcon: const Icon(
          Icons.email_outlined,
          color: AppColors.primaryLight,
        ),
        validator: _validateEmail,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email, AutofillHints.username],
      ),
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    return _buildFormField(
      context: context,
      label: "Password",
      child: CustomTextField(
        controller: _passwordController,
        hint: "Enter password (min 8 chars)",
        obscureText: _obscurePassword,
        validator: _validatePassword,
        prefixIcon: const Icon(
          Icons.lock_outline,
          color: AppColors.primaryLight,
        ),
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.next,
        suffixIcon: InkWell(
          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
          child: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.primaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmPasswordField(BuildContext context) {
    return _buildFormField(
      context: context,
      label: "Confirm Password",
      child: CustomTextField(
        controller: _confirmPasswordController,
        hint: "Re-enter your password",
        obscureText: _obscureConfirmPassword,
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please confirm password';
          if (value != _passwordController.text) {
            return 'Passwords do not match';
          }
          return null;
        },
        prefixIcon: const Icon(
          Icons.lock_person_outlined,
          color: AppColors.primaryLight,
        ),
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.next,
        suffixIcon: InkWell(
          onTap:
              () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
          child: Icon(
            _obscureConfirmPassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.primaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField(BuildContext context) {
    return _buildFormField(
      context: context,
      label: "Phone Number (Optional)",
      child: CustomTextField(
        controller: _phoneNumberController,
        hint: "Enter your phone number",
        prefixIcon: const Icon(
          Icons.phone_outlined,
          color: AppColors.primaryLight,
        ),
        validator: _validatePhoneNumber,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.telephoneNumber],
      ),
    );
  }

  Widget _buildRoleSelection() {
    return _buildFormField(
      context: context,
      label: "Register As",
      child: DropdownButtonFormField<UserRole>(
        value: _selectedRole,
        items:
            UserRole.values
                .where(
                  (role) =>
                      role == UserRole.patient ||
                      role == UserRole.nurse ||
                      role == UserRole.doctor,
                )
                .map(
                  (role) => DropdownMenuItem<UserRole>(
                    value: role,
                    child: Text(role.name.capitalize()),
                  ),
                )
                .toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedRole = value;
            });
          }
        },
        decoration: InputDecoration(
          prefixIcon: Icon(
            _getRoleIcon(_selectedRole),
            color: AppColors.primaryLight,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        validator: (value) => value == null ? 'Please select a role' : null,
        isExpanded: true,
      ),
    );
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return Icons.personal_injury_outlined;
      case UserRole.nurse:
        return Icons.medical_services_outlined;
      case UserRole.doctor:
        return Icons.health_and_safety_outlined;
      default:
        return Icons.person_outline;
    }
  }

  // --- Button/Link Builders ---
  Widget _buildSignUpButton(SignupViewModel signupViewModel, bool isLoading) {
    return CustomButton(
      label: "Create Account",
      onPressed: isLoading ? null : () => _handleSignUp(signupViewModel),
      backgroundColor: AppColors.primary,
      textStyle: TextStyles.buttonText,
    );
  }

  Widget _buildLoginLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Already have an account?", style: TextStyles.bodyGrey),
        TextButton(
          onPressed:
              () => Navigator.pushReplacementNamed(
                context,
                NavigationRoutes.login,
              ),
          child: Text("Login", style: TextStyles.linkText),
        ),
      ],
    );
  }

  Widget _buildGoogleSignUpButton(AuthViewModel authViewModel, bool isLoading) {
    return GoogleAuthButton(
      label: "Continue with Google",
      onPressed: isLoading ? null : () => _handleGoogleSignUp(authViewModel),
      isLoading: isLoading,
    );
  } // Show Google loading only if AuthVM is loading for Google

  // --- Validation Logic ---
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter email';
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter password';
    if (value.length < 8) return 'Password must be at least 8 characters';
    final hasLetter = value.contains(RegExp(r'[a-zA-Z]'));
    final hasNumber = value.contains(RegExp(r'[0-9]'));
    if (!hasLetter || !hasNumber) return 'Password needs letters and numbers';
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return null;
  } // Keep phone optional

  // --- Action Handlers ---
  Future<void> _handleSignUp(SignupViewModel signupViewModel) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final authViewModel =
        context.read<AuthViewModel>(); // Needed for navigation check later

    bool didInitiate = await signupViewModel.signup(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      name: _nameController.text.trim(),
      phoneNumber:
          _phoneNumberController.text.trim().isEmpty
              ? null
              : _phoneNumberController.text.trim(),
      profileImageUrl: null, // Implement image picker for this
      initialRole: _selectedRole,
    );

    if (!mounted) return;

    if (didInitiate) {
      _logger.i(
        "Signup initiated. Navigating to OTP verification for ${_emailController.text.trim()}",
      );
      _showSuccessSnackbar(
        "Account creation requested. Please check your email to verify.",
      );
      Navigator.pushReplacementNamed(
        context,
        NavigationRoutes.otpVerification,
        arguments: _emailController.text.trim(),
      );
    } else {
      _showErrorSnackbar(signupViewModel.signupError ?? 'Signup failed.');
    }
  }

  Future<void> _handleGoogleSignUp(AuthViewModel authViewModel) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await authViewModel.signInWithGoogle();
    if (!mounted) return;
    if (result['status'] == 'success') {
      _showSuccessSnackbar("Signed in with Google successfully!");
      _navigateToDashboardBasedOnRole(result['role'] as String?, authViewModel);
    } else if (result['status'] != 'cancelled') {
      _showErrorSnackbar(result['message'] ?? 'Google sign-up failed.');
    }
  }

  // --- Navigation & Feedback ---
  void _navigateToDashboardBasedOnRole(
    String? roleString,
    AuthViewModel authViewModel,
  ) {
    final role = userRoleFromString(roleString);
    String targetRoute;
    switch (role) {
      case UserRole.patient:
        targetRoute = NavigationRoutes.mainScreen;
        break;
      case UserRole.nurse:
        targetRoute = NavigationRoutes.nurseDashboard;
        break;
      case UserRole.doctor:
        targetRoute = NavigationRoutes.doctorDashboard;
        break;
      case UserRole.admin:
        targetRoute = NavigationRoutes.adminDashboard;
        break;
      case UserRole.unknown:
      default:
        _logger.e("Unknown role after sign-up/sign-in: $role");
        _showErrorSnackbar(
          "Signup successful, but couldn't determine dashboard access.",
        );
        targetRoute = NavigationRoutes.mainScreen;
        break;
    }
    _logger.i("Navigating to $targetRoute based on role $role");
    Navigator.pushNamedAndRemoveUntil(context, targetRoute, (route) => false);
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// Helper Widget (Copied from LoginView Implementation)
class _FormFieldHelper extends StatelessWidget {
  // Renamed to avoid conflict if helper is global
  final String label;
  final Widget child;
  const _FormFieldHelper({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyles.textFieldLabel),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
