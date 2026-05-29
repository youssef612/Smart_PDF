// pages/summary_page.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'chat_page.dart';
import 'widgets/interactive_scale.dart';
import '../utils/responsive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:project_flutter/services/api_service.dart';
import 'package:project_flutter/services/history_store.dart';
import 'package:project_flutter/pages/widgets/math_markdown.dart';
import 'widgets/particles_painter.dart';
import 'widgets/pdf_export.dart';
import 'widgets/word_export.dart';

// ─────────────────────────────────────────────────────────────
//  SummaryPage
// ─────────────────────────────────────────────────────────────
class SummaryPage extends StatefulWidget {
  final String? fileName;
  final String? fileId;
  final String? summary;
  final int pageCount;
  final int? fromPage;
  final int? toPage;

  const SummaryPage({
    Key? key,
    this.fileName,
    this.fileId,
    this.summary,
    this.pageCount = 0,
    this.fromPage,
    this.toPage,
  }) : super(key: key);

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage>
    with SingleTickerProviderStateMixin {
  bool _isGenerating = false;
  String? _summaryResult;
  late String _selectedLanguage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // متغيرات التحكم في نطاق الصفحات المحددة
  int? _selectedFromPage;
  int? _selectedToPage;
  int _totalPages = 0;

  // ✅ تعريف الـ Controllers هنا لحمايتهم من الـ Rebuild العشوائي ومسح النص
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _totalPages = widget.pageCount;

    // استرجاع نطاق الصفحات الممرر من صفحة التاريخ (History)
    _selectedFromPage = widget.fromPage ?? 1;
    _selectedToPage = widget.toPage ?? (_totalPages > 0 ? _totalPages : 1);

    if (widget.summary != null) {
      _summaryResult = widget.summary;
      _isGenerating = false;
    }

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
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLang = Localizations.localeOf(context).languageCode;
    _selectedLanguage = currentLang == 'ar' ? 'arabic' : 'english';
  }

  bool get isArabic => _selectedLanguage == 'arabic';

  // ── Page Range Dialog ───────────────────────────────────────────
  Future<void> _showPageRangeDialog() async {
    int fromPage = _selectedFromPage ?? 1;
    int toPage = _selectedToPage ?? (_totalPages > 0 ? _totalPages : 1);

    // تهيئة النص داخل الـ Controllers قبل فتح الديالوج علطول
    _fromController.text = '$fromPage';
    _toController.text = '$toPage';

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              isArabic
                  ? 'اختر نطاق الصفحات للملخص'
                  : 'Select Page Range for Summary',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _totalPages > 0
                      ? '${isArabic ? 'إجمالي الصفحات' : 'Total pages'}: $_totalPages'
                      : (isArabic
                            ? 'تعذر تحديد عدد الصفحات'
                            : 'Page count unavailable'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _totalPages > 0
                        ? const Color(0xFF6366F1)
                        : Colors.orange,
                  ),
                ),
                const SizedBox(height: 20),

