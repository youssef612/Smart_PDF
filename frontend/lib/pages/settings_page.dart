import 'page_transition.dart';
import 'package:flutter/material.dart';
import 'sign_in_page.dart';
import '../main.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _selectedLanguage;
  final AuthService _authService = AuthService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    _selectedLanguage = locale.languageCode;
  }

  bool get isArabic => _selectedLanguage == 'ar';

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showChangeNameDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isArabic ? 'تغيير الاسم' : 'Change Name'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'الاسم الجديد' : 'New Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _authService.updateName(name: ctrl.text.trim());
                _showSnack(isArabic ? 'تم تغيير الاسم' : 'Name updated');
              } catch (e) {
                _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
              }
            },
            child: Text(isArabic ? 'حفظ' : 'Save', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChangeEmailDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool obscure = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isArabic ? 'تغيير الإيميل' : 'Change Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الإيميل الجديد' : 'New Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: isArabic ? 'كلمة المرور الحالية' : 'Current Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setS(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (emailCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) return;
                final newEmail = emailCtrl.text.trim();
                final pass = passCtrl.text;
                Navigator.pop(ctx);
                try {
                  await _authService.changeEmail(
                    newEmail: newEmail,
                    currentPassword: pass,
                  );
                  _showSnack(isArabic ? 'تم إرسال OTP للإيميل الجديد' : 'OTP sent to new email');
                  // show OTP dialog
                  if (mounted) _showEmailOtpDialog(newEmail: newEmail);
                } catch (e) {
                  _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
                }
              },
              child: Text(isArabic ? 'حفظ' : 'Save', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    bool obscure1 = true, obscure2 = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isArabic ? 'تغيير كلمة المرور' : 'Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: obscure1,
                decoration: InputDecoration(
                  labelText: isArabic ? 'كلمة المرور الحالية' : 'Current Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(obscure1 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setS(() => obscure1 = !obscure1),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: obscure2,
                decoration: InputDecoration(
                  labelText: isArabic ? 'كلمة المرور الجديدة' : 'New Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(obscure2 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setS(() => obscure2 = !obscure2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (currentCtrl.text.isEmpty || newCtrl.text.isEmpty) return;
                if (newCtrl.text.length < 8) {
                  _showSnack(isArabic ? 'كلمة المرور 8 أحرف على الأقل' : 'Min 8 characters', error: true);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _authService.changePassword(
                    currentPassword: currentCtrl.text,
                    newPassword: newCtrl.text,
                  );
                  _showSnack(isArabic ? 'تم تغيير كلمة المرور، سجل دخول مجدداً' : 'Password changed, please login again');
                  await _authService.logout();
                  if (mounted) Navigator.pushReplacement(context, PageTransition(child: const SignInPage(), type: PageTransitionType.fade));
                } catch (e) {
                  _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
                }
              },
              child: Text(isArabic ? 'حفظ' : 'Save', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmailOtpDialog({required String newEmail}) {
    final otpCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isArabic ? 'تأكيد الإيميل' : 'Verify Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isArabic
                  ? 'أدخل الكود اللي وصلك على $newEmail'
                  : 'Enter the code sent to $newEmail',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: '000000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (otpCtrl.text.length != 6) return;
              Navigator.pop(ctx);
              try {
                await _authService.changeEmailVerify(
                  otp: otpCtrl.text,
                  newEmail: newEmail,
                );
                await _authService.getCurrentUser();
                _showSnack(isArabic ? 'تم تغيير الإيميل بنجاح' : 'Email updated successfully');
                await _authService.logout();
                if (mounted) Navigator.pushReplacement(context, PageTransition(child: const SignInPage(), type: PageTransitionType.fade));
              } catch (e) {
                _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
              }
            },
            child: Text(isArabic ? 'تأكيد' : 'Verify', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context)!;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(localizations.settings, style: const TextStyle(fontWeight: FontWeight.w600)),
          elevation: 0,
          backgroundColor: theme.cardColor,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Appearance ──
            _sectionHeader(isArabic ? 'المظهر' : 'Appearance', Icons.palette_rounded, const [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            const SizedBox(height: 8),
            _tile(
              context,
              icon: Icons.dark_mode_rounded,
              title: localizations.darkMode,
              subtitle: isArabic ? 'تفعيل الوضع الداكن' : 'Enable dark mode',
              trailing: Switch(
                value: isDark,
                activeColor: const Color(0xFF6366F1),
                onChanged: (v) => MyApp.of(context).changeTheme(v ? ThemeMode.dark : ThemeMode.light),
              ),
            ),
            const SizedBox(height: 20),

            // ── Language ──
            _sectionHeader(isArabic ? 'اللغة' : 'Language', Icons.language_rounded, const [Color(0xFF10B981), Color(0xFF34D399)]),
            const SizedBox(height: 8),
            _tile(
              context,
              icon: Icons.language_rounded,
              title: 'English',
              subtitle: 'Switch to English',
              trailing: _selectedLanguage == 'en'
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1))
                  : null,
              onTap: () {
                MyApp.of(context).changeLanguage(const Locale('en'));
                setState(() => _selectedLanguage = 'en');
              },
            ),
            const SizedBox(height: 8),
            _tile(
              context,
              icon: Icons.language_rounded,
              title: 'العربية',
              subtitle: 'التبديل إلى العربية',
              trailing: _selectedLanguage == 'ar'
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1))
                  : null,
              onTap: () {
                MyApp.of(context).changeLanguage(const Locale('ar'));
                setState(() => _selectedLanguage = 'ar');
              },
            ),
            const SizedBox(height: 20),

            // ── Account ──
            _sectionHeader(isArabic ? 'الحساب' : 'Account', Icons.manage_accounts_rounded, const [Color(0xFFF59E0B), Color(0xFFFBBF24)]),
            const SizedBox(height: 8),
            _tile(
              context,
              icon: Icons.badge_rounded,
              title: isArabic ? 'تغيير الاسم' : 'Change Name',
              subtitle: isArabic ? 'تعديل اسمك' : 'Update your display name',
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: _showChangeNameDialog,
            ),
            const SizedBox(height: 8),
            _tile(
              context,
              icon: Icons.email_rounded,
              title: isArabic ? 'تغيير الإيميل' : 'Change Email',
              subtitle: isArabic ? 'تعديل بريدك الإلكتروني' : 'Update your email address',
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: _showChangeEmailDialog,
            ),
            const SizedBox(height: 8),
            _tile(
              context,
              icon: Icons.lock_rounded,
              title: isArabic ? 'تغيير كلمة المرور' : 'Change Password',
              subtitle: isArabic ? 'تحديث كلمة المرور' : 'Update your password',
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: _showChangePasswordDialog,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, List<Color> colors) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _tile(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: trailing,
      ),
    );
  }
}
