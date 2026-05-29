import 'page_transition.dart';
import 'package:flutter/material.dart';
import 'widgets/interactive_scale.dart';
import '../utils/responsive.dart';

import '../services/auth_service.dart';
import 'reset_password_otp_page.dart';
import 'widgets/particles_painter.dart'; // ← يحتوي على ParticlesLayer, ShimmerText, PulseContainer

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  late String _selectedLanguage;
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

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLang = Localizations.localeOf(context).languageCode;
    _selectedLanguage = currentLang == 'ar' ? 'arabic' : 'english';
  }

  bool get isArabic => _selectedLanguage == 'arabic';

  Future<void> _sendResetLink() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage =
          isArabic ? 'البريد الإلكتروني مطلوب' : 'Email is required');
      return;
    }

    if (!_emailController.text.contains('@') ||
        !_emailController.text.contains('.')) {
      setState(() => _errorMessage = isArabic
          ? 'الرجاء إدخال بريد إلكتروني صحيح'
          : 'Please enter a valid email');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response =
          await _authService.forgotPassword(_emailController.text.trim());

      if (response['success'] == true) {
        if (mounted) {
          await _showSuccessDialog();
        }
      } else {
        setState(() {
          _errorMessage = response['message'] ??
              (isArabic
                  ? 'فشل إرسال رابط إعادة التعيين'
                  : 'Failed to send reset link');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
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
                        isArabic ? 'تم الإرسال بنجاح!' : 'Successfully Sent!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isArabic
                            ? 'لقد أرسلنا رمز التحقق إلى:'
                            : 'We have sent a verification OTP to:',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _emailController.text.trim(),
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
                                child: ResetPasswordOtpPage(
                                  email: _emailController.text.trim(),
                                ),
                                type: PageTransitionType.slideFromRight,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            isArabic ? 'متابعة' : 'Continue',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      /// ===== Header =====
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: double.infinity,
                          height: 280,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF6366F1),
                                Color(0xFF8B5CF6)
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(40),
                              bottomRight: Radius.circular(40),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1)
                                    .withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // ✅ Particles layer (مثل Splash Screen)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: ParticlesLayer(count: 18),
                                ),
                              ),

                              /// Back button
                              Positioned(
                                top: 20,
                                left: 20,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: _isLoading
                                        ? null
                                        : () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withOpacity(0.2),
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
                              Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    // ✅ Pulse animation حول الأيقونة (مثل Splash Screen)
                                    PulseContainer(
                                      minScale: 0.92,
                                      maxScale: 1.08,
                                      child: TweenAnimationBuilder(
                                        tween: Tween<double>(
                                            begin: 0, end: 1),
                                        duration: const Duration(
                                            milliseconds: 600),
                                        builder: (context, double value,
                                            child) {
                                          return Transform.scale(
                                            scale: value,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.all(20),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.2),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.white
                                                        .withOpacity(0.15),
                                                    blurRadius: 24,
                                                    spreadRadius: 6,
                                                  ),
                                                  BoxShadow(
                                                    color: const Color(
                                                            0xFF8B5CF6)
                                                        .withOpacity(0.3),
                                                    blurRadius: 16,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.lock_reset_rounded,
                                                size: 64,
                                                color: Colors.white,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),

                                    const SizedBox(height: 24),

                                    // ✅ Shimmer text للعنوان (مثل Splash Screen)
                                    ShimmerText(
                                      text: isArabic
                                          ? 'إعادة تعيين كلمة المرور'
                                          : 'Reset Password',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),

                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32),
                                      child: Text(
                                        isArabic
                                            ? 'أدخل بريدك الإلكتروني لإعادة تعيين كلمة المرور'
                                            : 'Enter your email to reset password',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white
                                              .withOpacity(0.9),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      /// ===== Form =====
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Form(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 24),

                                  /// Error message with animation
                                  if (_errorMessage != null)
                                    TweenAnimationBuilder(
                                      tween: Tween<double>(begin: 0, end: 1),
                                      duration:
                                          const Duration(milliseconds: 300),
                                      builder:
                                          (context, double value, child) {
                                        return Transform.translate(
                                          offset:
                                              Offset(0, (1 - value) * -20),
                                          child: Opacity(
                                            opacity: value,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        16),
                                                border: Border.all(
                                                    color: Colors
                                                        .red.shade200),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                      Icons.error_outline,
                                                      color: Colors
                                                          .red.shade700),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      _errorMessage!,
                                                      style: TextStyle(
                                                          color: Colors
                                                              .red.shade700),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                  if (_errorMessage != null)
                                    const SizedBox(height: 20),

                                  /// Email Field
                                  _inputContainer(
                                    context,
                                    child: TextFormField(
                                      controller: _emailController,
                                      enabled: !_isLoading,
                                      keyboardType:
                                          TextInputType.emailAddress,
                                      style: theme.textTheme.bodyLarge,
                                      decoration: InputDecoration(
                                        labelText: isArabic
                                            ? 'البريد الإلكتروني'
                                            : 'Email Address',
                                        labelStyle: TextStyle(
                                          color: theme
                                              .textTheme.bodyMedium?.color
                                              ?.withOpacity(0.7),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.email_rounded,
                                          color: theme
                                              .textTheme.bodyMedium?.color
                                              ?.withOpacity(0.7),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.all(20),
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 32),

                                  /// Info box with animation
                                  TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration:
                                        const Duration(milliseconds: 600),
                                    builder:
                                        (context, double value, child) {
                                      return Transform.translate(
                                        offset: Offset(0, (1 - value) * 30),
                                        child: Opacity(
                                          opacity: value,
                                          child: Container(
                                            width: double.infinity,
                                            padding:
                                                const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  theme.colorScheme.primary
                                                      .withOpacity(0.1),
                                                  theme.colorScheme.primary
                                                      .withOpacity(0.05),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: theme
                                                    .colorScheme.primary
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons
                                                      .info_outline_rounded,
                                                  color: theme
                                                      .colorScheme.primary,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    isArabic
                                                        ? 'سوف نرسل رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني'
                                                        : 'We will send a verification OTP to your email address',
                                                    style: TextStyle(
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
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

                                  /// Reset Button with animation
                                  TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration:
                                        const Duration(milliseconds: 700),
                                    builder:
                                        (context, double value, child) {
                                      return Transform.translate(
                                        offset: Offset(0, (1 - value) * 40),
                                        child: Opacity(
                                          opacity: value,
                                          child: InteractiveScale(
                                            onTap: _isLoading ? null : _sendResetLink,
                                            child: SizedBox(
                                              width: double.infinity,
                                              height: 56,
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 300),
                                                decoration: BoxDecoration(
                                                  gradient: _isLoading
                                                      ? LinearGradient(
                                                          colors: [
                                                            Colors.grey
                                                                .shade400,
                                                            Colors.grey
                                                                .shade500
                                                          ],
                                                        )
                                                      : const LinearGradient(
                                                          begin: Alignment
                                                              .topLeft,
                                                          end: Alignment
                                                              .bottomRight,
                                                          colors: [
                                                            Color(0xFF6366F1),
                                                            Color(0xFF8B5CF6)
                                                          ],
                                                        ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20),
                                                  boxShadow: _isLoading
                                                      ? []
                                                      : [
                                                          BoxShadow(
                                                            color: const Color(
                                                                    0xFF6366F1)
                                                                .withOpacity(
                                                                    0.4),
                                                            blurRadius: 20,
                                                            offset:
                                                                const Offset(
                                                                    0, 8),
                                                          ),
                                                        ],
                                                ),
                                                child: Center(
                                                  child: _isLoading
                                                      ? const SizedBox(
                                                          width: 24,
                                                          height: 24,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2.5,
                                                            valueColor:
                                                                AlwaysStoppedAnimation(
                                                                    Colors
                                                                        .white),
                                                          ),
                                                        )
                                                      : Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .send_rounded,
                                                              color: Colors
                                                                  .white,
                                                              size: 20,
                                                            ),
                                                            const SizedBox(
                                                                width: 10),
                                                            Text(
                                                              isArabic
                                                                  ? 'إرسال رابط إعادة التعيين'
                                                                  : 'Send OTP',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .white,
                                                                letterSpacing:
                                                                    -0.3,
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

                                  /// Back to sign in link
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isArabic
                                            ? 'تذكرت كلمة المرور؟'
                                            : 'Remember your password?',
                                        style: TextStyle(
                                          color: theme
                                              .textTheme.bodyMedium?.color
                                              ?.withOpacity(0.7),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _isLoading
                                            ? null
                                            : () => Navigator.pop(context),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF6366F1),
                                        ),
                                        child: Text(
                                          isArabic
                                              ? 'تسجيل الدخول'
                                              : 'Sign In',
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

  Widget _inputContainer(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
                theme.brightness == Brightness.dark ? 0.5 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}