import 'page_transition.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/responsive.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import 'sign_in_page.dart';
import 'home_page.dart';
import 'sign_up_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late String _currentLanguage;

  late AnimationController _mainController;
  late AnimationController _particlesController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _rotateAnimation;

  // Staggered button animations
  late Animation<double> _btn1Fade;
  late Animation<Offset> _btn1Slide;
  late Animation<double> _btn2Fade;
  late Animation<Offset> _btn2Slide;

  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // Generate particles
    for (int i = 0; i < 18; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 8 + 4,
        speed: _random.nextDouble() * 0.3 + 0.1,
        opacity: _random.nextDouble() * 0.4 + 0.1,
      ));
    }

    // Main controller — logo + header
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _rotateAnimation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Staggered buttons
    _btn1Fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
      ),
    );
    _btn1Slide =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _btn2Fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.68, 1.0, curve: Curves.easeOut),
      ),
    );
    _btn2Slide =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.68, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Particles controller — infinite loop
    _particlesController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();

    // Pulse controller — logo glow
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Shimmer controller
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _mainController.forward();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 4));

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (!mounted) return;

    if (token != null) {
      final apiService = ApiService();
      final newToken = await apiService.refreshToken(token);

      if (!mounted) return;

      if (newToken != null) {
        Navigator.pushReplacement(
          context,
          PageTransition(child: const HomePage(), type: PageTransitionType.fade),
        );
      } else {
        Navigator.pushReplacement(
          context,
          PageTransition(child: const SignInPage(), type: PageTransitionType.fade),
        );
      }
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particlesController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentLanguage = Localizations.localeOf(context).languageCode;
  }

  bool get isArabic => _currentLanguage == 'ar';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header with particles ──
                      Expanded(
                        flex: 3,
                        child: FadeTransition(
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
                                bottomLeft: Radius.circular(60),
                                bottomRight: Radius.circular(60),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(0.35),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: SafeArea(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Particles layer
                                  AnimatedBuilder(
                                    animation: _particlesController,
                                    builder: (context, _) {
                                      return CustomPaint(
                                        painter: _ParticlesPainter(
                                          particles: _particles,
                                          progress: _particlesController.value,
                                        ),
                                        size: Size(size.width, constraints.maxHeight * 0.6),
                                      );
                                    },
                                  ),

                                  // Logo + text
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Logo with pulse + scale
                                      AnimatedBuilder(
                                        animation: Listenable.merge([_scaleAnimation, _pulseAnimation, _rotateAnimation]),
                                        builder: (context, _) {
                                          return Transform.rotate(
                                            angle: _rotateAnimation.value,
                                            child: Transform.scale(
                                              scale: _scaleAnimation.value,
                                              child: AnimatedBuilder(
                                                animation: _pulseAnimation,
                                                builder: (context, child) {
                                                  return Container(
                                                    padding: const EdgeInsets.all(28),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.2),
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.white.withOpacity(0.15 * _pulseAnimation.value),
                                                          blurRadius: 30 * _pulseAnimation.value,
                                                          spreadRadius: 8 * _pulseAnimation.value,
                                                        ),
                                                        BoxShadow(
                                                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                                          blurRadius: 20,
                                                          spreadRadius: 2,
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Icon(
                                                      Icons.description_rounded,
                                                      size: 80,
                                                      color: Colors.white,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                      const SizedBox(height: 32),

                                      // Shimmer title
                                      AnimatedBuilder(
                                        animation: _shimmerAnimation,
                                        builder: (context, _) {
                                          return ShaderMask(
                                            shaderCallback: (bounds) {
                                              return LinearGradient(
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                                colors: const [
                                                  Colors.white,
                                                  Color(0xFFE0E7FF),
                                                  Colors.white,
                                                  Colors.white,
                                                ],
                                                stops: [
                                                  0.0,
                                                  (_shimmerAnimation.value + 2) / 4,
                                                  (_shimmerAnimation.value + 2.3) / 4,
                                                  1.0,
                                                ],
                                              ).createShader(bounds);
                                            },
                                            child: const Text(
                                              'SmartPDF',
                                              style: TextStyle(
                                                fontSize: 52,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: -1.5,
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                      const SizedBox(height: 16),

                                      // Subtitle badge
                                      ScaleTransition(
                                        scale: _scaleAnimation,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(30),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            loc.appSubtitle,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Buttons ──
                      Expanded(
                        flex: 2,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Sign In Button
                                    FadeTransition(
                                      opacity: _btn1Fade,
                                      child: SlideTransition(
                                        position: _btn1Slide,
                                        child: SizedBox(
                                          width: double.infinity,
                                          height: 54,
                                          child: GestureDetector(
                                            onTap: () {
                                              Navigator.pushReplacement(
                                                context,
                                                PageTransition(
                                                  child: const SignInPage(),
                                                  type: PageTransitionType.slideFromRight,
                                                ),
                                              );
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                                ),
                                                borderRadius: BorderRadius.circular(20),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFF6366F1).withOpacity(0.4),
                                                    blurRadius: 20,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.login_rounded, color: Colors.white, size: 22),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      loc.signIn,
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
                                    ),

                                    const SizedBox(height: 14),

                                    // New Account Button
                                    FadeTransition(
                                      opacity: _btn2Fade,
                                      child: SlideTransition(
                                        position: _btn2Slide,
                                        child: SizedBox(
                                          width: double.infinity,
                                          height: 54,
                                          child: GestureDetector(
                                            onTap: () {
                                              Navigator.pushReplacement(
                                                context,
                                                PageTransition(
                                                  child: const SignUpPage(),
                                                  type: PageTransitionType.slideFromRight,
                                                ),
                                              );
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: const Color(0xFF6366F1).withOpacity(0.5),
                                                  width: 2,
                                                ),
                                              ),
                                              child: Center(
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.person_add_rounded, color: Color(0xFF6366F1), size: 22),
                                                    const SizedBox(width: 10),
                                                    const Text(
                                                      'NEW ACCOUNT',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF6366F1),
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
                                    ),
                                  ],
                                ),
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
}

// ── Particle model ──
class _Particle {
  final double x;
  double y;
  final double size;
  final double speed;
  final double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

// ── Particles painter ──
class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlesPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (p.y + progress * p.speed) % 1.0;
      final paint = Paint()
        ..color = Colors.white.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(p.x * size.width, y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) => old.progress != progress;
}