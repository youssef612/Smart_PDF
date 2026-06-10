import 'page_transition.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'widgets/interactive_scale.dart';

import 'package:flutter/services.dart';
import '../utils/responsive.dart';

import 'package:project_flutter/services/api_service.dart';
import 'package:project_flutter/services/auth_service.dart';
import 'package:project_flutter/services/files_service.dart';
import 'explanation_page.dart';
import 'mindmap_page.dart';
import 'package:project_flutter/pages/summary_page.dart';
import 'splash_screen.dart';
import 'questions_page.dart';
import 'personal_page.dart';
import 'settings_page.dart';
import 'sign_in_page.dart';
import 'history_page.dart';
import 'widgets/particles_painter.dart';
import 'chat_page.dart';
import '../main.dart';

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
  int _selectedPageCount = 0;
  bool _isFileProcessing = false;
  bool _isDragging = false;
  bool _isUploading = false;

  late String _selectedLanguage;

  late AnimationController _animationController;
  final FocusNode _focusNode = FocusNode();
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
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _focusNode.dispose();
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
            child: const SignInPage(),
            type: PageTransitionType.fade,
          ),
        );
      }
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
            child: const SplashScreen(),
            type: PageTransitionType.fade,
          ),
        );
      }
    }
  }

  Future<void> _pickPDF() async {
    if (_isUploading) return;
    await showDialog(
      context: context,
      builder: (context) => FilePickerDialog(
        filesService: _filesService,
        isArabic: isArabic,
        currentFileId: _selectedFileId,
        onFileSelected: (fileId, fileName, pageCount) {
          setState(() {
            _selectedFileId = fileId;
            _selectedFileName = fileName;
            _selectedPageCount = pageCount;
            _isFileProcessing = false;
          });
        },
        onFileUploaded: (fileId, fileName, pageCount, isProcessing) {
          // تحديث الواجهة فقط في حالة اختيار الفتح الفوري
          setState(() {
            _selectedFileId = fileId;
            _selectedFileName = fileName;
            _selectedPageCount = pageCount;
            _isFileProcessing = isProcessing;
            _isUploading = false;
          });
          _showSuccessSnackBar(
            '$fileName ${isArabic ? 'تم رفعه وفتحه بنجاح' : 'uploaded and opened successfully'}',
          );
        },
        onUploadStart: () => setState(() => _isUploading = true),
        onError: (msg) {
          setState(() => _isUploading = false);

          // التحقق مما إذا كانت الرسالة القادمة هي نجاح الحفظ فقط وليست خطأ حقيقي
          if (msg.startsWith('__JUST_SAVED_SUCCESS__')) {
            final fileName = msg.split(':')[1];
            _showSuccessSnackBar(
              '$fileName ${isArabic ? 'تم حفظه في مستنداتك بنجاح' : 'saved to your documents successfully'}',
            );
          } else {
            _showErrorSnackBar(msg);
          }
        },
      ),
    );
  }

  void _changePDF() {
    setState(() {
      _selectedFileName = null;
      _selectedFileId = null;
      _selectedPageCount = 0;
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
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 20,
            ),
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
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

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): _pickPDF,
        const SingleActivator(LogicalKeyboardKey.keyH, control: true): () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => HistoryPage()),
          );
        },
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (_selectedFileName == null) {
            _showErrorSnackBar(
              isArabic
                  ? 'الرجاء رفع ملف PDF أولاً'
                  : 'Please upload a PDF first',
            );
            return;
          }
          Navigator.push(
            context,
            PageTransition(
              child: SummaryPage(
                fileName: _selectedFileName,
                fileId: _selectedFileId,
                pageCount: _selectedPageCount,
                filesService:
                    _filesService, // ← مرر الـ service هنا برضه أثناء التنقل
              ),
              type: PageTransitionType.slideFromRight,
            ),
          );
        },
        const SingleActivator(LogicalKeyboardKey.keyQ, control: true): () {
          if (_selectedFileName == null) {
            _showErrorSnackBar(
              isArabic
                  ? 'الرجاء رفع ملف PDF أولاً'
                  : 'Please upload a PDF first',
            );
            return;
          }
          Navigator.push(
            context,
            PageTransition(
              child: QuestionsPage(
                fileName: _selectedFileName,
                fileId: _selectedFileId,
                pageCount: _selectedPageCount,
                filesService: _filesService,
              ),
              type: PageTransitionType.slideFromRight,
            ),
          );
        },
        const SingleActivator(LogicalKeyboardKey.keyE, control: true): () {
          if (_selectedFileName == null) {
            _showErrorSnackBar(
              isArabic
                  ? 'الرجاء رفع ملف PDF أولاً'
                  : 'Please upload a PDF first',
            );
            return;
          }
          Navigator.push(
            context,
            PageTransition(
              child: ExplanationPage(
                fileName: _selectedFileName,
                fileId: _selectedFileId,
                pageCount: _selectedPageCount,
                filesService: _filesService,
              ),
              type: PageTransitionType.slideFromRight,
            ),
          );
        },
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          Navigator.push(
            context,
            PageTransition(
              child: const PersonalPage(),
              type: PageTransitionType.slideFromRight,
            ),
          );
        },
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: _buildAppBar(theme, avatarImage),
          drawer: AppDrawer(
            user: _user,
            onLogout: _logout,
            selectedFileId: _selectedFileId,
            selectedFileName: _selectedFileName,
            selectedLanguage: _selectedLanguage,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.maxWidth(context),
              ),
              child: SingleChildScrollView(
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
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    ThemeData theme,
    ImageProvider? avatarImage,
  ) {
    final isDarkMode = theme.brightness == Brightness.dark;
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
        Tooltip(
          message: isDarkMode
              ? (isArabic ? 'تفعيل الوضع الفاتح' : 'Switch to Light Mode')
              : (isArabic ? 'تفعيل الوضع الداكن' : 'Switch to Dark Mode'),
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => MyApp.of(
              context,
            ).changeTheme(isDarkMode ? ThemeMode.light : ThemeMode.dark),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.amber.withOpacity(0.1)
                    : const Color(0xFF6366F1).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return RotationTransition(
                    turns: Tween<double>(
                      begin: 0.75,
                      end: 1.0,
                    ).animate(animation),
                    child: ScaleTransition(scale: animation, child: child),
                  );
                },
                child: Icon(
                  isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                  key: ValueKey<bool>(isDarkMode),
                  color: isDarkMode ? Colors.amber : const Color(0xFF6366F1),
                  size: 22,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Hero(
          tag: 'profile_avatar',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _navigateToPersonalPage,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                margin: const EdgeInsets.only(right: 16, left: 16),
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: avatarImage,
                  backgroundColor: _getColorFromName(
                    _user?['name'],
                  ).withOpacity(0.2),
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
              fontSize: Responsive.fontSize(context, 32),
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

  Widget _buildUploadButton(ThemeData theme) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        if (_isUploading) return;

        setState(() => _isDragging = false);
        final files = details.files
            .where((f) => f.path.toLowerCase().endsWith('.pdf'))
            .toList();
        if (files.isEmpty) {
          _showErrorSnackBar(
            isArabic ? 'يرجى إسقاط ملف PDF فقط' : 'Please drop a PDF file only',
          );
          return;
        }

        final file = files.first;
        final bytes = await file.readAsBytes();
        final fileName = file.name;

        setState(() => _isUploading = true);

        final uploadedFile = await _filesService.uploadFileBytes(
          bytes,
          fileName: fileName,
          type: 'PDF',
        );

        if (uploadedFile != null) {
          if (!mounted) return;
          // سؤال المستخدم فورياً باستخدام الـ context الثابت والمستقر للـ HomePage
          final bool? shouldOpen = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogCtx) => _buildUploadActionPrompt(
              dialogCtx,
            ), // نمرر الـ dialogCtx الجديد
          );

          setState(() => _isUploading = false);

          if (shouldOpen == true) {
            setState(() {
              _selectedFileName = fileName;
              _selectedFileId = uploadedFile['id']?.toString();
              _selectedPageCount = (uploadedFile['page_count'] ?? 0) as int;
              _isFileProcessing = uploadedFile['has_text'] == false;
            });
            _showSuccessSnackBar(
              '$fileName ${isArabic ? 'تم رفعه وفتحه بنجاح' : 'uploaded and opened successfully'}',
            );
          } else {
            _showSuccessSnackBar(
              '$fileName ${isArabic ? 'تم حفظه في مستنداتك بنجاح' : 'saved to your documents successfully'}',
            );
            // هنا لا نغير قيم الـ _selectedFileName والـ _selectedFileId فبالتالي يظل الملف القديم كما هو!
          }
        } else {
          setState(() => _isUploading = false);
          if (mounted)
            _showErrorSnackBar(
              isArabic ? 'فشل رفع الملف' : 'Failed to upload file',
            );
        }
      },
      child: MouseRegion(
        cursor: _isUploading
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: InteractiveScale(
          onTap: _isUploading ? null : _pickPDF,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              gradient: _isUploading
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8B8FD4), Color(0xFFA78BCA)],
                    )
                  : _isDragging
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF6366F1,
                  ).withOpacity(_isUploading ? 0.15 : 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
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
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: const ParticlesLayer(count: 18),
                    ),
                  ),
                ),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isUploading
                        ? _buildUploadingState()
                        : _buildIdleUploadState(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
        ),
      ],
    );
  }

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
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSelectedFile(ThemeData theme) {
    // تحسين احترافي: كرت المستند المختار أصبح قابلاً للضغط لإعادة فتحه وتعديله بلمسة واحدة
    return GestureDetector(
      onTap: _pickPDF,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF10B981).withOpacity(0.12),
                const Color(0xFF10B981).withOpacity(0.06),
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
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: 24,
                ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (_isFileProcessing
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
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.orange,
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.check_circle,
                              size: 12,
                              color: Color(0xFF10B981),
                            ),
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
              // أيقونة الحذف تظل منفصلة لمنع التداخل
              IconButton(
                onPressed: () {
                  _changePDF();
                },
                icon: Icon(
                  Icons.close_rounded,
                  color: theme.iconTheme.color?.withOpacity(0.6),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.withOpacity(0.1),
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // نافذة الخيارات المودرن بعد عملية الرفع الناجحة لرفع مستوى الاحترافية والتحكم للمستخدم
  Widget _buildUploadActionPrompt(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_done_rounded,
                color: Color(0xFF6366F1),
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isArabic ? 'تم الرفع بنجاح!' : 'Uploaded Successfully!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'ماذا تود أن تفعل بهذا الملف الآن؟'
                  : 'What would you like to do with this file now?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      false,
                    ), // الرفع فقط دون التحديد النشط
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF6366F1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isArabic ? 'رفع وحفظ فقط' : 'Just Save It'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, true), // الرفع والفتح فوراً
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isArabic ? 'رفع وفتح فوراً' : 'Open & Process'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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

  Widget _buildFeatureItem(
    BuildContext context,
    ThemeData theme,
    Feature feature,
    int index,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          if (feature.route == '/chat') {
            if (index == 2) {
              if (_selectedFileId == null) {
                _showErrorSnackBar(
                  isArabic
                      ? 'الرجاء رفع ملف PDF أولاً'
                      : 'Please upload a PDF first',
                );
                return;
              }
              Navigator.push(
                context,
                PageTransition(
                  child: ChatPage(
                    fileId: _selectedFileId!,
                    fileName: _selectedFileName,
                  ),
                  type: PageTransitionType.slideFromRight,
                  duration: const Duration(milliseconds: 400),
                ),
              );
            } else {
              Navigator.push(
                context,
                PageTransition(
                  child: const ChatPage(fileId: ''),
                  type: PageTransitionType.slideFromRight,
                  duration: const Duration(milliseconds: 400),
                ),
              );
            }
            return;
          }
          if (_selectedFileName == null) {
            _showErrorSnackBar(
              isArabic
                  ? 'الرجاء رفع ملف PDF أولاً'
                  : 'Please upload a PDF first',
            );
            return;
          }
          Widget page;
          if (feature.route == '/explanation') {
            page = ExplanationPage(
              fileName: _selectedFileName,
              fileId: _selectedFileId,
              pageCount: _selectedPageCount,
              filesService: _filesService,
            );
          } else if (feature.route == '/summary') {
            page = SummaryPage(
              fileName: _selectedFileName,
              fileId: _selectedFileId,
              pageCount: _selectedPageCount,
              filesService: _filesService, // ← أضف هذا السطر هنا برضه
            );
          } else if (feature.route == '/mindmap') {
            page = MindMapPage(
              fileName: _selectedFileName,
              fileId: _selectedFileId,
            );
          } else if (feature.route == '/chat') {
            page = ChatPage(
              fileName: _selectedFileName!,
              fileId: _selectedFileId!,
            );
          } else {
            page = QuestionsPage(
              fileName: _selectedFileName,
              fileId: _selectedFileId,
              pageCount: _selectedPageCount,
              filesService: _filesService,
            );
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
                feature.color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: feature.color.withOpacity(0.2), width: 1),
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
                    child: Icon(feature.icon, color: Colors.white, size: 28),
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

// ─── تعديل وتطوير الـ FilePickerDialog لدعم تمييز الملف النشط بالكامل وعرض نافذة التأكيد الاختيارية بعد الرفع ───
class FilePickerDialog extends StatefulWidget {
  final FilesService filesService;
  final bool isArabic;
  final String?
  currentFileId; // الـ ID الحالي الممرر لتعليمه وتمييزه في القائمة
  final void Function(String fileId, String fileName, int pageCount)
  onFileSelected;
  final void Function(
    String fileId,
    String fileName,
    int pageCount,
    bool isProcessing,
  )
  onFileUploaded;
  final VoidCallback onUploadStart;
  final void Function(String msg) onError;

  const FilePickerDialog({
    required this.filesService,
    required this.isArabic,
    this.currentFileId,
    required this.onFileSelected,
    required this.onFileUploaded,
    required this.onUploadStart,
    required this.onError,
  });

  @override
  State<FilePickerDialog> createState() => FilePickerDialogState();
}

class FilePickerDialogState extends State<FilePickerDialog> {
  int _selectedTab = 0;
  List<Map<String, dynamic>> _recentFiles = [];
  List<Map<String, dynamic>> _filteredFiles = [];
  bool _loadingRecent = true;
  bool _isUploading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
    _searchController.addListener(_filterFiles);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterFiles);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentFiles() async {
    final files = await widget.filesService.getRecentFiles();
    if (mounted) {
      setState(() {
        _recentFiles = files;
        _filteredFiles = files;
        _loadingRecent = false;
      });
    }
  }

  void _filterFiles() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredFiles = _recentFiles;
      } else {
        _filteredFiles = _recentFiles.where((file) {
          final fileName = (file['fileName'] ?? file['file_name'] ?? 'Unknown')
              .toString()
              .toLowerCase();
          return fileName.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _uploadNew() async {
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

      setState(() => _isUploading = true);
      widget.onUploadStart();

      // 1. الانتظار حتى يكتمل الرفع تماماً والتأكد من نجاحه في الداتا بيز والباكيند
      final uploadedFile = await widget.filesService.uploadFileBytes(
        bytes,
        fileName: fileName,
        type: 'PDF',
      );

      if (!mounted) return;

      if (uploadedFile != null) {
        // 2. إظهار نافذة السؤال *قبل* عمل pop للـ Dialog الحالي لضمان استقرار الـ Context
        final bool? shouldOpen = await showDialog<bool>(
          context: context,
          barrierDismissible:
              false, // إجبار المستخدم على الاختيار لضمان سلامة الـ Flow
          builder: (dialogCtx) => _buildUploadPrompt(dialogCtx),
        );

        if (mounted) {
          // 3. الآن نغلق الـ FilePickerDialog بأمان
          Navigator.pop(context);

          if (shouldOpen == true) {
            // حالة الفتح الفوري: نمرر البيانات كاملة لتنشيط الملف
            widget.onFileUploaded(
              uploadedFile['id']?.toString() ?? '',
              fileName,
              (uploadedFile['page_count'] ?? 0) as int,
              uploadedFile['has_text'] == false,
            );
          } else {
            // حالة الحفظ فقط: الـ callback المخصص للحفظ بهدوء دون التأثير على الملف الحالي
            widget.onError('__JUST_SAVED_SUCCESS__:$fileName');
          }
        }
      } else {
        Navigator.pop(context);
        widget.onError(
          widget.isArabic ? 'فشل رفع الملف' : 'Failed to upload file',
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      widget.onError('Error: $e');
    }
  }

  // بناء صندوق تأكيد رغبة المستخدم عند الانتهاء من عملية رفع مستند جديد
  Widget _buildUploadPrompt(BuildContext context) {
    final isArabic = widget.isArabic;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_done_rounded,
                color: Color(0xFF10B981),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isArabic ? 'تم الرفع بنجاح' : 'Uploaded Successfully',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'هل تريد فتح ومعالجة المستند فوراً أم حفظه في قائمتك فقط؟'
                  : 'Do you want to open and process it now, or just save it to your list?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false), // حفظ فقط
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isArabic ? 'حفظ فقط' : 'Just Save',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, true), // فتح ومعالجة فورية
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isArabic ? 'فتح ومعالجة' : 'Open & Process',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isArabic = widget.isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 560),
          child: Row(
            children: [
              Container(
                width: 140,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.04),
                  border: Border(
                    right: isArabic
                        ? BorderSide.none
                        : BorderSide(
                            color: theme.dividerColor.withOpacity(0.15),
                            width: 1,
                          ),
                    left: isArabic
                        ? BorderSide(
                            color: theme.dividerColor.withOpacity(0.15),
                            width: 1,
                          )
                        : BorderSide.none,
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        isArabic ? 'اختر ملفاً' : 'Select File',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SideTab(
                      icon: Icons.history_rounded,
                      label: isArabic ? 'السابقة' : 'Recent',
                      selected: _selectedTab == 0,
                      color: theme.primaryColor,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                    const SizedBox(height: 10),
                    _SideTab(
                      icon: Icons.cloud_upload_outlined,
                      label: isArabic ? 'رفع جديد' : 'Upload',
                      selected: _selectedTab == 1,
                      color: theme.primaryColor,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _selectedTab == 0
                          ? _buildRecentTab(theme, isArabic)
                          : _buildUploadTab(theme, isArabic),
                    ),
                    Positioned(
                      top: 14,
                      left: isArabic ? 14 : null,
                      right: isArabic ? null : 14,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.dividerColor.withOpacity(0.04),
                          hoverColor: Colors.red.withOpacity(0.08),
                          foregroundColor: theme.iconTheme.color?.withOpacity(
                            0.6,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        tooltip: isArabic ? 'إغلاق' : 'Close',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTab(ThemeData theme, bool isArabic) {
    return Container(
      key: const ValueKey('recent'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, color: theme.primaryColor, size: 22),
              const SizedBox(width: 10),
              Text(
                isArabic ? 'الملفات السابقة' : 'Recent Files',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: theme.dividerColor.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                hintText: isArabic
                    ? 'ابحث باسم المستند...'
                    : 'Search documents...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Colors.grey[400],
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () => _searchController.clear(),
                        child: Icon(
                          Icons.clear_rounded,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _loadingRecent
                ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
                : _filteredFiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchController.text.isNotEmpty
                              ? Icons.search_off_rounded
                              : Icons.folder_open_rounded,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchController.text.isNotEmpty
                              ? (isArabic
                                    ? 'لم نجد نتائج مطابقة'
                                    : 'No results found')
                              : (isArabic
                                    ? 'لا توجد ملفات سابقة'
                                    : 'No recent files'),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredFiles.length,
                    physics: const BouncingScrollPhysics(),
                    separatorBuilder: (_, __) => Divider(
                      height: 8,
                      color: theme.dividerColor.withOpacity(0.15),
                    ),
                    itemBuilder: (context, index) {
                      final file = _filteredFiles[index];
                      final fileId = file['id']?.toString() ?? '';
                      final fileName =
                          file['fileName'] ?? file['file_name'] ?? 'Unknown';
                      final pageCount = (file['page_count'] ?? 0) as int;
                      final date = _formatDate(
                        file['createdAt'] ?? file['uploaded_at'],
                      );

                      // ميزة احترافية: التحقق مما إذا كان الملف الحالي في الـ List هو الملف النشط والمختار حالياً لتحديده وتلوينه بشكل مميز
                      final bool isSelected =
                          widget.currentFileId != null &&
                          widget.currentFileId == fileId;

                      return ListTile(
                        hoverColor: theme.primaryColor.withOpacity(0.03),
                        // تمييز الكارت النشط بخلفية ملونة رقيقة وحدود متناسقة
                        tileColor: isSelected
                            ? const Color(0xFF10B981).withOpacity(0.06)
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isSelected
                              ? const BorderSide(
                                  color: Color(0xFF10B981),
                                  width: 1.2,
                                )
                              : BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF10B981).withOpacity(0.15)
                                : const Color(0xFF6366F1).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: isSelected
                                ? const Color(0xFF10B981)
                                : const Color(0xFF6366F1),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isSelected ? const Color(0xFF10B981) : null,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '$pageCount ${isArabic ? 'صفحة' : 'pages'} • $date',
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? const Color(0xFF10B981).withOpacity(0.8)
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: Color(0xFF10B981),
                              )
                            : Icon(
                                isArabic
                                    ? Icons.arrow_back_ios_new_rounded
                                    : Icons.arrow_forward_ios_rounded,
                                size: 12,
                                color: Colors.grey[400],
                              ),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onFileSelected(fileId, fileName, pageCount);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTab(ThemeData theme, bool isArabic) {
    return Container(
      key: const ValueKey('upload'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _isUploading ? null : _uploadNew,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: _isUploading
                    ? theme.disabledColor.withOpacity(0.02)
                    : theme.primaryColor.withOpacity(0.02),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isUploading
                      ? Colors.grey[300]!
                      : theme.primaryColor.withOpacity(0.3),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  if (_isUploading) ...[
                    const SizedBox(
                      height: 48,
                      width: 48,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isArabic ? 'جاري رفع الملف...' : 'Uploading file...',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_upload_rounded,
                        color: theme.primaryColor,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isArabic ? 'رفع ملف PDF' : 'Upload PDF',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isArabic
                          ? 'انقر هنا لتصفح الملفات من جهازك'
                          : 'Click here to browse files from your device',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SideTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        width: double.infinity,
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? color : Colors.grey[500], size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.grey[600],
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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

class AppDrawer extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onLogout;
  final String selectedLanguage;
  final String? selectedFileId;
  final String? selectedFileName;

  const AppDrawer({
    Key? key,
    required this.user,
    required this.onLogout,
    required this.selectedLanguage,
    this.selectedFileId,
    this.selectedFileName,
  }) : super(key: key);

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _drawerAnimationController;
  int? _hoveredIndex;

  bool get isArabic => widget.selectedLanguage == 'arabic';

  @override
  void initState() {
    super.initState();
    _drawerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _drawerAnimationController.forward();
  }

  @override
  void dispose() {
    _drawerAnimationController.dispose();
    super.dispose();
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

  ImageProvider? _getUserAvatar() {
    if (widget.user == null) return null;
    if (widget.user!['avatarBytes'] != null) {
      try {
        Uint8List bytes = base64Decode(widget.user!['avatarBytes']);
        return MemoryImage(bytes);
      } catch (e) {
        return null;
      }
    }
    if (widget.user!['avatar'] != null &&
        widget.user!['avatar'].toString().isNotEmpty) {
      return NetworkImage(widget.user!['avatar']);
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
          FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: _drawerAnimationController,
                curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
              ),
            ),
            child: Container(
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
                                  _getInitials(widget.user?['name']),
                                  style: TextStyle(
                                    color: _getColorFromName(
                                      widget.user?['name'],
                                    ),
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.user?['name'] ?? (isArabic ? 'مستخدم' : 'User'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user?['email'] ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              children: [
                _buildAnimatedDrawerItem(
                  context,
                  icon: Icons.home_rounded,
                  title: isArabic ? 'الرئيسية' : 'Home',
                  index: 0,
                  onTap: () => Navigator.pop(context),
                ),
                _buildAnimatedDrawerItem(
                  context,
                  icon: Icons.folder_rounded,
                  title: isArabic ? 'مستنداتي' : 'My Documents',
                  index: 1,
                  onTap: () {
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
                _buildAnimatedDrawerItem(
                  context,
                  icon: Icons.chat_rounded,
                  title: isArabic ? 'الشات الذكي' : 'Smart Chat',
                  index: 2,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      PageTransition(
                        child: ChatPage(
                          fileId: widget.selectedFileId ?? '',
                          fileName: widget.selectedFileName,
                        ),
                        type: PageTransitionType.slideFromRight,
                      ),
                    );
                  },
                ),
                _buildAnimatedDrawerItem(
                  context,
                  icon: Icons.settings_rounded,
                  title: isArabic ? 'الإعدادات' : 'Settings',
                  index: 3,
                  onTap: () {
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
                FadeTransition(
                  opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _drawerAnimationController,
                      curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: Divider(),
                  ),
                ),
                _buildAnimatedDrawerItem(
                  context,
                  icon: Icons.logout_rounded,
                  title: isArabic ? 'تسجيل الخروج' : 'Logout',
                  index: 4,
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onLogout();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int index,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final double start = 0.1 + (index * 0.08);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final Animation<double> fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(
          CurvedAnimation(
            parent: _drawerAnimationController,
            curve: Interval(start, end, curve: Curves.easeInOut),
          ),
        );
    final Animation<Offset> slideAnimation =
        Tween<Offset>(begin: const Offset(0.08, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _drawerAnimationController,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        );

    final isHovered = _hoveredIndex == index;
    final itemColor = color ?? theme.primaryColor;

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) => setState(() => _hoveredIndex = null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isHovered
                  ? itemColor.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  onTap: onTap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isHovered
                          ? itemColor.withOpacity(0.15)
                          : itemColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      padding: EdgeInsets.only(
                        right: isHovered && isArabic ? 4.0 : 0.0,
                        left: isHovered && !isArabic ? 4.0 : 0.0,
                      ),
                      child: Icon(
                        icon,
                        color: itemColor,
                        size: 20,
                      ), // ← الـ style تم التأكد من عدم وجوده هنا بالخطأ
                    ),
                  ),
                  title: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color:
                          color ??
                          theme.textTheme.bodyLarge?.color ??
                          Colors.black,
                      fontWeight: isHovered ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 16,
                    ),
                    child: Text(title),
                  ),
                ),
                Positioned(
                  top: 12,
                  bottom: 12,
                  left: isArabic ? null : 0,
                  right: isArabic ? 0 : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: isHovered ? 4 : 0,
                    decoration: BoxDecoration(
                      color: itemColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
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
