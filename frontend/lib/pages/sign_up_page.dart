import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../l10n/app_localizations.dart';
import 'Otp_Verification_Page.dart';  // ✅ أضف هذا الـ import
import 'sign_in_page.dart';
import 'page_transition.dart';  // ✅ أضف هذا

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Image handling with bytes
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  late String _currentLanguage;

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
    _nameController.dispose();
    _emailController.dispose();
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

  Future<void> _pickImage() async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (pickedImage != null) {
        final bytes = await pickedImage.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = pickedImage.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        _showErrorSnackBar(isArabic ? 'فشل اختيار الصورة' : 'Failed to pick image');
      }
    }
  }

  // ✅ احتفظ بهذه الدالة للاستخدام المستقبلي (مثلاً لو نجح التسجيل مباشرة)
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

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First, send OTP to email
      final otpResponse = await _authService.sendOtp(
        email: _emailController.text.trim(),
      );

      if (otpResponse['success'] == true) {
        if (mounted) {
          // Navigate to OTP verification page
          Navigator.push(
            context,
            PageTransition(
              child: OtpVerificationPage(
                email: _emailController.text.trim(),
                name: _nameController.text.trim(),
                password: _passwordController.text,
                passwordConfirmation: _confirmPasswordController.text,
                imageBytes: _selectedImageBytes,
                imageName: _selectedImageName,
              ),
              type: PageTransitionType.slideFromRight,
            ),
          );
        }
      } else {
        throw Exception(otpResponse['message'] ?? (isArabic ? 'فشل إرسال رمز التحقق' : 'Failed to send verification code'));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
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
                                  color: const Color(0xFF6366F1).withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    /// Back button
                                    Align(
                                      alignment: Alignment.topLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 20, top: 8),
                                        child: GestureDetector(
                                          onTap: () => Navigator.pop(context),
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

                                    const SizedBox(height: 16),

                                    /// Profile Image with picker
                                    GestureDetector(
                                      onTap: _pickImage,
                                      child: TweenAnimationBuilder(
                                        tween: Tween<double>(begin: 0, end: 1),
                                        duration: const Duration(milliseconds: 600),
                                        builder: (context, double value, child) {
                                          return Transform.scale(
                                            scale: value,
                                            child: Stack(
                                              children: [
                                                Container(
                                                  width: 100,
                                                  height: 100,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.white.withOpacity(0.2),
                                                        Colors.white.withOpacity(0.1),
                                                      ],
                                                    ),
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 3,
                                                    ),
                                                    image: _selectedImageBytes != null
                                                        ? DecorationImage(
                                                      image: MemoryImage(_selectedImageBytes!),
                                                      fit: BoxFit.cover,
                                                    )
                                                        : null,
                                                  ),
                                                  child: _selectedImageBytes == null
                                                      ? const Icon(
                                                    Icons.person_add_rounded,
                                                    size: 50,
                                                    color: Colors.white,
                                                  )
                                                      : null,
                                                ),
                                                Positioned(
                                                  bottom: 0,
                                                  right: 0,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: const BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.camera_alt,
                                                      size: 18,
                                                      color: const Color(0xFF6366F1),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      isArabic ? 'اضغط لإضافة صورة' : 'Tap to add photo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      localizations.createAccount,
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
                                        localizations.signUpToStart,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
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
                                  const SizedBox(height: 8),

                                  /// Error Message with animation
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

                                  /// Full Name
                                  _inputContainer(
                                    theme,
                                    child: TextFormField(
                                      controller: _nameController,
                                      enabled: !_isLoading,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return isArabic ? 'الاسم مطلوب' : 'Name is required';
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        labelText: localizations.fullName,
                                        prefixIcon: Icon(
                                          Icons.person_rounded,
                                          color: theme.primaryColor,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(20),
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  /// Email
                                  _inputContainer(
                                    theme,
                                    child: TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      enabled: !_isLoading,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return isArabic ? 'البريد الإلكتروني مطلوب' : 'Email is required';
                                        }
                                        if (!value.contains('@') || !value.contains('.')) {
                                          return isArabic ? 'أدخل بريداً إلكترونياً صحيحاً' : 'Enter a valid email';
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        labelText: localizations.emailAddress,
                                        prefixIcon: Icon(
                                          Icons.email_rounded,
                                          color: theme.primaryColor,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(20),
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  /// Password
                                  _inputContainer(
                                    theme,
                                    child: TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      enabled: !_isLoading,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return isArabic ? 'كلمة المرور مطلوبة' : 'Password is required';
                                        }
                                        if (value.length < 8) {
                                          return isArabic ? 'كلمة المرور يجب أن تكون 8 أحرف على الأقل' : 'Password must be at least 8 characters';
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        labelText: localizations.password,
                                        prefixIcon: Icon(
                                          Icons.lock_rounded,
                                          color: theme.primaryColor,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: theme.primaryColor,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword = !_obscurePassword;
                                            });
                                          },
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(20),
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  /// Confirm Password
                                  _inputContainer(
                                    theme,
                                    child: TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: _obscureConfirmPassword,
                                      enabled: !_isLoading,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return isArabic ? 'الرجاء تأكيد كلمة المرور' : 'Please confirm your password';
                                        }
                                        if (value != _passwordController.text) {
                                          return isArabic ? 'كلمة المرور غير متطابقة' : 'Passwords do not match';
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        labelText: isArabic ? 'تأكيد كلمة المرور' : 'Confirm Password',
                                        prefixIcon: Icon(
                                          Icons.lock_rounded,
                                          color: theme.primaryColor,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: theme.primaryColor,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscureConfirmPassword = !_obscureConfirmPassword;
                                            });
                                          },
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(20),
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 28),

                                  /// Sign Up Button
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
                                              onTap: _isLoading ? null : _signUp,
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
                                                        Icons.person_add_rounded,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Text(
                                                        localizations.createAccount,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 16,
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

                                  const SizedBox(height: 20),

                                  /// Already have account
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          localizations.alreadyHaveAccount,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _isLoading ? null : () {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const SignInPage(),
                                              ),
                                            );
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(0xFF6366F1),
                                          ),
                                          child: Text(
                                            localizations.signIn,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// ===== Input Container =====
  Widget _inputContainer(ThemeData theme, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

// Custom Page Transition
