import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/presentation/viewmodel/auth_viewmodel.dart';
import 'package:mama_care/presentation/widgets/custom_button.dart';
import 'package:mama_care/presentation/widgets/custom_text_field.dart';
import 'package:mama_care/presentation/widgets/google_auth_button.dart';
import 'package:mama_care/navigation/router.dart';
import 'package:mama_care/data/local/database_helper.dart';

class SignUpView extends StatefulWidget {
  const SignUpView({Key? key}) : super(key: key);

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _profileImageUrlController = TextEditingController();
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(30.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image(image: AssetImage('assets/images/logo.png')),
                SizedBox(height: 20),
                Text(
                  "Enter your Name",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.pinkAccent,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: 10),
                CustomTextField(
                  controller: _nameController,
                  hint: "Enter Name",
                  suffixIcon: Icon(Icons.person_outline_rounded, color: Colors.pinkAccent),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                Text(
                  "Enter your Email",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.pinkAccent,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: 10),
                CustomTextField(
                  controller: _emailController,
                  hint: "Enter Email",
                  suffixIcon: Icon(Icons.email_outlined, color: Colors.pinkAccent),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter your email';
                    }
                    if (!value!.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                Text(
                  "Enter your Password",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.pinkAccent,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: 10),
                CustomTextField(
                  controller: _passwordController,
                  hint: "Enter Password",
                  obscureText: _obscureText,
                  suffixIcon: GestureDetector(
                    onTap: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                    child: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      color: Colors.pinkAccent,
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter your password';
                    }
                    if (value!.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                Text(
                  "Enter your Phone Number",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.pinkAccent,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: 10),
                CustomTextField(
                  controller: _phoneNumberController,
                  hint: "Enter Phone Number",
                  suffixIcon: Icon(Icons.phone_outlined, color: Colors.pinkAccent),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                Text(
                  "Enter your Profile Image URL",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.pinkAccent,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: 10),
                CustomTextField(
                  controller: _profileImageUrlController,
                  hint: "Enter Profile Image URL",
                  suffixIcon: Icon(Icons.image_outlined, color: Colors.pinkAccent),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter your profile image URL';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 30),
                CustomButton(
                  label: "Sign Up",
                  onPressed: () async {
                    if (_formKey.currentState?.validate() == true) {
                      final dbHelper = DatabaseHelper();

                      // Store user data in SQLite
                      await dbHelper.insertUser({
                        'email': _emailController.text,
                        'name': _nameController.text,
                        'phoneNumber': _phoneNumberController.text,
                        'profileImageUrl': _profileImageUrlController.text,
                      });

                      // Send OTP for email verification
                      await authViewModel.sendEmailOTP(_emailController.text);

                      // Navigate to OTP verification screen
                      Navigator.pushReplacementNamed(context, NavigationRoutes.otpVerification);
                    }
                  },
                  color: Colors.pinkAccent,
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: TextStyle(color: Colors.grey),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacementNamed(context, NavigationRoutes.login);
                      },
                      child: Text(
                        "Login",
                        style: TextStyle(color: Colors.pinkAccent),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  "OR",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 20),
                GoogleAuthButton(
                  label: "Sign up with Google",
                  onPressed: () async {
                    await authViewModel.googleLogin();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}