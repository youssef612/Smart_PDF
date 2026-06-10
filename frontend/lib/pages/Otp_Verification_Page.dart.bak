import 'page_transition.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../utils/responsive.dart';

import 'package:project_flutter/services/auth_service.dart';
import 'home_page.dart';
import 'sign_in_page.dart';

class OtpVerificationPage extends StatefulWidget {
  final String email;
  final String name;
  final String password;
  final String passwordConfirmation;
  final Uint8List? imageBytes;
  final String? imageName;

  const OtpVerificationPage({
    super.key,  // ✅ استخدام super parameter
    required this.email,
    required this.name,
    required this.password,
    required this.passwordConfirmation,
    this.imageBytes,
    this.imageName,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isResending = false;
  int _resendTimer = 60;
  bool _canResend = false;
  String? _errorMessage;
  late String _currentLanguage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
    _startResendTimer();
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentLanguage = Localizations.localeOf(context).languageCode;
  }

  bool get isArabic => _currentLanguage == 'ar';

  void _startResendTimer() {
    _canResend = false;
    _resendTimer = 60;
    Future.delayed(const Duration(seconds: 1), _updateTimer);
  }

  void _updateTimer() {
    if (mounted && _resendTimer > 0) {
      setState(() {
        _resendTimer--;
      });
      Future.delayed(const Duration(seconds: 1), _updateTimer);
    } else if (mounted) {
      setState(() {
        _canResend = true;
      });
    }
  }

  String get _otpCode {
    return _otpControllers.map((c) => c.text).join();
  }

  Future<void> _verifyOtp() async {
    if (_otpCode.length != 6) {
      setState(() {
        _errorMessage = isArabic ? 'الرجاء إدخال رمز التحقق كاملاً' : 'Please enter the complete verification code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First verify OTP
      final verifyResponse = await _authService.verifyOtp(
        email: widget.email,
        otp: _otpCode,
      );

      if (verifyResponse['success'] != true) {
        throw Exception(verifyResponse['message'] ?? (isArabic ? 'رمز التحقق غير صحيح' : 'Invalid verification code'));
      }

      // Then complete signup
      await _authService.signUp(
        name: widget.name,
        email: widget.email,
        password: widget.password,
        passwordConfirmation: widget.passwordConfirmation,
        imageBytes: widget.imageBytes,
        imageName: widget.imageName,
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
        _showErrorSnackBar(_errorMessage!);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final response = await _authService.resendOtp(email: widget.email);

      if (response['success'] == true) {
        _startResendTimer();
        if (mounted) {
          _showSuccessSnackBar(isArabic ? 'تم إعادة إرسال رمز التحقق' : 'Verification code resent');
        }
      } else {
        throw Exception(response['message'] ?? (isArabic ? 'فشل إعادة إرسال الرمز' : 'Failed to resend code'));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
        _showErrorSnackBar(_errorMessage!);
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF34D399)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isArabic ? 'تم التحقق بنجاح!' : 'Verification Successful!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isArabic
                            ? 'تم إنشاء حسابك بنجاح'
                            : 'Your account has been created successfully',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushReplacement(
                              context,
                              PageTransition(
                                child: const HomePage(),
                                type: PageTransitionType.slideFromRight,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            isArabic ? 'الذهاب إلى الرئيسية' : 'Go to Home',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      /// ===== Header =====
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(40),
                              bottomRight: Radius.circular(40),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.3), // ✅ استخدام withValues
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              /// Back button
                              Positioned(
                                top: 20,
                                left: 20,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: _isLoading ? null : () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2), // ✅ استخدام withValues
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.arrow_back_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              /// Center content
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 60),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TweenAnimationBuilder(
                                        tween: Tween<double>(begin: 0, end: 1),
                                        duration: const Duration(milliseconds: 600),
                                        builder: (context, double value, child) {
                                          return Transform.scale(
                                            scale: value,
                                            child: Container(
                                              padding: const EdgeInsets.all(20),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.2), // ✅ استخدام withValues
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.verified_rounded,
                                                size: 64,
                                                color: Colors.white,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        isArabic ? 'تحقق من بريدك الإلكتروني' : 'Verify Your Email',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 32),
                                        child: Text(
                                          isArabic
                                              ? 'لقد أرسلنا رمز التحقق إلى بريدك الإلكتروني'
                                              : 'We have sent a verification code to your email',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white.withValues(alpha: 0.9), // ✅ استخدام withValues
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2), // ✅ استخدام withValues
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          widget.email,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      /// ===== OTP Form =====
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 24),

                                /// Error message
                                if (_errorMessage != null)
                                  TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 300),
                                    builder: (context, double value, child) {
                                      return Transform.translate(
                                        offset: Offset(0, (1 - value) * -20),
                                        child: Opacity(
                                          opacity: value,
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.red.shade200),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.error_outline, color: Colors.red.shade700),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    _errorMessage!,
                                                    style: TextStyle(color: Colors.red.shade700),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                if (_errorMessage != null) const SizedBox(height: 20),

                                /// OTP Input Fields
                                _buildOtpInput(theme),

                                const SizedBox(height: 32),

                                /// Info text
                                TweenAnimationBuilder(
                                  tween: Tween<double>(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 600),
                                  builder: (context, double value, child) {
                                    return Transform.translate(
                                      offset: Offset(0, (1 - value) * 30),
                                      child: Opacity(
                                        opacity: value,
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                theme.colorScheme.primary.withValues(alpha: 0.1), // ✅ استخدام withValues
                                                theme.colorScheme.primary.withValues(alpha: 0.05), // ✅ استخدام withValues
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: theme.colorScheme.primary.withValues(alpha: 0.3), // ✅ استخدام withValues
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.info_outline_rounded,
                                                color: theme.colorScheme.primary,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  isArabic
                                                      ? 'الرجاء إدخال الرمز المكون من 6 أرقام المرسل إلى بريدك الإلكتروني'
                                                      : 'Please enter the 6-digit code sent to your email',
                                                  style: TextStyle(
                                                    color: theme.colorScheme.primary,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 32),

                                /// Verify Button
                                TweenAnimationBuilder(
                                  tween: Tween<double>(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 700),
                                  builder: (context, double value, child) {
                                    return Transform.translate(
                                      offset: Offset(0, (1 - value) * 40),
                                      child: Opacity(
                                        opacity: value,
                                        child: SizedBox(
                                          width: double.infinity,
                                          height: 56,
                                          child: GestureDetector(
                                            onTap: _isLoading ? null : _verifyOtp,
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 300),
                                              decoration: BoxDecoration(
                                                gradient: _isLoading
                                                    ? LinearGradient(
                                                      colors: [Colors.grey.shade400, Colors.grey.shade500],
                                                    )
                                                    : const LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                                    ),
                                                borderRadius: BorderRadius.circular(20),
                                                boxShadow: _isLoading
                                                    ? []
                                                    : [
                                                        BoxShadow(
                                                          color: const Color(0xFF6366F1).withValues(alpha: 0.4), // ✅ استخدام withValues
                                                          blurRadius: 20,
                                                          offset: const Offset(0, 8),
                                                        ),
                                                      ],
                                              ),
                                              child: Center(
                                                child: _isLoading
                                                    ? const SizedBox(
                                                        width: 24,
                                                        height: 24,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2.5,
                                                          valueColor: AlwaysStoppedAnimation(Colors.white),
                                                        ),
                                                      )
                                                    : Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          const Icon(
                                                            Icons.verified_rounded,
                                                            color: Colors.white,
                                                            size: 20,
                                                          ),
                                                          const SizedBox(width: 10),
                                                          Text(
                                                            isArabic ? 'تحقق' : 'Verify',
                                                            style: const TextStyle(
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.white,
                                                              letterSpacing: -0.3,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 24),

                                /// Resend Section
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isArabic ? 'لم تصلك رسالة؟' : "Didn't receive code?",
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), // ✅ استخدام withValues
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_canResend)
                                      TextButton(
                                        onPressed: _isResending ? null : _resendOtp,
                                        style: TextButton.styleFrom(
                                          foregroundColor: const Color(0xFF6366F1),
                                        ),
                                        child: _isResending
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
                                                ),
                                              )
                                            : Text(
                                                isArabic ? 'إعادة إرسال' : 'Resend',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.timer_rounded,
                                              size: 14,
                                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '00:$_resendTimer',
                                              style: TextStyle(
                                                color: isDark ? Colors.grey[500] : Colors.grey[600],
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                /// Back to sign in
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isArabic ? 'تريد تسجيل الدخول؟' : 'Want to sign in?',
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), // ✅ استخدام withValues
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _isLoading ? null : () {
                                        Navigator.pushReplacement(
                                          context,
                                          PageTransition(
                                            child: const SignInPage(),
                                            type: PageTransitionType.slideFromRight,
                                          ),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF6366F1),
                                      ),
                                      child: Text(
                                        isArabic ? 'تسجيل الدخول' : 'Sign In',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOtpInput(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (index) {
          return Container(
            width: 50,
            height: 60,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05), // ✅ استخدام withValues
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: _otpControllers[index].text.isNotEmpty
                    ? const Color(0xFF6366F1)
                    : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
                width: 2,
              ),
            ),
            child: TextFormField(
              controller: _otpControllers[index],
              focusNode: _otpFocusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              enabled: !_isLoading,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                if (value.isNotEmpty && index < 5) {
                  FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
                } else if (value.isEmpty && index > 0) {
                  FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
                }
                
                // Auto-verify when all fields are filled
                if (index == 5 && value.isNotEmpty && _otpCode.length == 6) {
                  _verifyOtp();
                }
              },
            ),
          );
        }),
      ),
    );
  }
}

