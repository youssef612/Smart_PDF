import 'page_transition.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:project_flutter/services/auth_service.dart';
import 'package:project_flutter/services/files_service.dart';
import 'explanation_page.dart';
import 'mindmap_page.dart';
import 'summary_page.dart';
import 'splash_screen.dart';
import 'questions_page.dart';
import 'personal_page.dart';
import 'settings_page.dart';
import 'sign_in_page.dart';
import 'history_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FilesService _filesService = FilesService();

  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String? _selectedFileName;
  String? _selectedFileId;
  int     _selectedPageCount = 0;
  bool _isFileProcessing = false;
  bool _isUploading = false; // ← NEW: tracks upload-in-progress

  late String _selectedLanguage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserData();

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
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLang = Localizations.localeOf(context).languageCode;
    _selectedLanguage = currentLang == 'ar' ? 'arabic' : 'english';
  }

  bool get isArabic => _selectedLanguage == 'arabic';

  List<Feature> get _features {
    return [
      Feature(
        title: isArabic ? 'تلخيص ذكي' : 'Smart Summary',
        description: isArabic
            ? 'احصل على ملخص دقيق لمستنداتك'
            : 'Get accurate summaries of your documents',
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFF6366F1),
        route: '/summary',
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
      ),
      Feature(
        title: isArabic ? 'شرح ذكي' : 'Smart Explanation',
        description: isArabic
            ? 'شرح بالعامية المصرية بأسلوب بسيط'
            : 'Explained in simple Egyptian Arabic',
        icon: Icons.lightbulb_rounded,
        color: const Color(0xFF10B981),
        route: '/explanation',
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF34D399)],
        ),
      ),
      Feature(
        title: isArabic ? 'أسئلة تفاعلية' : 'Smart Questions',
        description: isArabic
            ? 'توليد أسئلة ذكية من المحتوى'
            : 'Generate intelligent questions from content',
        icon: Icons.quiz_rounded,
        color: const Color(0xFFF59E0B),
        route: '/questions',
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        ),
      ),
    ];
  }

  ImageProvider? _getUserAvatar() {
    if (_user == null) return null;

    if (_user!['avatarBytes'] != null) {
      try {
        Uint8List bytes = base64Decode(_user!['avatarBytes']);
        return MemoryImage(bytes);
      } catch (e) {
        debugPrint('Error decoding avatar: $e');
      }
    }

    if (_user!['avatar'] != null && _user!['avatar'].toString().isNotEmpty) {
      return NetworkImage(_user!['avatar']);
    }

    return null;
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    final localUser = await _authService.getCurrentUserFromStorage();

    if (localUser != null) {
      setState(() {
        _user = localUser;
        _isLoading = false;
      });

      _refreshUserData();
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageTransition(
              child: const SignInPage(), type: PageTransitionType.fade),
        );
      }
    }
  }

  Future<void> _refreshUserData() async {
    try {
      final response = await _authService.getCurrentUser();
      if (response['success'] == true && mounted) {
        final freshUser = await _authService.getCurrentUserFromStorage();
        if (freshUser != null && mounted) {
          setState(() {
            _user = freshUser;
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing user: $e');
    }
  }

  void _navigateToPersonalPage() async {
    final result = await Navigator.push(
      context,
      PageTransition(
        child: PersonalPage(user: _user),
        type: PageTransitionType.slideFromRight,
      ),
    );

    if (result != null && result is Map && result['updated'] == true) {
      final updatedUserData = result['userData'];
      if (updatedUserData != null) {
        setState(() {
          _user = updatedUserData;
        });

        if (_user!['avatarBytes'] != null) {
          try {
            final bytes = base64Decode(_user!['avatarBytes']);
            await _authService.updateAvatarLocally(bytes);
          } catch (e) {
            debugPrint('Error updating avatar locally: $e');
          }
        }
      } else {
        final freshUser = await _authService.getCurrentUserFromStorage();
        if (freshUser != null && mounted) {
          setState(() {
            _user = freshUser;
          });
        }
      }
    } else {
      final freshUser = await _authService.getCurrentUserFromStorage();
      if (freshUser != null && mounted) {
        setState(() {
          _user = freshUser;
        });
      }
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getColorFromName(String? name) {
    if (name == null || name.isEmpty) return const Color(0xFF6366F1);
    final hash = name.hashCode.abs();
    final hue = hash % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.7, 0.5).toColor();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _buildAnimatedDialog(
        context,
        title: isArabic ? 'تسجيل الخروج' : 'Logout',
        content: isArabic
            ? 'هل أنت متأكد من تسجيل الخروج؟'
            : 'Are you sure you want to logout?',
        confirmText: isArabic ? 'تسجيل الخروج' : 'Logout',
        isDestructive: true,
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageTransition(
              child: const SplashScreen(), type: PageTransitionType.fade),
        );
      }
    }
  }

  Future<void> _pickPDF() async {
    // Prevent double-tap while uploading
    if (_isUploading) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null) return;

      final pickedFile = result.files.single;
      final bytes = pickedFile.bytes;
      final fileName = pickedFile.name;

      if (bytes == null) return;

      // ── show loading on the button ──────────────────────────────────────
      setState(() => _isUploading = true);

      final uploadedFile = await _filesService.uploadFileBytes(
        bytes,
        fileName: fileName,
        type: 'PDF',
      );

      if (uploadedFile != null) {
        setState(() {
          _selectedFileName = fileName;
          _selectedFileId = uploadedFile['id']?.toString();
          _selectedPageCount = (uploadedFile['page_count'] ?? 0) as int;
          _isFileProcessing = uploadedFile['has_text'] == false;
          _isUploading = false;
        });

        if (mounted) {
          _showSuccessSnackBar(
            '$fileName ${isArabic ? 'تم رفعه بنجاح' : 'uploaded successfully'}',
          );
        }
      } else {
        setState(() => _isUploading = false);
        if (mounted) {
          _showErrorSnackBar(
              isArabic ? 'فشل رفع الملف' : 'Failed to upload file');
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  void _changePDF() {
    setState(() {
      _selectedFileName = null;
      _isFileProcessing = false;
    });
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

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
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
      ),
    );
  }

  Widget _buildAnimatedDialog(
      BuildContext context, {
        required String title,
        required String content,
        required String confirmText,
        bool isDestructive = false,
      }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ScaleTransition(
        scale: CurvedAnimation(
            parent: _animationController, curve: Curves.easeOutBack),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDestructive ? Colors.red : Colors.green)
                      .withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDestructive
                      ? Icons.warning_rounded
                      : Icons.check_circle_rounded,
                  color: isDestructive ? Colors.red : Colors.green,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDestructive
                            ? Colors.red
                            : Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(confirmText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarImage = _getUserAvatar();

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            builder: (context, double value, child) {
              return Opacity(
                opacity: value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isArabic ? 'جاري التحميل...' : 'Loading...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme, avatarImage),
      drawer: AppDrawer(
        user: _user,
        onLogout: _logout,
        selectedLanguage: _selectedLanguage,
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: _buildHeaderSection(theme),
            ),
            SlideTransition(
              position: _slideAnimation,
              child: _buildUploadSection(theme),
            ),
            const SizedBox(height: 8),
            _buildFeaturesSection(theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, ImageProvider? avatarImage) {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'SP',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isArabic ? 'سمارت بي دي إف' : 'SmartPDF',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      backgroundColor: theme.cardColor,
      foregroundColor: theme.textTheme.bodyLarge?.color,
      elevation: 0,
      actions: [
        Hero(
          tag: 'profile_avatar',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _navigateToPersonalPage,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: avatarImage,
                  backgroundColor:
                  _getColorFromName(_user?['name']).withOpacity(0.2),
                  child: avatarImage == null
                      ? Text(
                    _getInitials(_user?['name']),
                    style: TextStyle(
                      color: _getColorFromName(_user?['name']),
                      fontWeight: FontWeight.bold,
                    ),
                  )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSection(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'مرحباً بعودتك،' : 'Welcome back,',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _user?['name'] ?? (isArabic ? 'مستخدم' : 'User'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 32,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.email_rounded,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  _user?['email'] ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        children: [
          if (_selectedFileName == null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: _buildUploadButton(theme),
            )
          else
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: _buildSelectedFile(theme),
            ),
        ],
      ),
    );
  }

  // ── Upload button — shows spinner while _isUploading is true ────────────
  Widget _buildUploadButton(ThemeData theme) {
    return MouseRegion(
      cursor: _isUploading
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _isUploading ? null : _pickPDF,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              // slightly desaturate while uploading
              colors: _isUploading
                  ? [const Color(0xFF8B8FD4), const Color(0xFFA78BCA)]
                  : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(
                    _isUploading ? 0.15 : 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // decorative circles
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // content — switches between normal and loading states
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isUploading
                      ? _buildUploadingState()   // ← loading UI
                      : _buildIdleUploadState(), // ← normal UI
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Normal (idle) state of the upload button
  Widget _buildIdleUploadState() {
    return Column(
      key: const ValueKey('idle'),
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
                  Icons.cloud_upload_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          isArabic ? 'رفع ملف PDF' : 'Upload PDF',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isArabic ? 'اسحب الملف أو انقر للاختيار' : 'Drag or click to select',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// Loading state shown while the file is being uploaded
  Widget _buildUploadingState() {
    return Column(
      key: const ValueKey('uploading'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isArabic ? 'جاري رفع الملف...' : 'Uploading...',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isArabic ? 'برجاء الانتظار' : 'Please wait',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedFile(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.1),
            const Color(0xFF10B981).withOpacity(0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF10B981), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFileName!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (_isFileProcessing
                        ? Colors.orange
                        : const Color(0xFF10B981))
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isFileProcessing)
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                            AlwaysStoppedAnimation(Colors.orange),
                          ),
                        )
                      else
                        const Icon(Icons.check_circle,
                            size: 12, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text(
                        _isFileProcessing
                            ? (isArabic
                            ? 'جاري معالجة الملف...'
                            : 'Processing...')
                            : (isArabic
                            ? 'جاهز للمعالجة'
                            : 'Ready to process'),
                        style: TextStyle(
                          color: _isFileProcessing
                              ? Colors.orange
                              : const Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _changePDF,
            icon: Icon(Icons.close_rounded,
                color: theme.iconTheme.color?.withOpacity(0.6)),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.withOpacity(0.1),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(ThemeData theme) {
    List<Widget> featureWidgets = [];
    for (int i = 0; i < _features.length; i++) {
      featureWidgets.add(_buildFeatureItem(context, theme, _features[i], i));
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? ' الخدمات الذكية' : ' Smart Services',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isArabic ? 'مدعوم بالذكاء الاصطناعي' : 'AI Powered',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...featureWidgets,
        ],
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, ThemeData theme,
      Feature feature, int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          if (_selectedFileName == null) {
            _showErrorSnackBar(isArabic
                ? 'الرجاء رفع ملف PDF أولاً'
                : 'Please upload a PDF first');
            return;
          }

          Widget page;
          if (feature.route == '/explanation') {
            page = ExplanationPage(
                fileName: _selectedFileName, fileId: _selectedFileId);
          } else if (feature.route == '/summary') {
            page = SummaryPage(
                fileName: _selectedFileName, fileId: _selectedFileId);
          } else if (feature.route == '/mindmap') {
            page = MindMapPage(
                fileName: _selectedFileName, fileId: _selectedFileId);
          } else {
            page = QuestionsPage(
                fileName: _selectedFileName, fileId: _selectedFileId, pageCount: _selectedPageCount);
          }

          Navigator.push(
            context,
            PageTransition(
              child: page,
              type: PageTransitionType.slideFromRight,
              duration: const Duration(milliseconds: 400),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                feature.color.withOpacity(0.1),
                feature.color.withOpacity(0.05)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: feature.color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: feature.gradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: feature.color.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child:
                    Icon(feature.icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          feature.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: feature.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: feature.color,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Feature {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String route;
  final LinearGradient gradient;

  Feature({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.route,
    required this.gradient,
  });
}

class AppDrawer extends StatelessWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onLogout;
  final String selectedLanguage;

  const AppDrawer({
    Key? key,
    required this.user,
    required this.onLogout,
    required this.selectedLanguage,
  }) : super(key: key);

  bool get isArabic => selectedLanguage == 'arabic';

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getColorFromName(String? name) {
    if (name == null || name.isEmpty) return const Color(0xFF6366F1);
    final hash = name.hashCode.abs();
    final hue = hash % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.7, 0.5).toColor();
  }

  ImageProvider? _getUserAvatar() {
    if (user == null) return null;

    if (user!['avatarBytes'] != null) {
      try {
        Uint8List bytes = base64Decode(user!['avatarBytes']);
        return MemoryImage(bytes);
      } catch (e) {
        return null;
      }
    }

    if (user!['avatar'] != null && user!['avatar'].toString().isNotEmpty) {
      return NetworkImage(user!['avatar']);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarImage = _getUserAvatar();

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'profile_avatar_drawer',
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: avatarImage,
                        backgroundColor: Colors.white,
                        child: avatarImage == null
                            ? Text(
                          _getInitials(user?['name']),
                          style: TextStyle(
                            color: _getColorFromName(user?['name']),
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?['name'] ?? (isArabic ? 'مستخدم' : 'User'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?['email'] ?? '',
                      style:
                      const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  Icons.home_rounded,
                  isArabic ? 'الرئيسية' : 'Home',
                      () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  context,
                  Icons.folder_rounded,
                  isArabic ? 'مستنداتي' : 'My Documents',
                      () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      PageTransition(
                        child: HistoryPage(),
                        type: PageTransitionType.slideFromRight,
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  Icons.settings_rounded,
                  isArabic ? 'الإعدادات' : 'Settings',
                      () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      PageTransition(
                        child: const SettingsPage(),
                        type: PageTransitionType.slideFromRight,
                      ),
                    ).then((_) async {
                      final authService = AuthService();
                      await authService.getCurrentUser();
                    });
                  },
                ),
                const Divider(),
                _buildDrawerItem(
                  context,
                  Icons.logout_rounded,
                  isArabic ? 'تسجيل الخروج' : 'Logout',
                      () {
                    Navigator.pop(context);
                    onLogout();
                  },
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
      BuildContext context,
      IconData icon,
      String title,
      VoidCallback onTap, {
        Color? color,
      }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? Theme.of(context).primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            color: color ?? Theme.of(context).primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}