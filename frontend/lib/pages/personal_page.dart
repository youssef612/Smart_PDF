import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import '../utils/responsive.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:project_flutter/services/auth_service.dart';
import 'package:project_flutter/services/files_service.dart';
import 'edit_profile_page.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_flutter/services/api_service.dart';
import 'sign_in_page.dart';

class PersonalPage extends StatefulWidget {
  final Map<String, dynamic>? user;

  const PersonalPage({Key? key, this.user}) : super(key: key);

  @override
  State<PersonalPage> createState() => _PersonalPageState();
}

class _PersonalPageState extends State<PersonalPage>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FilesService _filesService = FilesService();

  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _userFiles = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  Map<String, int> _stats = {
    'completed': 0,
    'processing': 0,
    'total': 0,
  };
  late String _selectedLanguage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadData();

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUserData();
    });
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

  String _getMemberSince() {
    if (_user?['createdAt'] == null)
      return isArabic ? 'تاريخ غير معروف' : 'Unknown date';

    try {
      DateTime joinDate = DateTime.parse(_user!['createdAt']);
      final now = DateTime.now();
      final difference = now.difference(joinDate);

      if (difference.inDays > 365) {
        final years = (difference.inDays / 365).floor();
        return isArabic ? 'عضو منذ $years سنة' : 'Member for $years years';
      } else if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        return isArabic ? 'عضو منذ $months شهر' : 'Member for $months months';
      } else if (difference.inDays > 0) {
        return isArabic
            ? 'عضو منذ ${difference.inDays} يوم'
            : 'Member for ${difference.inDays} days';
      } else {
        final hours = difference.inHours;
        return isArabic
            ? 'عضو منذ $hours ساعة'
            : 'Member for $hours hours';
      }
    } catch (e) {
      return isArabic ? 'عضو جديد' : 'New member';
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return isArabic ? 'غير محدد' : 'Not set';
    try {
      DateTime date = DateTime.parse(dateString);
      final formatter =
          DateFormat(isArabic ? 'yyyy MMMM dd' : 'MMMM dd, yyyy');
      return formatter.format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    if (widget.user != null) {
      _user = widget.user;
    } else {
      _user = await _authService.getCurrentUserFromStorage();
    }

    await _loadUserFiles();
    await _refreshUserData();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshUserData() async {
    final freshUser = await _authService.getCurrentUserFromStorage();
    if (freshUser != null && mounted) {
      setState(() {
        _user = freshUser;
      });
      debugPrint(
          '✅ PersonalPage - User data refreshed: ${_user?['name']}, Has avatar: ${_user?['avatarBytes'] != null}');
    }
  }

  Future<void> _loadUserFiles() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    final files = await _filesService.getRecentFiles();

    int completed = files.where((f) => f['status'] == 'Completed').length;
    int processing = files.where((f) => f['status'] == 'Processing').length;

    if (mounted) {
      setState(() {
        _userFiles = files;
        _stats = {
          'completed': completed,
          'processing': processing,
          'total': files.length,
        };
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return isArabic ? 'م' : 'U';
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

  static const String _baseUrl = 'http://localhost:8000';

  Future<void> _viewFile(Map<String, dynamic> file) async {
    final fileId = file['id'];
    final url = '$_baseUrl/api/files/$fileId/download';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar(isArabic ? 'لا يمكن فتح الملف' : 'Cannot open file');
      }
    } catch (e) {
      _showErrorSnackBar(isArabic ? 'فشل فتح الملف' : 'Failed to open file');
    }
  }

  Future<void> _downloadFile(Map<String, dynamic> file) async {
    final fileId = file['id'];
    final fileName = file['name'] ?? 'file.pdf';
    final token = await _authService.getToken();
    if (token == null) {
      _showErrorSnackBar(isArabic ? 'غير مصرح' : 'Unauthorized');
      return;
    }
    try {
      _showSuccessSnackBar(isArabic ? 'جاري التحميل...' : 'Downloading...');
      final dio = Dio();
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$fileName';
      await dio.download(
        '$_baseUrl/api/files/$fileId/download',
        savePath,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) {
        _showSuccessSnackBar(isArabic ? 'تم التحميل: $fileName' : 'Downloaded: $fileName');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(isArabic ? 'فشل التحميل' : 'Download failed');
      }
    }
  }

  Future<void> _deleteFile(String fileId, String fileName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _buildAnimatedDialog(
        context,
        title: isArabic ? 'حذف الملف' : 'Delete File',
        content: isArabic
            ? 'هل أنت متأكد من حذف "$fileName"؟'
            : 'Are you sure you want to delete "$fileName"?',
        confirmText: isArabic ? 'حذف' : 'Delete',
        isDestructive: true,
      ),
    );

    if (confirm == true) {
      final success = await _filesService.deleteFile(fileId);
      if (success) {
        _loadUserFiles();
        if (mounted) {
          _showSuccessSnackBar(
              isArabic ? 'تم حذف الملف بنجاح' : 'File deleted successfully');
        }
      } else {
        if (mounted) {
          _showErrorSnackBar(
              isArabic ? 'فشل حذف الملف' : 'Failed to delete file');
        }
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _buildAnimatedDialog(
        context,
        title: isArabic ? "حذف الحساب" : "Delete Account",
        content: isArabic
            ? "هل أنت متأكد؟ سيتم حذف كل بياناتك نهائياً"
            : "Are you sure? All your data will be permanently deleted",
        confirmText: isArabic ? "حذف الحساب" : "Delete Account",
        isDestructive: true,
      ),
    );
    if (confirm == true) {
      try {
        final token = await _authService.getToken();
        final response = await ApiService().dio.delete(
          "/me",
          options: Options(headers: {"Authorization": "Bearer $token"}),
        );
        debugPrint("🗑️ Delete response: ${response.data}");
        if (response.data["success"] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const SignInPage()),
              (route) => false,
            );
          }
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar(isArabic ? "فشل حذف الحساب" : "Failed to delete account");
        }
      }
    }
  }

  Map<String, int> _getServiceStats() {
    int summaries = _userFiles.where((f) => f["type"]?.toString().toLowerCase() == "summary").length;
    int questions = _userFiles.where((f) => f["type"]?.toString().toLowerCase() == "questions").length;
    int explanations = _userFiles.where((f) => f["type"]?.toString().toLowerCase() == "translation").length;
    return {"summaries": summaries, "questions": questions, "explanations": explanations};
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
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
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
    final memberSince = _getMemberSince();
    final joinDate = _formatDate(_user?['createdAt']);

    if (_isLoading) {
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: Text(isArabic ? 'ملفي الشخصي' : 'My Profile'),
              backgroundColor: theme.cardColor,
              elevation: 0,
            ),
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
          ), // <-- Scaffold
        ), // <-- Focus
      ); // <-- CallbackShortcuts
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              isArabic ? 'ملفي الشخصي' : 'My Profile',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            elevation: 0,
            backgroundColor: theme.cardColor,
            foregroundColor: theme.textTheme.bodyLarge?.color,
            iconTheme: theme.iconTheme,
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfilePage(user: _user),
                    ),
                  );

                  if (result != null && mounted) {
                    if (result is Map && result['updated'] == true) {
                      final updatedUserData = result['userData'];
                      if (updatedUserData != null) {
                        setState(() {
                          _user = updatedUserData;
                        });
                        debugPrint(
                            '✅ User updated from edit page: ${_user?['name']}');
                      } else {
                        await _refreshUserData();
                      }

                      await _loadUserFiles();

                      _showSuccessSnackBar(isArabic
                          ? 'تم تحديث الملف الشخصي'
                          : 'Profile updated');
                    }
                  }
                },
                tooltip: isArabic ? 'تعديل الملف الشخصي' : 'Edit Profile',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadUserFiles,
            color: const Color(0xFF6366F1),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Header Section
                    SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(40),
                              bottomRight: Radius.circular(40),
                            ),
                          ),
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                              child: Column(
                                children: [
                                  // Profile Image
                                  TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 600),
                                    builder: (context, double value, child) {
                                      return Transform.scale(
                                        scale: value,
                                        child: Container(
                                          width: 140,
                                          height: 140,
                                          decoration: BoxDecoration(
                                            gradient: avatarImage == null
                                                ? LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      _getColorFromName(_user?['name']),
                                                      _getColorFromName(_user?['name'])
                                                          .withBlue(200),
                                                    ],
                                                  )
                                                : null,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 20,
                                                offset: const Offset(0, 10),
                                              ),
                                              BoxShadow(
                                                color: const Color(0xFF6366F1)
                                                    .withOpacity(0.3),
                                                blurRadius: 30,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 4,
                                            ),
                                            image: avatarImage != null
                                                ? DecorationImage(
                                                    image: avatarImage,
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: avatarImage == null
                                              ? Center(
                                                  child: Text(
                                                    _getInitials(_user?['name']),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 48,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 24),

                                  // Name
                                  Text(
                                    _user?['name'] ?? (isArabic ? 'مستخدم' : 'User'),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.verified_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isArabic
                                              ? 'عضو مميز • ${_userFiles.length} مستند'
                                              : 'Premium Member • ${_userFiles.length} document${_userFiles.length != 1 ? 's' : ''}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Member Since Card
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          memberSince,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(
                                          Icons.schedule_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          joinDate,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
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
                      ),
                    ),

                    // Contact Information Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.1),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _animationController,
                            curve:
                                const Interval(0.2, 0.5, curve: Curves.easeOut),
                          )),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF6366F1),
                                            Color(0xFF8B5CF6)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.contact_mail_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      isArabic
                                          ? 'معلومات الاتصال'
                                          : 'Contact Information',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildInfoRow(
                                  theme,
                                  Icons.email_rounded,
                                  isArabic ? 'البريد الإلكتروني' : 'Email Address',
                                  _user?['email'] ?? '',
                                  const Color(0xFF6366F1),
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                  theme,
                                  Icons.calendar_today_rounded,
                                  isArabic ? 'تاريخ الانضمام' : 'Join Date',
                                  joinDate,
                                  const Color(0xFF10B981),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Delete Account Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.red.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 22),
                            ),
                            title: Text(
                              isArabic ? "حذف الحساب" : "Delete Account",
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              isArabic ? "سيتم حذف كل بياناتك نهائياً" : "All your data will be permanently deleted",
                              style: TextStyle(color: Colors.red.withOpacity(0.7), fontSize: 12),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.red, size: 16),
                            onTap: _deleteAccount,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ), // <-- Scaffold
      ), // <-- Focus
    ); // <-- CallbackShortcuts
  }

  Widget _buildStatItem(ThemeData theme, String title, String value,
      Color color, IconData icon) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: double.tryParse(value) ?? 0),
      duration: const Duration(milliseconds: 800),
      builder: (context, double animatedValue, child) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.1),
                    color.withOpacity(0.05)
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              animatedValue.isNaN ? '0' : animatedValue.toInt().toString(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildServiceStatItem(ThemeData theme, String title, int value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label,
      String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserFileItem(
      ThemeData theme, Map<String, dynamic> file) {
    String status = file['status'] ?? 'Completed';
    Color statusColor = status == 'Completed'
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);
    String fileSize = file['size'] ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getTypeColor(file['type']).withOpacity(0.2),
                        _getTypeColor(file['type']).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getTypeIcon(file['type']),
                    color: _getTypeColor(file['type']),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file['name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  status == 'Completed'
                                      ? Icons.check_circle
                                      : Icons.hourglass_empty,
                                  size: 12,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isArabic
                                      ? (status == 'Completed'
                                          ? 'مكتمل'
                                          : 'قيد المعالجة')
                                      : status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getTypeColor(file['type'])
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _translateFileType(file['type']),
                              style: TextStyle(
                                color: _getTypeColor(file['type']),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (fileSize.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.storage_rounded,
                                    size: 10,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    fileSize,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 10,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            file['date'],
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.visibility_rounded,
                      color: Color(0xFF6366F1),
                      size: 20,
                    ),
                    onPressed: () => _viewFile(file),
                    tooltip: isArabic ? 'عرض' : 'View',
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.download_rounded,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                    onPressed: () => _downloadFile(file),
                    tooltip: isArabic ? 'تحميل' : 'Download',
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: theme.iconTheme.color),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteFile(file['id'], file['name']);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            isArabic ? 'حذف' : 'Delete',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
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

  String _translateFileType(String? type) {
    if (!isArabic) return type ?? '';
    switch (type?.toLowerCase()) {
      case 'summary':
        return 'تلخيص';
      case 'translation':
        return 'ترجمة';
      case 'questions':
        return 'أسئلة';
      default:
        return type ?? '';
    }
  }

  Color _getTypeColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'summary':
        return const Color(0xFF6366F1);
      case 'translation':
        return const Color(0xFF10B981);
      case 'questions':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6366F1);
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'summary':
        return Icons.auto_awesome_rounded;
      case 'translation':
        return Icons.language_rounded;
      case 'questions':
        return Icons.quiz_rounded;
      default:
        return Icons.description_rounded;
    }
  }
}