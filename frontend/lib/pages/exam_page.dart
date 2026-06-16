// lib/pages/exam_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'exam_models.dart';
import 'widgets/pdf_export.dart';
import 'widgets/word_export.dart';
import 'widgets/math_markdown.dart';
import 'widgets/interactive_scale.dart';
import '../services/files_service.dart';
import 'questions_page.dart';
import 'home_page.dart';
import '../services/exam_service.dart';
import 'package:dio/dio.dart'; // ✅ إضافة الـ Dio للتعامل مع الـ CancelToken

class ExamPage extends StatefulWidget {
  final bool isArabic;
  final FilesService? filesService;
  final String? fileId;
  final String? fileName;
  final int pageCount;

  const ExamPage({
    Key? key,
    required this.isArabic,
    this.filesService,
    this.fileId,
    this.fileName,
    this.pageCount = 0,
  }) : super(key: key);

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> with SingleTickerProviderStateMixin {
  bool get isArabic => widget.isArabic;

  final ExamService _examService = ExamService();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _subjectCtrl  = TextEditingController();
  final TextEditingController _durationCtrl = TextEditingController();
  bool _showAnswerKey = false;
  bool _isGlobalLoading = false; // ✅ تتبع حالة التوليد الإجمالية لحماية الصفحة من الخروج

  String? _activeFileId;
  String? _activeFileName;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _activeFileId = widget.fileId;
    _activeFileName = widget.fileName;

    final activeSheet = ExamStore.activeOrNull;
    _titleCtrl.text = activeSheet?.title ?? (isArabic ? 'ورقة امتحان ذكية' : 'Smart Exam Sheet');
    _subjectCtrl.text = activeSheet?.subject ?? '';
    _durationCtrl.text = activeSheet?.duration ?? '';

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _titleCtrl.addListener(_autoSaveHeaderData);
    _subjectCtrl.addListener(_autoSaveHeaderData);
    _durationCtrl.addListener(_autoSaveHeaderData);
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_autoSaveHeaderData);
    _subjectCtrl.removeListener(_autoSaveHeaderData);
    _durationCtrl.removeListener(_autoSaveHeaderData);
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    _durationCtrl.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _autoSaveHeaderData() {
    final activeSheet = ExamStore.activeOrNull;
    if (activeSheet != null) {
      activeSheet.title = _titleCtrl.text;
      activeSheet.subject = _subjectCtrl.text;
      activeSheet.duration = _durationCtrl.text;
    }
  }

  List<Map<String, String>> _questionsAsMap() {
    return ExamStore.questions.map((q) => {
      'question':   q.question,
      'answer':     q.answer,
      'type':       q.type,
      'difficulty': q.difficulty,
    }).toList();
  }

  Map<String, List<ExamQuestion>> _groupQuestionsByType() {
    final Map<String, List<ExamQuestion>> grouped = {};
    for (var q in ExamStore.questions) {
      grouped.putIfAbsent(q.type, () => []).add(q);
    }
    return grouped;
  }

