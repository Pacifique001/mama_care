import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:mama_care/domain/entities/user_model.dart';
import 'package:mama_care/presentation/viewmodel/auth_viewmodel.dart';
import 'package:mama_care/presentation/widgets/custom_button.dart';
import 'package:mama_care/presentation/widgets/custom_text_field.dart';
import 'package:mama_care/presentation/widgets/google_auth_button.dart';

import '../../navigation/router.dart';

class LoginView extends StatefulWidget {
  const LoginView({Key? key}) : super(key: key);

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final loginViewModel = Provider.of<AuthViewModel>(context);
    // final navigationService = GetIt.I<NavigationService>();
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Stack(
              children: [
                if (loginViewModel.isLoading)
                  const Center(child: CircularProgressIndicator()),
                Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Image(image: AssetImage('assets/images/logo.png')),
                      const SizedBox(height: 20),
                      Text(
                        "Email",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.pinkAccent,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 10),
                      CustomTextField(
                        controller: _emailController,
                        hint: "Enter Email",
                        onChanged: (value) => {},
                        suffixIcon: const Icon(Icons.email_outlined, color: Colors.pinkAccent),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        "Password",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.pinkAccent,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 10),
                      CustomTextField(
                        controller: _passwordController,
                        hint: "Enter Password",
                        obscureText: _obscureText,
                        onChanged: (value) => {},
                        suffixIcon: GestureDetector(
                          onTap: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                          child: Icon(
                            _obscureText ? Icons.visibility : Icons.visibility_off,
                            color: Colors.pinkAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      CustomButton(
                        label: "Login",
                        onPressed: () async {
                          if (_formKey.currentState?.validate() == true) {
                            await loginViewModel.login(
                              _emailController.text,
                              _passwordController.text,
                            );
                            Navigator.pushReplacementNamed(
                              context,
                              NavigationRoutes.mainScreen,
                            );
                          }
                        },
                        color: Colors.pinkAccent,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account?",
                            style: TextStyle(color: Colors.grey),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(
                                context,
                                NavigationRoutes.signup,
                              );
                            },
                            child: const Text(
                              "Sign Up",
                              style: TextStyle(color: Colors.pinkAccent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "OR",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      GoogleAuthButton(
                        label: "Sign in with Google",
                        onPressed: () async {
                          await loginViewModel.googleLogin();
                          Navigator.pushReplacementNamed(
                            context,
                            NavigationRoutes.mainScreen,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
