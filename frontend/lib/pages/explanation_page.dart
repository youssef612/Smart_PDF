// pages/explanation_page.dart
import 'package:flutter/material.dart';
import 'chat_page.dart';
import 'widgets/interactive_scale.dart';
import '../utils/responsive.dart';

import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/api_service.dart';
import '../services/history_store.dart';
import 'widgets/pdf_export.dart';
import 'widgets/word_export.dart';
import 'widgets/math_markdown.dart';
import 'widgets/particles_painter.dart';

class ExplanationPage extends StatefulWidget {
  final String? fileName;
  final String? fileId;
  final dynamic explanation;
  final int pageCount;
  final int? fromPage; // ✅ أضف هذا السطر
  final int? toPage;   // ✅ أضف هذا السطر

  const ExplanationPage({
    Key? key,
    this.fileName,
    this.fileId,
    this.explanation,
    this.pageCount = 0,
    this.fromPage,     // ✅ أضف هذا السطر
    this.toPage,       // ✅ أضف هذا السطر
  }) : super(key: key);

  @override
  State<ExplanationPage> createState() => _ExplanationPageState();
}

class _ExplanationPageState extends State<ExplanationPage>
    with SingleTickerProviderStateMixin {
  bool                       _isLoading = false;
  List<Map<String, dynamic>> _chunks    = [];
  late String                _selectedLanguage;
  late AnimationController   _animationController;
  late Animation<double>     _fadeAnimation;
  late Animation<Offset>     _slideAnimation;

  // ✅ متغيرات التحكم في نطاق الصفحات
  int? _selectedFromPage;
  int? _selectedToPage;
  int _totalPages = 0;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _totalPages = widget.pageCount;

    // ✅ استرجاع نطاق الصفحات الممرر من صفحة التاريخ (History)
    if (widget.fromPage != null) _selectedFromPage = widget.fromPage;
    if (widget.toPage != null) _selectedToPage = widget.toPage;

    if (widget.explanation != null) {
      _chunks = _parseExplanation(widget.explanation);
    }
    if (widget.explanation != null) {
      _chunks = _parseExplanation(widget.explanation);
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

  List<Map<String, dynamic>> _parseExplanation(dynamic raw) {
    if (raw is List) {
      return raw
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (raw is String && raw.isNotEmpty) {
      final parts = raw
          .split(RegExp(r'\n\s*---\s*\n'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.isEmpty) return [];
      return parts.asMap().entries.map((e) {
        return {
          'part':     e.key + 1,
          'total':    parts.length,
          'content':  e.value,
          'original': '',
        };
      }).toList();
    }
    return [];
  }

  String get _flatText => _chunks
      .map((c) => (c['content'] as String? ?? '').trim())
      .where((s) => s.isNotEmpty)
      .join('\n\n---\n\n');

  // ── Page Range Dialog (نفس التصميم المتناسق) ─────────────────
  Future<void> _showPageRangeDialog() async {
    int fromPage = _selectedFromPage ?? 1;
    int toPage   = _selectedToPage ?? (_totalPages > 0 ? _totalPages : 1);

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isArabic ? 'اختر نطاق الصفحات للشرح' : 'Select Page Range for Explanation',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _totalPages > 0
                    ? '${isArabic ? 'إجمالي الصفحات' : 'Total pages'}: $_totalPages'
                    : (isArabic ? 'تعذر تحديد عدد الصفحات' : 'Page count unavailable'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _totalPages > 0 ? const Color(0xFF6366F1) : Colors.orange,
                ),
              ),
              const SizedBox(height: 20),

              // ── من الصفحة ──
              Text(isArabic ? 'من الصفحة' : 'From Page',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildPageCounter(
                value: fromPage,
                min: 1,
                max: toPage,
                onDecrement: () => setStateDialog(() {
                  if (fromPage > 1) fromPage--;
                }),
                onIncrement: () => setStateDialog(() {
                  if (fromPage < toPage) fromPage++;
                }),
              ),

              const SizedBox(height: 16),

              // ── إلى الصفحة ──
              Text(isArabic ? 'إلى الصفحة' : 'To Page',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildPageCounter(
                value: toPage,
                min: fromPage,
                max: _totalPages > 0 ? _totalPages : 9999,
                onDecrement: () => setStateDialog(() {
                  if (toPage > fromPage) toPage--;
                }),
                onIncrement: () => setStateDialog(() {
                  if (_totalPages == 0 || toPage < _totalPages) toPage++;
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, {'from': fromPage, 'to': toPage}),
              child: Text(isArabic ? 'توليد' : 'Generate'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedFromPage = result['from'];
        _selectedToPage   = result['to'];
      });
      await _explainDocument();
    }
  }

  // ── Helper Widget لمعداد الصفحات ──────────────────────────────
  Widget _buildPageCounter({
    required int value,
    required int min,
    required int max,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: value > min ? onDecrement : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          color: const Color(0xFF6366F1),
          iconSize: 28,
        ),
        Container(
          width: 70,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        IconButton(
          onPressed: (_totalPages == 0 || value < max) ? onIncrement : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: const Color(0xFF6366F1),
          iconSize: 28,
        ),
      ],
    );
  }

  Future<void> _explainDocument() async {
    if (widget.fileId == null) {
      _showSnackBar(isArabic ? 'لم يتم اختيار ملف' : 'No file selected', Colors.red);
      return;
    }
    setState(() { _isLoading = true; _chunks = []; });
    try {
      // ✅ تمرير نطاق الصفحات في الـ request body إذا تم تحديده
      final response = await _apiService.dio.post(
        '/files/${widget.fileId}/explain',
        data: {
          if (_selectedFromPage != null) 'from_page': _selectedFromPage,
          if (_selectedToPage != null) 'to_page': _selectedToPage,
        },
      );
      if (response.data['success'] == true) {
        final raw    = response.data['data']['explanation'];
        final chunks = _parseExplanation(raw);
        setState(() { _chunks = chunks; _isLoading = false; });
        _animationController.reset();
        _animationController.forward();
        if (widget.fileId != null && chunks.isNotEmpty) {
          await HistoryStore.add({
            'file_id':   widget.fileId,
            'file_name': widget.fileName ?? '',
            'type':      'explanation',
            'data':      raw,
            'from_page': _selectedFromPage, // ✅ حفظ البيانات في الـ History
            'to_page':   _selectedToPage,
            'page_count': _totalPages,
            'date':      DateTime.now().toIso8601String(),
          });
        }
        _showSnackBar(isArabic ? 'تم الشرح بنجاح' : 'Explanation completed successfully', Colors.green);
      } else {
        setState(() => _isLoading = false);
        _showSnackBar(response.data['message'] ?? (isArabic ? 'فشل الشرح' : 'Explanation failed'), Colors.red);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(isArabic ? 'حدث خطأ: $e' : 'Error: $e', Colors.red);
    }
  }

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
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(isArabic ? 'تصدير الشرح' : 'Export Explanation',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            ]),
            const SizedBox(height: 8),
            Text(isArabic ? 'اختر صيغة الملف للتصدير' : 'Choose the file format to export',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
            const SizedBox(height: 24),
            _ExportOptionTile(
              icon: Icons.picture_as_pdf_rounded, color: const Color(0xFFEF4444),
              title: 'PDF', subtitle: isArabic ? 'ملف PDF جاهز للطباعة والمشاركة' : 'Ready-to-print PDF file',
              onTap: () { Navigator.pop(ctx); PdfExporter.exportSummary(context: context, summary: _flatText, fileName: widget.fileName ?? 'Explanation', isArabic: isArabic); },
            ),
            const SizedBox(height: 12),
            _ExportOptionTile(
              icon: Icons.article_rounded, color: const Color(0xFF2563EB),
              title: 'Word (DOCX)', subtitle: isArabic ? 'ملف Word قابل للتعديل' : 'Editable Word document',
              onTap: () { Navigator.pop(ctx); WordExporter.exportSummary(context: context, summary: _flatText, fileName: widget.fileName ?? 'Explanation', isArabic: isArabic); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(color == Colors.green ? Icons.check_circle : Icons.info_outline, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _copyToClipboard() {
    if (_chunks.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _flatText));
      _showSnackBar(isArabic ? 'تم النسخ إلى الحافظة' : 'Copied to clipboard', Colors.green);
    }
  }

  MarkdownStyleSheet _buildMarkdownStyle(ThemeData theme) {
    const baseColor = Color(0xFF6366F1);
    return MarkdownStyleSheet(
      h1: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: baseColor, letterSpacing: -0.5, height: 1.4) ?? const TextStyle(),
      h2: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6), letterSpacing: -0.3, height: 1.4) ?? const TextStyle(),
      h3: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: baseColor, height: 1.4) ?? const TextStyle(),
      p: theme.textTheme.bodyLarge?.copyWith(height: 1.8, letterSpacing: 0.1) ?? const TextStyle(),
      listBullet: theme.textTheme.bodyLarge?.copyWith(height: 1.8, color: baseColor) ?? const TextStyle(),
      code: const TextStyle(fontFamily: 'monospace', fontSize: 13, backgroundColor: Color(0x146366F1), color: baseColor),
      codeblockDecoration: BoxDecoration(color: const Color(0x0D6366F1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x266366F1))),
      codeblockPadding: const EdgeInsets.all(16),
      blockquote: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey[600]) ?? const TextStyle(),
      blockquoteDecoration: BoxDecoration(
        border: const Border(left: BorderSide(color: Color(0x806366F1), width: 4)),
        color: const Color(0x0A6366F1),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      h1Padding: const EdgeInsets.only(top: 16, bottom: 8),
      h2Padding: const EdgeInsets.only(top: 14, bottom: 6),
      h3Padding: const EdgeInsets.only(top: 12, bottom: 4),
      pPadding: const EdgeInsets.symmetric(vertical: 4),
      listIndent: 20,
    );
  }

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
            title: Text(isArabic ? 'الشرح' : 'Explanation', style: const TextStyle(fontWeight: FontWeight.w600)),
            elevation: 0,
            backgroundColor: theme.cardColor,
            actions: [
              if (widget.fileId != null)
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ChatPage(fileId: widget.fileId!, fileName: widget.fileName ?? ""),
                  )),
                  icon: const Icon(Icons.lightbulb_rounded),
                  color: const Color(0xFFFBBF24),
                  tooltip: isArabic ? 'الشات الذكي' : 'Smart Chat',
                ),
              if (_chunks.isNotEmpty) ...[
                IconButton(
                  onPressed: _showExportSheet,
                  icon: const Icon(Icons.ios_share_rounded),
                  color: const Color(0xFF6366F1),
                  tooltip: isArabic ? 'تصدير' : 'Export',
                ),
              ],
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──
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
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShimmerText(
                                    text: isArabic ? 'الشرح الذكي' : 'Smart Explanation',
                                    style: (theme.textTheme.headlineMedium ?? const TextStyle()).copyWith(
                                      fontWeight: FontWeight.bold, letterSpacing: -0.5, color: const Color(0xFF6366F1),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isArabic ? 'شرح بالعامية المصرية بأسلوب بسيط' : 'Explained in simple Egyptian Arabic',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                                  ),
                                ],
                              )),
                            ]),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [const Color(0xFF6366F1).withOpacity(0.1), const Color(0xFF8B5CF6).withOpacity(0.05)]),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                              ),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.description_rounded, color: Color(0xFF6366F1), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(
                                  widget.fileName ?? (isArabic ? 'لم يتم اختيار ملف' : 'No file selected'),
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -0.3),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                )),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Generate button ──
                    SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24)),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(20),
                        child: InteractiveScale(
                          onTap: _isLoading ? null : () async {
                            await _showPageRangeDialog(); // ✅ استدعاء الديالوج عند الضغط للبدء
                          },
                          child: SizedBox(
                            width: double.infinity,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: _isLoading
                                    ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade500])
                                    : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: _isLoading ? [] : [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isLoading)
                                    const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)))
                                  else
                                    const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 22),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isLoading
                                        ? (isArabic ? 'جاري الشرح...' : 'Explaining...')
                                        : (_chunks.isEmpty ? (isArabic ? 'اشرحلي المستند' : 'Explain Document') : (isArabic ? 'إعادة الشرح' : 'Re-explain')),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // ── Result card ──
                    SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
                        CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
                      ),
                      child: Container(
                        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24)),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                isArabic ? 'نتيجة الشرح' : 'Explanation Result',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.5),
                              ),
                            ]),

                            const SizedBox(height: 20),

                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              width: double.infinity,
                              constraints: const BoxConstraints(minHeight: 250),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  theme.scaffoldBackgroundColor,
                                  theme.scaffoldBackgroundColor.withOpacity(0.8),
                                ]),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                              ),
                              child: _isLoading
                                  ? Center(child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(width: 50, height: 50,
                                      child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)))),
                                  const SizedBox(height: 20),
                                  Text(isArabic ? 'جاري الشرح...' : 'Explaining your document...',
                                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
                                ],
                              ))
                                  : _chunks.isEmpty
                                  ? Center(child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lightbulb_outline_rounded, size: 70, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    isArabic ? 'انقر على "اشرحلي المستند" للبدء' : 'Click "Explain Document" to start',
                                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[500], fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ))
                                  : Stack(children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 36),
                                  child: Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: MathMarkdown(
                                      data: _flatText,
                                      styleSheet: _buildMarkdownStyle(theme),
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
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.25)),
                                        ),
                                        child: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF6366F1)),
                                      ),
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
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

class _ExportOptionTile extends StatelessWidget {
  final IconData icon; final Color color; final String title; final String subtitle; final VoidCallback onTap;
  const _ExportOptionTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

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
          decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.25))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
            ])),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color.withOpacity(0.6)),
          ]),
        ),
      ),
    );
  }
}