  void _showExportSheet() {
    final theme     = Theme.of(context);
    final examTitle = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : (isArabic ? 'امتحان' : 'Exam');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 45, height: 5,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.ios_share_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Text(
                  isArabic ? 'تصدير الامتحان' : 'Export Exam',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                isArabic ? 'اختر صيغة الملف المفضلة لحفظ أو طباعة المستند' : 'Choose your preferred file format to save or print',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              ),
            ),
            const SizedBox(height: 24),
            _ExportOptionTile(
              icon: Icons.picture_as_pdf_rounded,
              color: const Color(0xFFEF4444),
              title: 'PDF Document',
              subtitle: isArabic ? 'ملف PDF ثابت جاهز للطباعة والمشاركة الفورية' : 'Fixed PDF layout ready for printing & sharing',
              onTap: () {
                Navigator.pop(ctx);
                PdfExporter.exportQuestions(
                  context:   context,
                  questions: _questionsAsMap(),
                  fileName:  examTitle,
                  isArabic:  isArabic,
                );
              },
            ),
            const SizedBox(height: 12),
            _ExportOptionTile(
              icon: Icons.article_rounded,
              color: const Color(0xFF2563EB),
              title: 'Word (DOCX)',
              subtitle: isArabic ? 'مستند وورد مرن وقابل للتعديل وإعادة الصياغة' : 'Flexible Word file template ready for editing',
              onTap: () {
                Navigator.pop(ctx);
                WordExporter.exportQuestions(
                  context:   context,
                  questions: _questionsAsMap(),
                  fileName:  examTitle,
                  isArabic:  isArabic,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeQuestion(ExamQuestion target) async {
    setState(() {
      ExamStore.questions.removeWhere((q) => q.id == target.id);
    });
    final activeSheet = ExamStore.activeOrNull;
    if (activeSheet?.dbId != null) {
      await _examService.update(
        activeSheet!.dbId!,
        ExamStore.questions.map((q) => q.toMap()).toList(),
      );
    }
  }

  void _clearAll() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                isArabic ? 'مسح ورقة الامتحان؟' : 'Clear Exam Sheet?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: widget.isArabic ? null : FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isArabic ? 'سيتم حذف جميع الأسئلة الحالية والبدء من جديد. هل أنت متأكد؟' : 'This action will wipe all current questions. Are you sure?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 13.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() => ExamStore.clear());
                        Navigator.pop(ctx);
                        final activeSheet = ExamStore.activeOrNull;
                        if (activeSheet?.dbId != null) {
                          await _examService.update(activeSheet!.dbId!, []);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(isArabic ? 'مسح الكل' : 'Clear All', style: const TextStyle(color: Colors.white)),
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

  Color _diffColor(String diff) {
    final lower = diff.toLowerCase();
    if (lower == 'easy'   || lower == 'سهل')   return const Color(0xFF10B981);
    if (lower == 'medium' || lower == 'متوسط') return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  // ✅ ميزة الخروج الثالثة: نظام حماية الديالوج لمنع الخروج المفاجئ أثناء المعالجة الخلفية
  Future<bool> _onWillPop() async {
    if (!_isGlobalLoading) return true;

    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
            const SizedBox(width: 10),
            Text(
              isArabic ? 'تنبيه: جاري التوليد' : 'Warning: Generating',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من مغادرة الشاشة؟ سيؤدي ذلك إلى إلغاء عملية إنشاء الأسئلة الحالية.'
              : 'Are you sure you want to leave? This will cancel the current questions generation.',
          style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              isArabic ? 'تابع الانتظار' : 'Keep Waiting',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx, true); // الموافقة على المغادرة والإغلاق الفوري
            },
            child: Text(isArabic ? 'إلغاء ومغادرة' : 'Cancel & Leave'),
          ),
        ],
      ),
    );

    return shouldCancel ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final groupedQuestions = _groupQuestionsByType();
    final String appBarTitle = ExamStore.activeOrNull?.title ?? (isArabic ? 'صانع الامتحانات الذكي' : 'Smart Exam Builder');

