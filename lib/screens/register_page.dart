import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final AppLanguageService _language = AppLanguageService.instance;

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  String _t(String key, String fallback) {
    final translated = _language.translate(key);
    return translated == key ? fallback : translated;
  }

  @override
  void initState() {
    super.initState();
    _language.load();
  }

  Future<void> registerUser() async {
    if (isLoading) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text,
          );

      if (!mounted) return;

      if (credential.user != null) {
        showMessage(
          _t(
            'account_created_successfully',
            'Account created successfully! 🌱',
          ),
        );
      }

      // The authentication wrapper in main.dart handles navigation
      // after the account has been created successfully.
    } on FirebaseAuthException catch (e) {
      final String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = _t(
            'email_already_registered',
            'An account already exists with this email.',
          );
          break;
        case 'invalid-email':
          message = _t('invalid_email', 'Please enter a valid email address.');
          break;
        case 'weak-password':
          message = _t('weak_password', 'Please choose a stronger password.');
          break;
        case 'operation-not-allowed':
          message = _t(
            'email_registration_disabled',
            'Email and password registration is not enabled.',
          );
          break;
        case 'network-request-failed':
          message = _t(
            'network_error',
            'Network error. Check your internet connection.',
          );
          break;
        case 'too-many-requests':
          message = _t(
            'too_many_attempts',
            'Too many attempts. Please try again later.',
          );
          break;
        default:
          message = _t(
            'account_creation_failed',
            'Could not create account. Please try again.',
          );
      }

      showMessage(message);
    } catch (error, stackTrace) {
      debugPrint('Registration error: $error');
      debugPrintStack(stackTrace: stackTrace);

      showMessage(
        _t('something_went_wrong', 'Something went wrong. Please try again.'),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return _t('please_enter_email', 'Please enter your email.');
    }

    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailPattern.hasMatch(email)) {
      return _t('invalid_email', 'Please enter a valid email address.');
    }

    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return _t('please_enter_password', 'Please enter a password.');
    }

    if (value.length < 6) {
      return _t(
        'password_minimum_length',
        'Password must be at least 6 characters.',
      );
    }

    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return _t('please_confirm_password', 'Please confirm your password.');
    }

    if (value != passwordController.text) {
      return _t('passwords_do_not_match', 'Passwords do not match.');
    }

    return null;
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  InputDecoration fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.green.shade100),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.green.shade700, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _language,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF6FAF5),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(_t('create_account', 'Create Account')),
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          Center(
                            child: Container(
                              height: 80,
                              width: 80,
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  '🌱',
                                  style: TextStyle(fontSize: 42),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _t('start_your_garden', 'Start Your Garden'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF204D2B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _t(
                              'create_account_description',
                              'Create an account to manage your plants.',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 35),
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            enabled: !isLoading,
                            validator: validateEmail,
                            decoration: fieldDecoration(
                              label: _t('email', 'Email'),
                              hint: _t('enter_your_email', 'Enter your email'),
                              icon: Icons.email_outlined,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            enabled: !isLoading,
                            validator: validatePassword,
                            onChanged: (_) {
                              if (confirmPasswordController.text.isNotEmpty) {
                                _formKey.currentState?.validate();
                              }
                            },
                            decoration: fieldDecoration(
                              label: _t('password', 'Password'),
                              hint: _t(
                                'password_minimum_hint',
                                'Minimum 6 characters',
                              ),
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                tooltip: obscurePassword
                                    ? _t('show_password', 'Show password')
                                    : _t('hide_password', 'Hide password'),
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          obscurePassword = !obscurePassword;
                                        });
                                      },
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: confirmPasswordController,
                            obscureText: obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            enabled: !isLoading,
                            validator: validateConfirmPassword,
                            onFieldSubmitted: (_) {
                              if (!isLoading) registerUser();
                            },
                            decoration: fieldDecoration(
                              label: _t('confirm_password', 'Confirm Password'),
                              hint: _t(
                                'reenter_password',
                                'Re-enter your password',
                              ),
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                tooltip: obscureConfirmPassword
                                    ? _t('show_password', 'Show password')
                                    : _t('hide_password', 'Hide password'),
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          obscureConfirmPassword =
                                              !obscureConfirmPassword;
                                        });
                                      },
                                icon: Icon(
                                  obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : registerUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.green.shade300,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _t('create_account', 'Create Account'),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            _t(
                              'create_account_footer',
                              'By creating an account, you can start building your own smart garden.',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
