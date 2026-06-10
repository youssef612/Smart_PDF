// lib/pages/exam_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'exam_models.dart';
import 'widgets/pdf_export.dart';
import 'widgets/word_export.dart';
import 'widgets/math_markdown.dart';

// ─────────────────────────────────────────────────────────────
//  ExamPage
// ─────────────────────────────────────────────────────────────
class ExamPage extends StatefulWidget {
  final bool isArabic;
  const ExamPage({Key? key, required this.isArabic}) : super(key: key);

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  bool get isArabic => widget.isArabic;

  final TextEditingController _titleCtrl =
  TextEditingController(text: 'Exam');
  final TextEditingController _subjectCtrl  = TextEditingController();
  final TextEditingController _durationCtrl = TextEditingController();
  bool _showAnswerKey = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  List<Map<String, String>> _questionsAsMap() {
    return ExamStore.questions.map((q) => {
      'question':   q.question,
      'answer':     q.answer,
      'type':       q.type,
      'difficulty': q.difficulty,
    }).toList();
  }

  void _showExportSheet() {
    final theme     = Theme.of(context);
    final examTitle = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : (isArabic ? 'امتحان' : 'Exam');

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
                width: 40, height: 4,
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
                        colors: [Color(0xFFF59E0B), Color(0xFFFC8A00)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.ios_share_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
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
            Text(
              isArabic
                  ? 'اختر صيغة الملف للتصدير'
                  : 'Choose the file format to export',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
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
              subtitle: isArabic
                  ? 'ملف Word قابل للتعديل'
                  : 'Editable Word document',
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _removeQuestion(int index) =>
      setState(() => ExamStore.questions.removeAt(index));

  void _reorderQuestions(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = ExamStore.questions.removeAt(oldIndex);
      ExamStore.questions.insert(newIndex, item);
    });
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
   constraints: const BoxConstraints(maxWidth: 480),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isArabic ? 'مسح الامتحان؟' : 'Clear Exam?'),
        content: Text(isArabic
            ? 'هيتم حذف كل الأسئلة من ورقة الامتحان'
            : 'All questions will be removed from the exam sheet'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => ExamStore.clear());
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isArabic ? 'مسح' : 'Clear',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _diffColor(String diff) {
    if (diff == 'easy'   || diff == 'سهل')   return const Color(0xFF10B981);
    if (diff == 'medium' || diff == 'متوسط') return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  MarkdownStyleSheet _mdStyle(ThemeData theme, {double fontSize = 14}) {
    const baseColor = Color(0xFF6366F1);
    final base = theme.textTheme.bodyMedium?.copyWith(
      height: 1.7,
      fontSize: fontSize,
      letterSpacing: 0.1,
    ) ??
        TextStyle(fontSize: fontSize, height: 1.7);

    return MarkdownStyleSheet(
      p: base,
      strong: base.copyWith(fontWeight: FontWeight.bold, color: baseColor),
      em:     base.copyWith(fontStyle: FontStyle.italic),
      listBullet: base.copyWith(color: const Color(0xFF10B981)),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: fontSize - 2,
        backgroundColor: const Color(0x146366F1),
        color: baseColor,
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0x0D6366F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x266366F1)),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquote: base.copyWith(
          fontStyle: FontStyle.italic, color: Colors.grey[600]),
      blockquoteDecoration: BoxDecoration(
        border: const Border(
            left: BorderSide(color: Color(0x8010B981), width: 3)),
        color: const Color(0x0A10B981),
        borderRadius: const BorderRadius.only(
          topRight:    Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      blockquotePadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      pPadding: const EdgeInsets.symmetric(vertical: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final questions = ExamStore.questions;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            isArabic ? 'ورقة الامتحان' : 'Exam Sheet',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          elevation: 0,
          backgroundColor: theme.cardColor,
          actions: [
            if (questions.isNotEmpty)
              IconButton(
                onPressed: _showExportSheet,
                icon: const Icon(Icons.ios_share_rounded),
                color: const Color(0xFFF59E0B),
                tooltip: isArabic ? 'تصدير' : 'Export',
              ),
            if (questions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.delete_sweep_rounded,
                      color: Colors.red),
                  tooltip: isArabic ? 'مسح الكل' : 'Clear all',
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed:
                questions.isEmpty ? null : () => _previewExam(context),
                icon: Icon(Icons.visibility_rounded,
                    size: 18,
                    color: questions.isEmpty
                        ? Colors.grey
                        : const Color(0xFF6366F1)),
                label: Text(
                  isArabic ? 'معاينة' : 'Preview',
                  style: TextStyle(
                    color: questions.isEmpty
                        ? Colors.grey
                        : const Color(0xFF6366F1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: questions.isEmpty
                      ? Colors.grey.withOpacity(0.08)
                      : const Color(0xFF6366F1).withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ),
        body: questions.isEmpty
            ? _buildEmptyState(theme)
            : Column(
          children: [
            // ── Exam info card ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF59E0B), Color(0xFFFC8A00)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.assignment_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _titleCtrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: isArabic ? 'اسم الامتحان' : 'Exam title',
                            hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.6)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isArabic
                              ? '${questions.length} سؤال'
                              : '${questions.length} Q',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
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
                          hint: isArabic ? 'المادة...' : 'Subject...',
                          icon: Icons.book_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildExamInfoField(
                          ctrl: _durationCtrl,
                          hint: isArabic ? 'المدة (دقيقة)' : 'Duration (min)',
                          icon: Icons.timer_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(
                                  () => _showAnswerKey = !_showAnswerKey),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _showAnswerKey
                                  ? Colors.white.withOpacity(0.25)
                                  : Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showAnswerKey
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _showAnswerKey
                                        ? (isArabic
                                        ? 'إخفاء الإجابات'
                                        : 'Hide Answers')
                                        : (isArabic
                                        ? 'إظهار الإجابات'
                                        : 'Show Answers'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _showExportSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.ios_share_rounded,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                isArabic ? 'تصدير' : 'Export',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.drag_indicator_rounded,
                      size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 6),
                  Text(
                    isArabic
                        ? 'اسحب لإعادة ترتيب الأسئلة'
                        : 'Drag to reorder questions',
                    style:
                    TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: questions.length,
                onReorder: _reorderQuestions,
                itemBuilder: (ctx, i) {
                  final q  = questions[i];
                  final dc = _diffColor(q.difficulty);

                  final questionStyle =
                      theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                        fontSize: 14,
                      ) ??
                          const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.6);

                  final answerStyle =
                      theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        height: 1.5,
                        fontSize: 12,
                      ) ??
                          TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              height: 1.5);

                  return Container(
                    key: ValueKey('q_${i}_${q.question.hashCode}'),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Number badge
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFFF59E0B),
                                Color(0xFFFC8A00),
                              ]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _tag(q.difficulty, dc),
                                    const SizedBox(width: 6),
                                    _tag(q.type, const Color(0xFF6366F1)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // ✅ MathMarkdown بدل MarkdownBody
                                MathMarkdown(
                                  data: q.question,
                                  style: questionStyle,
                                  styleSheet: _mdStyle(theme)
                                      .copyWith(p: questionStyle),
                                ),
                                if (_showAnswerKey &&
                                    q.answer.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981)
                                          .withOpacity(0.06),
                                      borderRadius:
                                      BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xFF10B981)
                                              .withOpacity(0.2)),
                                    ),
                                    // ✅ MathMarkdown بدل MarkdownBody
                                    child: MathMarkdown(
                                      data: q.answer,
                                      style: answerStyle,
                                      styleSheet: _mdStyle(theme,
                                          fontSize: 12)
                                          .copyWith(p: answerStyle),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Delete button
                          IconButton(
                            onPressed: () => _removeQuestion(i),
                            icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                size: 20,
                                color: Colors.red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );

  Widget _buildExamInfoField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
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
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.55), fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_outlined,
                size: 52, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(height: 24),
          Text(
            isArabic ? 'ورقة الامتحان فاضية' : 'Exam sheet is empty',
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 10),
          Text(
            isArabic
                ? 'ارجع لصفحة التوليد واضغط\n"أضف للامتحان" على أي سؤال'
                : 'Go back to the generator\nand tap "Add to Exam" on any question',
            textAlign: TextAlign.center,
            style:
            theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label:
            Text(isArabic ? 'رجوع للتوليد' : 'Back to Generator'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  void _previewExam(BuildContext context) {
    final theme     = Theme.of(context);
    final questions = ExamStore.questions;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  children: [
                    Text(
                      _titleCtrl.text.isNotEmpty
                          ? _titleCtrl.text
                          : (isArabic ? 'امتحان' : 'Exam'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      textAlign: TextAlign.center,
                    ),
                    if (_subjectCtrl.text.isNotEmpty ||
                        _durationCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_subjectCtrl.text.isNotEmpty)
                            Text(_subjectCtrl.text,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 13)),
                          if (_subjectCtrl.text.isNotEmpty &&
                              _durationCtrl.text.isNotEmpty)
                            Text('  •  ',
                                style: TextStyle(color: Colors.grey[400])),
                          if (_durationCtrl.text.isNotEmpty)
                            Text(
                              isArabic
                                  ? '${_durationCtrl.text} دقيقة'
                                  : '${_durationCtrl.text} min',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 13),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey.shade200),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 8),
                  itemCount: questions.length,
                  itemBuilder: (ctx, i) {
                    final q = questions[i];

                    final previewQuestionStyle =
                        theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.6,
                          fontSize: 14,
                        ) ??
                            const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.6);

                    final previewAnswerStyle =
                        theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          height: 1.5,
                          fontSize: 12,
                        ) ??
                            TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                height: 1.5);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ Row مع رقم السؤال + MathMarkdown بدون Expanded
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${i + 1}. ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                              Flexible(
                                child: MathMarkdown(
                                  data: q.question,
                                  style: previewQuestionStyle,
                                  styleSheet: _mdStyle(theme)
                                      .copyWith(p: previewQuestionStyle),
                                ),
                              ),
                            ],
                          ),
                          if (_showAnswerKey && q.answer.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.07),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFF10B981)
                                        .withOpacity(0.2)),
                              ),
                              child: MathMarkdown(
                                data: q.answer,
                                style: previewAnswerStyle,
                                styleSheet: _mdStyle(theme, fontSize: 12)
                                    .copyWith(p: previewAnswerStyle),
                              ),
                            ),
                          ] else if (!_showAnswerKey) ...[
                            const SizedBox(height: 8),
                            Container(
                              height: 36,
                              decoration: BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: Colors.grey.shade300)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: color.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}