                // ── من الصفحة ──
                Text(
                  isArabic ? 'من الصفحة' : 'From Page',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _buildPageCounter(
                  value: fromPage,
                  min: 1,
                  max: _totalPages > 0
                      ? _totalPages
                      : 9999, // مفتوح للكتابة الحرة
                  controller: _fromController,
                  onChanged: (val) =>
                      fromPage = val, // تحديث متغير الـ الـ Logic فقط
                  onDecrement: () => setStateDialog(() {
                    if (fromPage > 1) {
                      fromPage--;
                      _fromController.text = '$fromPage';
                    }
                  }),
                  onIncrement: () => setStateDialog(() {
                    fromPage++;
                    _fromController.text = '$fromPage';
                  }),
                ),

                const SizedBox(height: 16),

                // ── إلى الصفحة ──
                Text(
                  isArabic ? 'إلى الصفحة' : 'To Page',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _buildPageCounter(
                  value: toPage,
                  min: 1,
                  max: _totalPages > 0 ? _totalPages : 9999,
                  controller: _toController,
                  onChanged: (val) => toPage = val,
                  onDecrement: () => setStateDialog(() {
                    if (toPage > 1) {
                      toPage--;
                      _toController.text = '$toPage';
                    }
                  }),
                  onIncrement: () => setStateDialog(() {
                    toPage++;
                    _toController.text = '$toPage';
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // 🚨 فحص الـ Validation الذكي عند الضغط على زر التوليد النهائي
                  int finalFrom =
                      int.tryParse(_fromController.text) ?? fromPage;
                  int finalTo = int.tryParse(_toController.text) ?? toPage;

                  if (finalFrom < 1 ||
                      (_totalPages > 0 && finalFrom > _totalPages)) {
                    _showInfoSnackBar(
                      isArabic
                          ? 'رقم بداية الصفحة غير صحيح! يجب أن يكون بين 1 و $_totalPages'
                          : 'Invalid start page! Must be between 1 and $_totalPages',
                      Colors.orange,
                    );
                    return;
                  }

                  if (finalTo < finalFrom ||
                      (_totalPages > 0 && finalTo > _totalPages)) {
                    _showInfoSnackBar(
                      isArabic
                          ? 'رقم نهاية الصفحة غير صحيح أو أقل من صفحة البداية!'
                          : 'Invalid end page or less than start page!',
                      Colors.orange,
                    );
                    return;
                  }

                  Navigator.pop(context, {'from': finalFrom, 'to': finalTo});
                },
                child: Text(isArabic ? 'توليد' : 'Generate'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      setState(() {
        _selectedFromPage = result['from'];
        _selectedToPage = result['to'];
      });
      await _generateSummary();
    }
  }

  // ── Helper Widget لمعداد الصفحات كـ نص عادي ──────────────────────────────
  Widget _buildPageCounter({
    required int value,
    required int min,
    required int max,
    required TextEditingController controller,
    required ValueChanged<int> onChanged,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // زر الناقص (-) بحجم لطيف ومناسب للنص
        IconButton(
          onPressed: value > min ? onDecrement : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          color: const Color(0xFF6366F1),
          iconSize: 22,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),

        // حقل الكتابة الذكي الشفاف (يبدو كنص عادي)
        IntrinsicWidth(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            cursorColor: const Color(0xFF6366F1),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              color: const Color(0xFF6366F1),
              fontWeight: FontWeight.bold,
              fontSize: 18,
              // أضفنا خط تحت الرقم عشان المستخدم يعرف إنه مكان قابل للكتابة
              decoration: TextDecoration.underline,
              decorationColor: const Color(0xFF6366F1).withOpacity(0.4),
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
            onChanged: (text) {
              if (text.isEmpty) return;
              int? parsed = int.tryParse(text);
              if (parsed != null) {
                onChanged(parsed); // تحديث القيمة منطقياً فقط في الخلفية
              }
            },
          ),
        ),
        const SizedBox(width: 8),

        // زر الزائد (+) بحجم مناسب للنص
        IconButton(
          onPressed: (_totalPages == 0 || value < max) ? onIncrement : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: const Color(0xFF6366F1),
          iconSize: 22,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  // ── Generate ──────────────────────────────────────────────
  Future<void> _generateSummary() async {
    if (widget.fileId == null) {
      _showInfoSnackBar(
        isArabic ? 'لم يتم اختيار ملف' : 'No file selected',
        Colors.red,
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final apiService = ApiService();
      final response = await apiService.dio.post(
        '/files/${widget.fileId}/summarize',
        data: {
          if (_selectedFromPage != null) 'from_page': _selectedFromPage,
          if (_selectedToPage != null) 'to_page': _selectedToPage,
        },
      );

      if (response.data['success'] == true) {
        final summaryText = response.data['data']['summary'];
        setState(() {
          _summaryResult = summaryText;
          _isGenerating = false;
        });
        if (widget.fileId != null) {
          await HistoryStore.add({
            'file_id': widget.fileId,
            'file_name': widget.fileName ?? '',
            'type': 'summary',
            'data': summaryText,
            'from_page': _selectedFromPage,
            'to_page': _selectedToPage,
            'page_count': _totalPages,
            'date': DateTime.now().toIso8601String(),
          });
        }
        _showSuccessSnackBar(
          isArabic ? 'تم إنشاء الملخص بنجاح' : 'Summary generated successfully',
        );
      } else {
        setState(() => _isGenerating = false);
        _showInfoSnackBar(
          response.data['message'] ??
              (isArabic ? 'حدث خطأ' : 'An error occurred'),
          Colors.red,
        );
      }
    } on DioException {
      setState(() => _isGenerating = false);
      _showInfoSnackBar(
        isArabic ? 'فشل الاتصال بالسيرفر' : 'Failed to connect to server',
        Colors.red,
      );
    } catch (e) {
      setState(() => _isGenerating = false);
      _showInfoSnackBar(
        isArabic ? 'حدث خطأ غير متوقع' : 'Unexpected error occurred',
        Colors.red,
      );
    }
  }

  // ── Export sheet ──────────────────────────────────────────
  void _showExportSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.ios_share_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isArabic ? 'تصدير الملخص' : 'Export Summary',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'اختر صيغة الملف للتصدير'
                  : 'Choose the file format to export',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            _ExportOptionTile(
              icon: Icons.picture_as_pdf_rounded,
              color: const Color(0xFFEF4444),
              title: 'PDF',
              subtitle: isArabic
                  ? 'ملف PDF جاهز للطباعة والمشاركة'
                  : 'Ready-to-print PDF file',
              onTap: () {
                Navigator.pop(ctx);
                PdfExporter.exportSummary(
                  context: context,
                  summary: _summaryResult ?? '',
                  fileName: widget.fileName ?? 'Summary',
                  isArabic: isArabic,
                );
              },
            ),
            const SizedBox(height: 12),

            _ExportOptionTile(
              icon: Icons.article_rounded,
              color: const Color(0xFF2563EB),
              title: 'Word (DOCX)',
              subtitle: isArabic
                  ? 'ملف Word قابل للتعديل'
                  : 'Editable Word document',
              onTap: () {
                Navigator.pop(ctx);
                WordExporter.exportSummary(
                  context: context,
                  summary: _summaryResult ?? '',
                  fileName: widget.fileName ?? 'Summary',
                  isArabic: isArabic,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Snack bars ────────────────────────────────────────────
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

  void _showInfoSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _copyToClipboard() {
    if (_summaryResult != null) {
      Clipboard.setData(ClipboardData(text: _summaryResult!));
      _showInfoSnackBar(
        isArabic ? 'تم النسخ إلى الحافظة' : 'Copied to clipboard',
        Colors.green,
      );
    }
  }

  // ── Markdown style ────────────────────────────────────────
  MarkdownStyleSheet _buildMarkdownStyle(ThemeData theme) {
    const baseColor = Color(0xFF6366F1);
    return MarkdownStyleSheet(
      h1:
          theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: baseColor,
            letterSpacing: -0.5,
            height: 1.4,
          ) ??
          const TextStyle(),
      h2:
          theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: baseColor.withOpacity(0.85),
            letterSpacing: -0.3,
            height: 1.4,
          ) ??
          const TextStyle(),
      h3:
          theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: baseColor.withOpacity(0.75),
            height: 1.4,
          ) ??
          const TextStyle(),
      h4:
          theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.textTheme.bodyLarge?.color,
            height: 1.4,
          ) ??
          const TextStyle(),
      p:
          theme.textTheme.bodyLarge?.copyWith(
            height: 1.8,
            letterSpacing: 0.1,
          ) ??
          const TextStyle(),
      listBullet:
          theme.textTheme.bodyLarge?.copyWith(height: 1.8, color: baseColor) ??
          const TextStyle(),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        backgroundColor: baseColor.withOpacity(0.08),
        color: baseColor,
      ),
      codeblockDecoration: BoxDecoration(
        color: baseColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: baseColor.withOpacity(0.15)),
      ),
      codeblockPadding: const EdgeInsets.all(16),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: baseColor.withOpacity(0.2), width: 1.5),
        ),
      ),
      blockquote:
          theme.textTheme.bodyLarge?.copyWith(
            fontStyle: FontStyle.italic,
            color: Colors.grey[600],
          ) ??
          const TextStyle(),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: baseColor.withOpacity(0.5), width: 4),
        ),
        color: baseColor.withOpacity(0.04),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      h1Padding: const EdgeInsets.only(top: 16, bottom: 8),
      h2Padding: const EdgeInsets.only(top: 14, bottom: 6),
      h3Padding: const EdgeInsets.only(top: 12, bottom: 4),
      pPadding: const EdgeInsets.symmetric(vertical: 4),
      listIndent: 20,
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              isArabic ? 'ملخص' : 'Summary',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            elevation: 0,
            backgroundColor: theme.cardColor,
            actions: [
              if (widget.fileId != null)
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          fileName: widget.fileName ?? '',
                          fileId: widget.fileId ?? '',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.lightbulb_rounded),
                  color: const Color(0xFFFBBF24),
                  tooltip: isArabic ? 'الشات الذكي' : 'Smart Chat',
                ),
              if (_summaryResult != null)
                IconButton(
                  onPressed: _showExportSheet,
                  icon: const Icon(Icons.ios_share_rounded),
                  color: const Color(0xFF6366F1),
                  tooltip: isArabic ? 'تصدير' : 'Export',
                ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.maxWidth(context),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header card ──────────────────────────────────────────────
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(32),
                            bottomRight: Radius.circular(32),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
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
                                        Color(0xFF8B5CF6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isArabic ? 'ملخص ذكي' : 'Smart Summary',
                                        style:
                                            (theme.textTheme.headlineMedium ??
                                                    const TextStyle())
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: -0.5,
                                                  color: const Color(
                                                    0xFF6366F1,
                                                  ),
                                                ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isArabic
                                            ? 'احصل على ملخص دقيق لمستنداتك'
                                            : 'Get accurate summaries of your documents',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF6366F1).withOpacity(0.1),
                                    const Color(0xFF8B5CF6).withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF6366F1,
                                      ).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.description_rounded,
                                      color: Color(0xFF6366F1),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      widget.fileName ??
                                          (isArabic
                                              ? 'لم يتم اختيار ملف'
                                              : 'No file selected'),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: -0.3,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Generate button ───────────────────────────────────────────
                    SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(20),
                        child: InteractiveScale(
                          onTap: _isGenerating
                              ? null
                              : () async {
                                  await _showPageRangeDialog();
                                },
                          child: SizedBox(
                            width: double.infinity,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: _isGenerating
                                    ? LinearGradient(
                                        colors: [
                                          Colors.grey.shade400,
                                          Colors.grey.shade500,
                                        ],
                                      )
                                    : const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF6366F1),
                                          Color(0xFF8B5CF6),
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: _isGenerating
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF6366F1,
                                          ).withOpacity(0.4),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isGenerating)
                                    const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isGenerating
                                        ? (isArabic
                                              ? 'جاري إنشاء الملخص...'
                                              : 'Generating Summary...')
                                        : (_summaryResult == null
                                              ? (isArabic
                                                    ? 'إنشاء الملخص'
                                                    : 'Generate Summary')
                                              : (isArabic
                                                    ? 'إعادة إنشاء الملخص'
                                                    : 'Regenerate Summary')),
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

                    const SizedBox(height: 12),

                    // ── Summary result card ───────────────────────────────────────
                    SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 0.25),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _animationController,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF10B981),
                                        Color(0xFF34D399),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.summarize_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  isArabic ? 'نتيجة الملخص' : 'Summary Result',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              width: double.infinity,
                              constraints: const BoxConstraints(minHeight: 250),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.scaffoldBackgroundColor,
                                    theme.scaffoldBackgroundColor.withOpacity(
                                      0.8,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withOpacity(0.2),
                                ),
                              ),
                              child: _isGenerating
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const SizedBox(
                                            width: 50,
                                            height: 50,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    Color(0xFF6366F1),
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            isArabic
                                                ? 'جاري إنشاء الملخص...'
                                                : 'Generating your summary...',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: Colors.grey[600],
                                                ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : _summaryResult == null
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.auto_awesome_outlined,
                                            size: 70,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            isArabic
                                                ? 'انقر على "إنشاء الملخص" للبدء'
                                                : 'Click "Generate Summary" to start',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  color: Colors.grey[500],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            isArabic
                                                ? 'سيتم عرض الملخص الذكي هنا'
                                                : 'Your smart summary will appear here',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: Colors.grey[400],
                                                ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Stack(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 36,
                                          ),
                                          child: Directionality(
                                            textDirection: TextDirection.rtl,
                                            child: MathMarkdown(
                                              data: _summaryResult!,
                                              styleSheet: _buildMarkdownStyle(
                                                theme,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: Tooltip(
                                            message: isArabic ? 'نسخ' : 'Copy',
                                            child: InkWell(
                                              onTap: _copyToClipboard,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  7,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF6366F1,
                                                  ).withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF6366F1,
                                                    ).withOpacity(0.25),
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.copy_rounded,
                                                  size: 16,
                                                  color: Color(0xFF6366F1),
                                                ),
                                              ),
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
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Export option tile
// ─────────────────────────────────────────────────────────────
class _ExportOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ExportOptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: color.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