    // ✅ تطبيق الـ PopScope لحماية خروج الصفحة بالكامل بناءً على ميزتك الثالثة
    return PopScope(
      canPop: !_isGlobalLoading,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              appBarTitle,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            elevation: 0,
            backgroundColor: theme.cardColor,
            foregroundColor: theme.textTheme.bodyLarge?.color,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: theme.textTheme.bodyLarge?.color),
              ),
              onPressed: () async {
                final shouldPop = await _onWillPop();
                if (shouldPop && context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
            actions: [
              if (ExamStore.questions.isNotEmpty) ...[
                IconButton(
                  onPressed: _showExportSheet,
                  icon: const Icon(Icons.ios_share_rounded),
                  color: const Color(0xFF6366F1),
                  tooltip: isArabic ? 'تصدير' : 'Export',
                ),
                IconButton(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.delete_sweep_rounded),
                  color: Colors.red.withOpacity(0.8),
                  tooltip: isArabic ? 'مسح الكل' : 'Clear all',
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
          body: ExamStore.questions.isEmpty
              ? _GenerateQuestionsPanel(
            isArabic: isArabic,
            filesService: widget.filesService,
            fileId: _activeFileId,
            fileName: _activeFileName,
            pageCount: widget.pageCount,
            onFileUpdated: (newId, newName) {
              setState(() {
                _activeFileId = newId;
                _activeFileName = newName;
              });
            },
            onStatusChanged: (loading) {
              setState(() => _isGlobalLoading = loading);
            },
            onGenerated: () => setState(() {}),
          )
              : Column(
            children: [
              _buildHeaderConfigCard(theme),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: const Color(0xFF6366F1).withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Text(
                      isArabic ? 'الأسئلة مرتبة تلقائياً ومجمعة حسب نوعها لمظهر احترافي' : 'Questions are automatically sorted and grouped by type',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: groupedQuestions.keys.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (ctx, typeIndex) {
                    final typeKey = groupedQuestions.keys.elementAt(typeIndex);
                    final typeList = groupedQuestions[typeKey]!;
                    return _buildQuestionGroupSection(theme, typeKey, typeList, typeIndex + 1);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderConfigCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: isArabic ? 'اسم الامتحان' : 'Exam title',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isArabic ? '${ExamStore.questions.length} سؤال' : '${ExamStore.questions.length} Qs',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildExamInfoField(
                  ctrl: _subjectCtrl,
                  hint: isArabic ? 'المادة الدراسية...' : 'Subject name...',
                  icon: Icons.book_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildExamInfoField(
                  ctrl: _durationCtrl,
                  hint: isArabic ? 'مدة الامتحان (دقائق)' : 'Duration (mins)',
                  icon: Icons.timer_rounded,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => setState(() => _showAnswerKey = !_showAnswerKey),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _showAnswerKey ? Colors.white.withOpacity(0.22) : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(_showAnswerKey ? 0.35 : 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showAnswerKey ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _showAnswerKey
                        ? (isArabic ? 'إخفاء الإجابات النموذجية' : 'Hide Answers Key')
                        : (isArabic ? 'إظهار الإجابات النموذجية' : 'Show Answers Key'),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionGroupSection(ThemeData theme, String typeKey, List<ExamQuestion> typeList, int groupNumber) {
    String groupTitle = typeKey.replaceAll('_', ' ').toUpperCase();
    if (isArabic) {
      if (typeKey.contains('multiple')) groupTitle = 'القسم $groupNumber: أسئلة الاختيار من متعدد';
      else if (typeKey.contains('true')) groupTitle = 'القسم $groupNumber: أسئلة الصواب والخطأ';
      else if (typeKey.contains('short')) groupTitle = 'القسم $groupNumber: الأسئلة المقالية القصيرة';
      else if (typeKey.contains('essay')) groupTitle = 'القسم $groupNumber: الأسئلة المقالية الطويلة';
      else if (typeKey.contains('matching')) groupTitle = 'القسم $groupNumber: أسئلة التوصيل / المطابقة';
      else if (typeKey.contains('ordering')) groupTitle = 'القسم $groupNumber: أسئلة ترتيب العناصر';
      else if (typeKey.contains('definition')) groupTitle = 'القسم $groupNumber: أسئلة المصطلحات والتعريفات';
      else groupTitle = 'القسم $groupNumber: أسئلة متنوعة ($groupTitle)';
    } else {
      groupTitle = 'Question $groupNumber: $groupTitle';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 10),
          child: Row(
            children: [
              Container(
                width: 4, height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                groupTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color?.withOpacity(0.85),
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: typeList.length,
          onReorder: (oldIdx, newIdx) {
            setState(() {
              if (newIdx > oldIdx) newIdx--;
              final item = typeList.removeAt(oldIdx);
              typeList.insert(newIdx, item);

              final otherTypes = ExamStore.questions.where((q) => q.type != typeKey).toList();
              ExamStore.questions.clear();
              ExamStore.questions.addAll(otherTypes..addAll(typeList));
            });
          },
          itemBuilder: (ctx, index) {
            final q = typeList[index];
            return _QuestionHoverTile(
              key: ValueKey('tile_${q.id}'),
              q: q,
              insideIndex: index + 1,
              showAnswerKey: _showAnswerKey,
              isArabic: isArabic,
              diffColor: _diffColor(q.difficulty),
              onRemove: () => _removeQuestion(q),
            );
          },
        ),
      ],
    );
  }

  Widget _buildExamInfoField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white.withOpacity(0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: keyboardType,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12.5),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionHoverTile extends StatefulWidget {
  final ExamQuestion q;
  final int insideIndex;
  final bool showAnswerKey;
  final bool isArabic;
  final Color diffColor;
  final VoidCallback onRemove;

  const _QuestionHoverTile({
    Key? key,
    required this.q,
    required this.insideIndex,
    required this.showAnswerKey,
    required this.isArabic,
    required this.diffColor,
    required this.onRemove,
  }) : super(key: key);

  @override
  State<_QuestionHoverTile> createState() => _QuestionHoverTileState();
}

class _QuestionHoverTileState extends State<_QuestionHoverTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final questionStyle = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.6, fontSize: 14);
    final answerStyle = theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600], height: 1.5, fontSize: 12);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 10),
        transform: Matrix4.identity()..translate(_isHovered ? (widget.isArabic ? -3.0 : 3.0) : 0.0),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFF6366F1).withOpacity(isDark ? 0.12 : 0.04) : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _isHovered ? const Color(0xFF6366F1).withOpacity(0.3) : theme.dividerColor.withOpacity(0.06), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: _isHovered ? const Color(0xFF6366F1).withOpacity(0.06) : Colors.black.withOpacity(0.02),
              blurRadius: _isHovered ? 12 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${widget.insideIndex}',
                    style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _innerTag(widget.q.difficulty, widget.diffColor),
                        const SizedBox(width: 6),
                        _innerTag(widget.q.type.replaceAll('_', ' '), const Color(0xFF6366F1)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    MathMarkdown(
                      data: widget.q.question,
                      style: questionStyle,
                    ),
                    if (widget.showAnswerKey && widget.q.answer.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isArabic ? 'الإجابة النموذجية:' : 'Model Answer:',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                            ),
                            const SizedBox(height: 4),
                            MathMarkdown(
                              data: widget.q.answer,
                              style: answerStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.onRemove,
                icon: Icon(Icons.remove_circle_outline_rounded, size: 20, color: Colors.red.withOpacity(0.7)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                hoverColor: Colors.red.withOpacity(0.05),
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _innerTag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

class _ExportOptionTile extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       title;
  final String       subtitle;
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
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                  isArabic ? Icons.arrow_back_ios_new_rounded : Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: color.withOpacity(0.5)
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  لوحة توليد الأسئلة الذكية المحدثة كلياً بمزايا شاشة الأسئلة المتطورة
// ═══════════════════════════════════════════════════════════════
class _GenerateQuestionsPanel extends StatefulWidget {
  final bool isArabic;
  final FilesService? filesService;
  final String? fileId;
  final String? fileName;
  final int pageCount;
  final Function(String? id, String? name) onFileUpdated;
  final ValueChanged<bool> onStatusChanged; // ✅ إشعار الصفحة بحالة التحميل الإجمالية للتحكم بالـ PopScope
  final VoidCallback onGenerated;

  const _GenerateQuestionsPanel({
    required this.isArabic,
    required this.filesService,
    required this.fileId,
    this.fileName,
    this.pageCount = 0,
    required this.onFileUpdated,
    required this.onStatusChanged,
    required this.onGenerated,
  });

  @override
  State<_GenerateQuestionsPanel> createState() => _GenerateQuestionsPanelState();
}

class _GenerateQuestionsPanelState extends State<_GenerateQuestionsPanel> {
  bool get isArabic => widget.isArabic;

  final ExamService _examService = ExamService();
  final Map<String, int> _selectedTypes = {};
  final Map<String, String> _typeDifficulties = {};
  bool _isLoading = false;

  // ✅ تهيئة المتحكمات لنطاق الصفحات المأخوذة من شاشة الأسئلة
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  int? _selectedFromPage;
  int? _selectedToPage;
  int _totalPages = 0;
  CancelToken? _cancelToken; // ✅ لإلغاء طلب السيرفر فوراً عند تأكيد الخروج

  @override
  void initState() {
    super.initState();
    _totalPages = widget.pageCount;
    if (_totalPages > 0) {
      _selectedFromPage = 1;
      _selectedToPage = _totalPages;
    }
  }

  final List<Map<String, dynamic>> _filteredQuestionTypes = [
    {'value': 'multiple', 'labelEn': 'Multiple Choice', 'labelAr': 'اختيار من متعدد', 'icon': Icons.checklist_rounded},
    {'value': 'truefalse', 'labelEn': 'True / False', 'labelAr': 'صح أو خطأ', 'icon': Icons.check_circle_outline_rounded},
    {'value': 'short', 'labelEn': 'Short Answer', 'labelAr': 'إجابة قصيرة', 'icon': Icons.short_text_rounded},
    {'value': 'essay', 'labelEn': 'Essay', 'labelAr': 'مقالي', 'icon': Icons.article_rounded},
    {'value': 'matching', 'labelEn': 'Matching', 'labelAr': 'توصيل / مطابقة', 'icon': Icons.compare_arrows_rounded},
    {'value': 'ordering', 'labelEn': 'Ordering', 'labelAr': 'ترتيب العناصر', 'icon': Icons.sort_rounded},
    {'value': 'definition', 'labelEn': 'Definition', 'labelAr': 'مصطلحات وتعريفات', 'icon': Icons.menu_book_rounded},
  ];

  int get _totalCount => _selectedTypes.values.fold(0, (a, b) => a + b);

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _changeActiveFile() async {
    if (_isLoading) return;
    if (widget.filesService == null) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => FilePickerDialog(
        filesService: widget.filesService!,
        isArabic: isArabic,
        currentFileId: widget.fileId,
        onFileSelected: (fileId, fileName, pageCount) {
          widget.onFileUpdated(fileId, fileName);
          setState(() {
            _totalPages = pageCount;
            _selectedFromPage = 1;
            _selectedToPage = pageCount > 0 ? pageCount : 1;
            _selectedTypes.clear();
            _typeDifficulties.clear();
          });
        },
        onFileUploaded: (fileId, fileName, pageCount, isProcessing) {
          widget.onFileUpdated(fileId, fileName);
          setState(() {
            _totalPages = pageCount;
            _selectedFromPage = 1;
            _selectedToPage = pageCount > 0 ? pageCount : 1;
            _selectedTypes.clear();
            _typeDifficulties.clear();
          });
        },
        onUploadStart: () {},
        onError: (msg) {},
      ),
    );
  }

  void _toggleTypeSelection(String value) {
    if (_isLoading) return;
    setState(() {
      if (_selectedTypes.containsKey(value)) {
        _selectedTypes.remove(value);
        _typeDifficulties.remove(value);
      } else {
        _selectedTypes[value] = 5; // جعل العدد الافتراضي عند التفعيل 5 مطابقة لصفحة الأسئلة
        _typeDifficulties[value] = 'medium';
      }
    });
  }

  void _updateCount(String value, int count) {
    if (_isLoading) return;
    setState(() {
      if (count <= 0) {
        _selectedTypes.remove(value);
        _typeDifficulties.remove(value);
      } else if (count <= 50) { // الالتزام بالحد الأقصى (50 سؤال) لكل نوع
        _selectedTypes[value] = count;
      }
    });
  }

  String _mapType(String type) {
    const map = {
      'multiple': 'multiple_choice',
      'truefalse': 'true_false',
      'short': 'short_answer',
      'essay': 'essay',
      'matching': 'matching',
      'ordering': 'ordering',
      'definition': 'definition',
    };
    return map[type] ?? 'multiple_choice';
  }

  // ✅ ميزة شاشة الأسئلة الأولى: ديالوج اختيار نطاق الصفحات المتقدم والذكي بالكامل بالـ Controllers والـ Validation
  Future<void> _showPageRangeDialogBeforeGenerate() async {
    if (_selectedTypes.isEmpty || widget.fileId == null || widget.filesService == null || _isLoading) return;

    int fromPage = _selectedFromPage ?? 1;
    int toPage = _selectedToPage ?? (_totalPages > 0 ? _totalPages : 1);

    _fromController.text = '$fromPage';
    _toController.text = '$toPage';

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            isArabic ? 'اختر نطاق الصفحات للأسئلة' : 'Select Page Range for Questions',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _totalPages > 0
                      ? '${isArabic ? 'إجمالي صفحات المستند' : 'Total document pages'}: $_totalPages'
                      : (isArabic ? 'تعذر تحديد عدد الصفحات' : 'Page count unavailable'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _totalPages > 0 ? const Color(0xFF6366F1) : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(isArabic ? 'من الصفحة' : 'From Page', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 8),
              _buildPageCounterRow(
                value: fromPage, min: 1, max: toPage, controller: _fromController,
                onChanged: (val) => fromPage = val,
                onDecrement: () => setStateDialog(() { if (fromPage > 1) { fromPage--; _fromController.text = '$fromPage'; } }),
                onIncrement: () => setStateDialog(() { if (fromPage < toPage) { fromPage++; _fromController.text = '$fromPage'; } }),
              ),
              const SizedBox(height: 20),
              Text(isArabic ? 'إلى الصفحة' : 'To Page', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 8),
              _buildPageCounterRow(
                value: toPage, min: fromPage, max: _totalPages > 0 ? _totalPages : 9999, controller: _toController,
                onChanged: (val) => toPage = val,
                onDecrement: () => setStateDialog(() { if (toPage > fromPage) { toPage--; _toController.text = '$toPage'; } }),
                onIncrement: () => setStateDialog(() { if (_totalPages == 0 || toPage < _totalPages) { toPage++; _toController.text = '$toPage'; } }),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isArabic ? 'إلغاء' : 'Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                int finalFrom = int.tryParse(_fromController.text) ?? fromPage;
                int finalTo = int.tryParse(_toController.text) ?? toPage;

                if (finalFrom < 1 || (_totalPages > 0 && finalFrom > _totalPages)) {
                  _showErrorSnackBar(isArabic ? 'رقم بداية الصفحة غير صحيح!' : 'Invalid start page!');
                  return;
                }
                if (finalTo < finalFrom || (_totalPages > 0 && finalTo > _totalPages)) {
                  _showErrorSnackBar(isArabic ? 'رقم نهاية الصفحة غير صحيح!' : 'Invalid end page!');
                  return;
                }
                Navigator.pop(ctx, {'from': finalFrom, 'to': finalTo});
              },
              child: Text(isArabic ? 'توليد' : 'Generate'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedFromPage = result['from'];
        _selectedToPage = result['to'];
      });
      await _generate(); // المضي قدماً في التوليد بعد تأكيد النطاق
    }
  }

  // الـ Helper Widget المخصص لبناء صف عداد الصفحات مع الحاوية المتدرجة
  Widget _buildPageCounterRow({
    required int value, required int min, required int max,
    required TextEditingController controller, required ValueChanged<int> onChanged,
    required VoidCallback onDecrement, required VoidCallback onIncrement,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: value > min ? onDecrement : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          color: const Color(0xFF6366F1), iconSize: 28,
        ),
        Container(
          width: 80, padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: TextField(
            controller: controller, keyboardType: TextInputType.number, textAlign: TextAlign.center, cursorColor: Colors.white,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
            onChanged: (text) {
              if (text.isEmpty) return;
              int? parsed = int.tryParse(text);
              if (parsed != null) onChanged(parsed);
            },
          ),
        ),
        IconButton(
          onPressed: (_totalPages == 0 || value < max) ? onIncrement : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: const Color(0xFF6366F1), iconSize: 28,
        ),
      ],
    );
  }

  Future<void> _generate() async {
    if (widget.fileId == null) {
      await _changeActiveFile();
      // لو لسه مفيش ملف بعد الاختيار، وقف
      if (widget.fileId == null) {
        _showErrorSnackBar(
          isArabic
              ? 'يجب اختيار مستند أولاً قبل توليد الأسئلة'
              : 'Please select a document first',
        );
        return;
      }
    }
    setState(() {
      _isLoading = true;
      widget.onStatusChanged(true);
    });

    _cancelToken = CancelToken();

    try {
      for (final entry in _selectedTypes.entries) {
        if (_cancelToken?.isCancelled == true) break;

        final typeValue = entry.key;
        final count     = entry.value;
        final specDiff  = _typeDifficulties[typeValue] ?? 'medium';

        // تمرير الـ from_page والـ to_page بشكل متطور إلى السيرفر
        final rawQuestions = await _examService.generateQuestions(
          fileId:     widget.fileId!,
          type:       _mapType(typeValue),
          difficulty: specDiff,
          count:      count,
          fromPage:   _selectedFromPage,
          toPage:     _selectedToPage,
        );

        if (rawQuestions != null && rawQuestions.trim().isNotEmpty) {
          final List<Map<String, String>> parsedList = parseQuestions(
            rawQuestions,
            _mapType(typeValue),
            specDiff,
          );

          for (final q in parsedList) {
            ExamStore.addQuestion(ExamQuestion(
              id:         DateTime.now().microsecondsSinceEpoch.toString() + q['question'].hashCode.toString(),
              question:   q['question'] ?? '',
              answer:     q['answer'] ?? '',
              type:       _mapType(typeValue),
              difficulty: specDiff,
            ));
          }
        }
      }

      final activeSheet = ExamStore.activeOrNull;
      if (activeSheet?.dbId != null) {
        final questionsToSave = ExamStore.questions.map((q) => q.toMap()).toList();
        await _examService.update(activeSheet!.dbId!, questionsToSave);
      }

    } catch (e) {
      debugPrint('Error during generation: $e');
    } finally {
      setState(() {
        _isLoading = false;
        widget.onStatusChanged(false);
      });
      widget.onGenerated();
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(message))]),
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Color _getDifficultyColor(String diff) {
    if (diff == 'easy') return const Color(0xFF10B981);
    if (diff == 'medium') return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IgnorePointer(
            ignoring: _isLoading,
            child: GestureDetector(
              onTap: _changeActiveFile,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isLoading ? 0.6 : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF6366F1).withOpacity(0.1), const Color(0xFF6366F1).withOpacity(0.04)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.25), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? 'المستند المختار حالياً' : 'Active Document',
                              style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2), // ✅ أضف دي
                            Text(
                              // ✅ أضف دي — بيعرض اسم الملف أو رسالة لو مفيش
                              widget.fileName ?? (isArabic ? 'اضغط لاختيار مستند' : 'Tap to select a document'),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.swap_horizontal_circle_rounded, color: const Color(0xFF6366F1).withOpacity(0.8), size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          Row(
            children: [
              Text(isArabic ? 'أنماط وصعوبة الأسئلة' : 'Question Types & Difficulties', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_totalCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    isArabic ? 'الإجمالي: $_totalCount سؤال' : 'Total: $_totalCount Qs',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          IgnorePointer(
            ignoring: _isLoading,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isLoading ? 0.7 : 1.0,
              child: Column(
                children: _filteredQuestionTypes.map((t) {
                  final value    = t['value'] as String;
                  final label    = isArabic ? t['labelAr'] as String : t['labelEn'] as String;
                  final icon     = t['icon'] as IconData;

                  final selected = _selectedTypes.containsKey(value);
                  final count    = _selectedTypes[value] ?? 3;
                  final currentDiff = _typeDifficulties[value] ?? 'medium';
                  final diffColor = _getDifficultyColor(currentDiff);

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF6366F1).withOpacity(isDark ? 0.05 : 0.02) : theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? const Color(0xFF6366F1).withOpacity(0.4) : theme.dividerColor.withOpacity(0.08),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    // ✅ شلنا InkWell من هنا — بقى بس padding عادي
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          // ✅ الـ tap بقى بس على الـ checkbox + الأيقونة + النص
                          GestureDetector(
                            onTap: () => _toggleTypeSelection(value),
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selected ? const Color(0xFF6366F1) : Colors.transparent,
                                    border: Border.all(
                                      color: selected ? const Color(0xFF6366F1) : Colors.grey.withOpacity(0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFF6366F1).withOpacity(0.12)
                                        : theme.dividerColor.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(icon, size: 18,
                                      color: selected ? const Color(0xFF6366F1) : Colors.grey[500]),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                    color: selected ? const Color(0xFF6366F1) : null,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(), // ✅ يدفع الـ difficulty والـ counter لليمين

                          if (selected) ...[
                            PopupMenuButton<String>(
                              tooltip: isArabic ? 'اختر الصعوبة' : 'Select Difficulty',
                              offset: const Offset(0, 36),
                              borderRadius: BorderRadius.circular(14),
                              color: isDark ? const Color(0xFF262626) : Colors.white,
                              elevation: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: diffColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: diffColor.withOpacity(0.25), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                        width: 7, height: 7,
                                        decoration: BoxDecoration(color: diffColor, shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text(
                                      currentDiff == 'easy'
                                          ? (isArabic ? 'سهل' : 'Easy')
                                          : currentDiff == 'medium'
                                          ? (isArabic ? 'متوسط' : 'Medium')
                                          : (isArabic ? 'صعب' : 'Hard'),
                                      style: TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w700, color: diffColor),
                                    ),
                                  ],
                                ),
                              ),
                              onSelected: (String newDiff) {
                                setState(() => _typeDifficulties[value] = newDiff);
                              },
                              itemBuilder: (BuildContext context) => [
                                _buildPopupItem('easy', isArabic ? 'سهل' : 'Easy', const Color(0xFF10B981)),
                                _buildPopupItem('medium', isArabic ? 'متوسط' : 'Medium', const Color(0xFFF59E0B)),
                                _buildPopupItem('hard', isArabic ? 'صعب' : 'Hard', const Color(0xFFEF4444)),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildCounterButton(
                                  icon: Icons.remove_rounded,
                                  enabled: count > 1,
                                  theme: theme,
                                  onTap: () => _updateCount(value, count - 1),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 54,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$count',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _buildCounterButton(
                                  icon: Icons.add_rounded,
                                  enabled: count < 50,
                                  theme: theme,
                                  onTap: () => _updateCount(value, count + 1),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_selectedTypes.isEmpty || _isLoading) ? null : _showPageRangeDialogBeforeGenerate, // ✅ استدعاء ديالوج اختيار الصفحات أولاً
              icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
              ),
              label: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text(isArabic ? 'توليد ورقة الامتحان الذكية' : 'Generate Smart Exam', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // الـ Counter Button الفخم المطابق تماماً لصفحة الأسئلة بدعم الـ Enabled/Disabled والـ الحواف المنحنية المتقنة
  Widget _buildCounterButton({required IconData icon, required bool enabled, required ThemeData theme, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF6366F1).withOpacity(0.1) : theme.dividerColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: enabled ? const Color(0xFF6366F1).withOpacity(0.4) : theme.dividerColor.withOpacity(0.2)),
        ),
        child: Icon(icon, size: 18, color: enabled ? const Color(0xFF6366F1) : Colors.grey[400]),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, String text, Color color) {
    return PopupMenuItem<String>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}