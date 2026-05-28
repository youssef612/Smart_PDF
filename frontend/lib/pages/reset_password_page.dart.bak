import 'page_transition.dart';
import 'package:flutter/material.dart';
import '../utils/responsive.dart';

import 'package:project_flutter/services/auth_service.dart';
import 'sign_in_page.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String otp;

  const ResetPasswordPage({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentLanguage = Localizations.localeOf(context).languageCode;
  }

  bool get isArabic => _currentLanguage == 'ar';

  Future<void> _resetPassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty) {
      setState(() => _errorMessage = isArabic ? 'كلمة المرور مطلوبة' : 'Password is required');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = isArabic ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : 'Password must be at least 6 characters');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = isArabic ? 'كلمة المرور غير متطابقة' : 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authService.resetPasswordWithOtp(
        email: widget.email,
        otp: widget.otp,
        password: password,
        passwordConfirmation: confirmPassword,
      );

      if (response['success'] == true) {
        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        setState(() {
          _errorMessage = response['message'] ?? (isArabic ? 'فشل إعادة تعيين كلمة المرور' : 'Failed to reset password');
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
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Theme.of(context).cardColor,
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
                        isArabic ? 'تم إعادة تعيين كلمة المرور!' : 'Password Reset Successfully!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isArabic
                            ? 'يمكنك الآن تسجيل الدخول باستخدام كلمة المرور الجديدة'
                            : 'You can now sign in with your new password',
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
                                child: const SignInPage(),
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
                            isArabic ? 'تسجيل الدخول' : 'Sign In',
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
                          height: 280,
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
                                color: const Color(0xFF6366F1).withOpacity(0.3),
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
                                        color: Colors.white.withOpacity(0.2),
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
                                              color: Colors.white.withOpacity(0.2),
                                              shape: BoxShape.circle,
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
                                    const SizedBox(height: 24),
                                    Text(
                                      isArabic ? 'إنشاء كلمة مرور جديدة' : 'Create New Password',
                                      style: const TextStyle(
                                        fontSize: 32,
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
                                            ? 'أدخل كلمة المرور الجديدة لحسابك'
                                            : 'Enter your new password',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white.withOpacity(0.9),
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 24),
                                /// Error message with animation
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
                                              color: isDark 
                                                  ? Colors.red.shade900.withOpacity(0.3)
                                                  : Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: isDark 
                                                    ? Colors.red.shade700
                                                    : Colors.red.shade200,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.error_outline, 
                                                  color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    _errorMessage!,
                                                    style: TextStyle(
                                                      color: isDark ? Colors.red.shade300 : Colors.red.shade700,
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
                                if (_errorMessage != null) const SizedBox(height: 20),
                                /// New Password Field
                                _buildInputField(
                                  context,
                                  controller: _passwordController,
                                  label: isArabic ? 'كلمة المرور الجديدة' : 'New Password',
                                  hint: isArabic ? 'أدخل كلمة المرور الجديدة' : 'Enter new password',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                const SizedBox(height: 20),
                                /// Confirm Password Field
                                _buildInputField(
                                  context,
                                  controller: _confirmPasswordController,
                                  label: isArabic ? 'تأكيد كلمة المرور' : 'Confirm Password',
                                  hint: isArabic ? 'أعد إدخال كلمة المرور الجديدة' : 'Re-enter new password',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscureConfirmPassword,
                                  onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                                const SizedBox(height: 32),
                                /// Info box with password requirements
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
                                                theme.colorScheme.primary.withOpacity(0.1),
                                                theme.colorScheme.primary.withOpacity(0.05),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: theme.colorScheme.primary.withOpacity(0.3),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.info_outline_rounded,
                                                    color: theme.colorScheme.primary,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      isArabic
                                                          ? 'متطلبات كلمة المرور:'
                                                          : 'Password Requirements:',
                                                      style: TextStyle(
                                                        color: theme.colorScheme.primary,
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              _buildRequirementRow(
                                                context,
                                                text: isArabic ? '6 أحرف على الأقل' : 'At least 6 characters',
                                                isMet: _passwordController.text.length >= 6,
                                              ),
                                              const SizedBox(height: 4),
                                              _buildRequirementRow(
                                                context,
                                                text: isArabic ? 'كلمة المرور وتأكيدها متطابقان' : 'Password and confirmation match',
                                                isMet: _passwordController.text.isNotEmpty && 
                                                       _passwordController.text == _confirmPasswordController.text,
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
                                            onTap: _isLoading ? null : _resetPassword,
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 300),
                                              decoration: BoxDecoration(
                                                gradient: _isLoading
                                                    ? LinearGradient(
                                                        colors: isDark
                                                            ? [Colors.grey.shade700, Colors.grey.shade800]
                                                            : [Colors.grey.shade400, Colors.grey.shade500],
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
                                                          color: const Color(0xFF6366F1).withOpacity(0.4),
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
                                                            Icons.save_rounded,
                                                            color: Colors.white,
                                                            size: 20,
                                                          ),
                                                          const SizedBox(width: 10),
                                                          Text(
                                                            isArabic ? 'إعادة تعيين كلمة المرور' : 'Reset Password',
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
                                /// Back to sign in link
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isArabic ? 'تذكرت كلمة المرور؟' : 'Remember your password?',
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _isLoading ? null : () => Navigator.pop(context),
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

  Widget _buildInputField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        enabled: !_isLoading,
        obscureText: obscureText,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
          ),
          labelStyle: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
          prefixIcon: Icon(
            icon, 
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildRequirementRow(BuildContext context, {
    required String text,
    required bool isMet,
  }) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: isMet ? const Color(0xFF10B981) : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isMet ? const Color(0xFF10B981) : Colors.grey,
            decoration: isMet ? TextDecoration.lineThrough : null,
            decorationColor: const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }
}

