// lib/pages/questions_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_page.dart';
import 'widgets/interactive_scale.dart';
import 'package:dio/dio.dart';

import 'package:flutter/services.dart';
import '../utils/responsive.dart';

import 'package:flutter_markdown/flutter_markdown.dart';
import 'widgets/math_markdown2.dart';
import 'widgets/pdf_export.dart';
import 'widgets/word_export.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/history_store.dart';
import 'package:project_flutter/services/files_service.dart';
import 'exam_models.dart';
import 'exam_page.dart';
import 'home_page.dart';

export 'exam_models.dart';
export 'exam_page.dart';

// ─── color helpers ───────────────────────────────────────────
Color _difficultyColor(String rawDifficulty) {
  switch (rawDifficulty.toLowerCase().trim()) {
    case 'easy':
      return const Color(0xFF10B981);
    case 'medium':
      return const Color(0xFFF59E0B);
    case 'hard':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF6366F1);
  }
}

String _preprocessQuestionText(String text) {
  // [fix] وصّل السطور المكسورة زي: e^{\n-x} أو g(x)=e^{\n-x}
  text = text.replaceAllMapped(
    RegExp(r'(\w\^\{[^}\n]*)\n([^}\n]*\})'),
    (m) => '${m[1]}${m[2]}',
  );
  text = text.replaceAllMapped(
    RegExp(r'(\\\w+\{[^}\n]*)\n([^}\n]*\})'),
    (m) => '${m[1]}${m[2]}',
  );

  final lines  = text.split('\n');
  final result = <String>[];
  bool inFence = false;

  for (final line in lines) {
    final trimmed = line.trim();

    if (trimmed.startsWith('```')) {
      inFence = !inFence;
      result.add(line);
      continue;
    }
    if (inFence) { result.add(line); continue; }

    // [fix] سطر بيبدأ بـ closing brace → وصّله بالسابق
    if (RegExp(r'^-?[a-zA-Z0-9]\s*\}').hasMatch(trimmed) && result.isNotEmpty) {
      for (int i = result.length - 1; i >= 0; i--) {
        if (result[i].trim().isNotEmpty) {
          result[i] = result[i].trimRight() + trimmed;
          break;
        }
      }
      continue;
    }

    // سطر فيه bare LaTeX خارج $ → لفّه في $$
    final hasBareLatex = _hasBareLatexOutsideDelimiters(trimmed);
    if (hasBareLatex && trimmed.isNotEmpty) {
      final cleaned = _stripOrphanDollars(trimmed);
      result.add('\$\$$cleaned\$\$');
      continue;
    }

    // سطر فيه $ بالفعل وسليم → اتركه
    if (trimmed.contains(r'$')) {
      result.add(line);
      continue;
    }

    // سطر فيه LaTeX commands بدون $ → لفّه في $$
    final hasLatex = RegExp(
      r'\\(?:phi|psi|int|frac|sqrt|sum|prod|lim|partial|'
      r'lambda|mu|sigma|theta|pi|alpha|beta|gamma|delta|'
      r'omega|nabla|infty|cdot|times|text|mathbf|vec|hat|'
      r'left|right|begin|end)\b',
    ).hasMatch(trimmed);

    final isCodeLine = RegExp(
      r'^\s*(?:def |class |import |function |const |let |var |'
      r'#include|cout|printf|public |private )',
    ).hasMatch(trimmed);

    if (hasLatex && !isCodeLine && trimmed.isNotEmpty) {
      result.add('\$\$$trimmed\$\$');
      continue;
    }

    result.add(line);
  }

  return result.join('\n');
}

// ── helpers ──────────────────────────────────────────────────

/// يشوف لو السطر فيه \command برة أي $ delimiter
bool _hasBareLatexOutsideDelimiters(String line) {
  // إزالة كل اللي جوه $...$ أو $$...$$
  String stripped = line
      .replaceAll(RegExp(r'\$\$[^$]*\$\$'), '')
      .replaceAll(RegExp(r'\$[^$\n]*\$'), '');
  // لو لسه فيه \command → فيه bare LaTeX
  return RegExp(
    r'\\(?:phi|psi|lambda|mu|sigma|theta|int|frac|sqrt|'
    r'sum|partial|alpha|beta|gamma|delta|omega|cdot|times|'
    r'left|right|infty|nabla|vec|hat|bar)\b'
  ).hasMatch(stripped);
}

/// يشيل الـ $ المنفردة اللي مش بتعمل pair صح
String _stripOrphanDollars(String line) {
  // عد الـ $ — لو عددهم فردي → فيه orphan
  // الحل: شيل كل $ منفردة (مش $$)
  return line
      .replaceAll(RegExp(r'(?<!\$)\$(?!\$)'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}
Color _typeColor(String rawType) {
  switch (rawType.toLowerCase().trim()) {
    case 'multiple':
    case 'multiple_choice':
      return const Color(0xFF6366F1);
    case 'truefalse':
    case 'true_false':
      return const Color(0xFF10B981);
    default:
      return const Color(0xFFF59E0B);
  }
}

// ─── latex fixers ────────────────────────────────────────────
String _fixLatexSpacing(String raw) {
  String s = raw
      .replaceAllMapped(RegExp(r'(\S)\$\$'), (m) => '${m[1]} \$\$')
      .replaceAllMapped(RegExp(r'\$\$(\S)'), (m) => '\$\$ ${m[1]}');

  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (s[i] == '\$' && (i + 1 >= s.length || s[i + 1] != '\$')) {
      final before = i > 0 ? s[i - 1] : ' ';
      final after = i + 1 < s.length ? s[i + 1] : ' ';
      if (after == '\\') {
        buf.write('\$');
        continue;
      }
      final needBefore = before != ' ' && before != '\n' && before != '\$';
      final needAfter = after != ' ' && after != '\n' && after != '\$';
      if (needBefore) buf.write(' ');
      buf.write('\$');
      if (needAfter) buf.write(' ');
    } else {
      buf.write(s[i]);
    }
  }
  return buf.toString();
}

String _fixBrokenLatex(String text) {
  return text
      .replaceAllMapped(
        RegExp(r'([a-zA-Z])_(\d+)_\{([^}]+)\}'),
        (m) => '${m[1]}_{${m[2]},${m[3]}}',
      )
      .replaceAllMapped(
        RegExp(r'([a-zA-Z])_(\d+)_([a-zA-Z]+)'),
        (m) => '${m[1]}_{${m[2]},${m[3]}}',
      );
}

/// بس لـ multiple_choice — مش للـ matching أو ordering
String _fixMCQOptions(String text) {
  return text
      .replaceAllMapped(
        RegExp(r'(?<!\n)([A-D])\)\s+(?![a-z])'),
        (m) => '\n\n${m[1]}) ',
      )
      .replaceAll(RegExp(r'\?\s*\n\nA\)'), '\n\nA)')
      .trim();
}

// ═══════════════════════════════════════════════════════════════
//  Question Parser — supports all 12 types
// ═══════════════════════════════════════════════════════════════

/// أنواع الأسئلة اللي بيتعامل معاها الـ parser
enum _QType {
  multipleChoice,
  trueFalse,
  shortAnswer,
  essay,
  fillBlank,
  matching,
  ordering,
  definition,
  diagram,
  calculation,
  compare,
  caseStudy,
  unknown,
}

_QType _detectType(String typeStr) {
  switch (typeStr.toLowerCase().trim()) {
    case 'multiple':
    case 'multiple_choice':
      return _QType.multipleChoice;
    case 'truefalse':
    case 'true_false':
      return _QType.trueFalse;
    case 'short':
    case 'short_answer':
      return _QType.shortAnswer;
    case 'essay':
      return _QType.essay;
    case 'fill':
    case 'fill_blank':
      return _QType.fillBlank;
    case 'matching':
      return _QType.matching;
    case 'ordering':
      return _QType.ordering;
    case 'definition':
      return _QType.definition;
    case 'diagram':
      return _QType.diagram;
    case 'calculation':
      return _QType.calculation;
    case 'compare':
      return _QType.compare;
    case 'casestudy':
    case 'case_study':
      return _QType.caseStudy;
    default:
      return _QType.unknown;
  }
}

/// يقسم section واحدة لـ question + answer
/// بيتعامل مع كل الأنواع بدون ما يكسر structure الـ matching أو table
Map<String, String> _splitSection(String section, String rawType) {
  // شيل ## Question N header
  String body = section
      .replaceAll(RegExp(r'#{0,2}QSEP##', caseSensitive: false), '')
      .replaceFirst(
        RegExp(
          r'^##\s*Question\s*\d+[^\n]*\n?',
          caseSensitive: false,
          multiLine: true,
        ),
        '',
      )
      .trim();

  // الـ answer separator — دايماً **Answer:** على سطر لوحده
  final answerPatterns = [
    RegExp(r'^\*\*Answer:\*\*', caseSensitive: false, multiLine: true),
    RegExp(r'^\*\*Answer\*\*\s*:', caseSensitive: false, multiLine: true),
    RegExp(r'^\*\*الإجابة:\*\*', multiLine: true),
    RegExp(r'^\*\*الإجابة\*\*\s*:', multiLine: true),
    RegExp(r'^الإجابة\s*:', multiLine: true),
    RegExp(r'^الجواب\s*:', multiLine: true),
    RegExp(r'^\*\*Answer\b', caseSensitive: false, multiLine: true),
  ];

  for (final pat in answerPatterns) {
    final match = pat.firstMatch(body);
    if (match != null) {
      final qPart = body.substring(0, match.start).trim();
      final aPart = body.substring(match.start).trim();
      if (qPart.isEmpty) continue;
      return {
        'question': _cleanQuestion(qPart, rawType),
        'answer': _cleanAnswer(aPart),
      };
    }
  }

  // مفيش separator → كل النص question
  return {'question': _cleanQuestion(body, rawType), 'answer': ''};
}

String _cleanQuestion(String text, String rawType) {
  text = text
      .replaceAll(
        RegExp(
          r'(?:Type|Difficulty|Topic|Question):[^\n]*\n?',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
  text = _fixLatexSpacing(_fixBrokenLatex(text));
  // بس لـ multiple_choice نفصل الـ options
  if (_detectType(rawType) == _QType.multipleChoice) {
    text = _fixMCQOptions(text);
  }
  return text
      .replaceAll(RegExp(r'#{0,2}QSEP##', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bQSEP\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

String _cleanAnswer(String text) {
  return _fixLatexSpacing(_fixBrokenLatex(text))
      .replaceAll(RegExp(r'#{0,2}QSEP##', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bQSEP\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

// ─── main parser ─────────────────────────────────────────────

List<Map<String, String>> parseQuestions(
  String raw,
  String rawType,
  String difficulty,
) {
  if (raw.trim().isEmpty) return [];

  // شيل code fences
  String cleaned = raw
      .replaceAll(RegExp(r'^```[\w]*\n?', multiLine: true), '')
      .replaceAll(RegExp(r'```$', multiLine: true), '')
      .trim();

  List<String> sections;

  // محاولة 1: QSEP separator
  if (cleaned.contains('QSEP##')) {
    sections = cleaned
        .split(RegExp(r'#{0,2}QSEP##', caseSensitive: false))
        .map((e) => e.trim())
        .where(
          (e) =>
              e.isNotEmpty &&
              RegExp(r'##\s*Question\s*\d+', caseSensitive: false).hasMatch(e),
        )
        .toList();
  } else {
    // محاولة 2: split على ## Question N
    sections = [];
    final matches = RegExp(
      r'(?=##\s*Question\s*\d+)',
      caseSensitive: false,
    ).allMatches(cleaned);
    final positions = [0, ...matches.map((m) => m.start), cleaned.length];
    for (int i = 0; i < positions.length - 1; i++) {
      final sec = cleaned.substring(positions[i], positions[i + 1]).trim();
      if (sec.isNotEmpty &&
          RegExp(r'##\s*Question\s*\d+', caseSensitive: false).hasMatch(sec)) {
        sections.add(sec);
      }
    }
  }

  // fallback: regex كل question block
  if (sections.isEmpty) {
    final regex = RegExp(
      r'##\s*Question\s*\d+[\s\S]*?(?=##\s*Question\s*\d+|$)',
      caseSensitive: false,
    );
    sections = regex
        .allMatches(cleaned)
        .map((m) => m.group(0)!.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  final List<Map<String, String>> result = [];
  for (final sec in sections) {
    final parts = _splitSection(sec, rawType);
    final q = (parts['question'] ?? '').trim();
    if (q.isEmpty) continue;
    result.add({
      'question': q,
      'answer': (parts['answer'] ?? '').trim(),
      'type': rawType,
      'difficulty': difficulty,
    });
  }
  return result;
}

// ═══════════════════════════════════════════════════════════════
//  QuestionsPage
// ═══════════════════════════════════════════════════════════════

class QuestionsPage extends StatefulWidget {
  final String? fileName;
  final String? fileId;
  final List? questions;
  final int pageCount;
  final String? questionType;
  final String? difficulty;
  final int? fromPage;
  final int? toPage;
  final FilesService filesService;

  const QuestionsPage({
    Key? key,
    this.fileName,
    this.fileId,
    this.questions,
    this.pageCount = 0,
    this.questionType, // ✅ أضف
    this.difficulty,
    this.fromPage,
    this.toPage,
    required this.filesService,
  }) : super(key: key);

  @override
  State<QuestionsPage> createState() => _QuestionsPageState();
}

class _QuestionsPageState extends State<QuestionsPage>
    with SingleTickerProviderStateMixin {
  String _selectedQuestionType = 'multiple';
  String _selectedDifficulty = 'medium';
  int _questionCount = 5;

  static const int _maxQuestions = 50;

  bool _isGenerating = false;
  List<Map<String, String>> _generatedQuestions = [];

  String? _activeFileName;
  String? _activeFileId;

  int? _selectedFromPage;
  int? _selectedToPage;
  int _totalPages = 0;

  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  late String _currentLanguage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ApiService _apiService = ApiService();

  CancelToken? _cancelToken;

  final List<Map<String, dynamic>> _difficulties = [
    {'value': 'easy', 'label': 'easy', 'color': const Color(0xFF10B981)},
    {'value': 'medium', 'label': 'medium', 'color': const Color(0xFFF59E0B)},
    {'value': 'hard', 'label': 'hard', 'color': const Color(0xFFEF4444)},
  ];

  String get _selectedTypeLabel {
    final match = kQuestionTypes.firstWhere(
      (t) => t['value'] == _selectedQuestionType,
      orElse: () => kQuestionTypes.first,
    );
    return isArabic ? match['labelAr'] as String : match['labelEn'] as String;
  }

  IconData get _selectedTypeIcon {
    final match = kQuestionTypes.firstWhere(
      (t) => t['value'] == _selectedQuestionType,
      orElse: () => kQuestionTypes.first,
    );
    return match['icon'] as IconData;
  }

  @override
  void initState() {
    super.initState();

    // تهيئة البيانات النشطة من الـ widget الممرر ابتدائياً
    _activeFileName = widget.fileName;
    _activeFileId = widget.fileId;
    _totalPages = widget.pageCount;

    // ── page range محفوظة من history ──
    if (widget.fromPage != null) _selectedFromPage = widget.fromPage;
    if (widget.toPage != null) _selectedToPage = widget.toPage;

    if (widget.questions != null && widget.questions!.isNotEmpty) {
      _generatedQuestions = List<Map<String, String>>.from(
        widget.questions!.map((item) => Map<String, String>.from(item)),
      );
      _questionCount = _generatedQuestions.length;

      // ✅ خد question_type من widget أولاً (جاي من history صح)
      // لو مش موجود → unmap اللي جوه الـ data
      _selectedQuestionType =
          widget.questionType ??
          _unmapType(_generatedQuestions.first['type'] ?? 'multiple');

      // ✅ خد difficulty من widget أولاً
      _selectedDifficulty =
          widget.difficulty ??
          _generatedQuestions.first['difficulty'] ??
          'medium';
    } else {
      // مفيش بيانات محفوظة → خد من widget لو موجود
      if (widget.questionType != null)
        _selectedQuestionType = widget.questionType!;
      if (widget.difficulty != null) _selectedDifficulty = widget.difficulty!;
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

  // ✅ helper لتحويل الـ mapped type لـ short form
  String _unmapType(String mapped) {
    const reverseMap = {
      'multiple_choice': 'multiple',
      'true_false': 'truefalse',
      'short_answer': 'short',
      'fill_blank': 'fill',
      'case_study': 'casestudy',
    };
    return reverseMap[mapped] ?? mapped;
  }

  // ── ميزة تبديل الملف النشط مباشرة من داخل شاشة الأسئلة ──
  Future<void> _changeActiveFile() async {
    if (_isGenerating) {
      _showErrorSnackBar(
        isArabic
            ? 'برجاء الانتظار حتى ينتهي إنشاء الأسئلة الحالية'
            : 'Please wait until the current questions generation is complete',
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => FilePickerDialog(
        filesService: widget.filesService,
        isArabic: isArabic,
        currentFileId: _activeFileId,
        onFileSelected: (fileId, fileName, pageCount) {
          setState(() {
            // 1. تحديث بيانات الملف النشط الجديد
            _activeFileId = fileId;
            _activeFileName = fileName;
            _totalPages = pageCount;

            // 2. إعادة تعيين الخيارات للشكل الافتراضي تماماً
            _selectedQuestionType =
                'multiple'; // النوع الافتراضي (اختيار من متعدد)
            _selectedDifficulty = 'medium'; // المستوى الافتراضي (متوسط)
            _questionCount = 5; // العدد الافتراضي

            // 3. تصفير نطاق الصفحات والأسئلة القديمة بنظافة
            _selectedFromPage = 1;
            _selectedToPage = pageCount > 0 ? pageCount : 1;
            _generatedQuestions = [];
          });
        },
        onFileUploaded: (fileId, fileName, pageCount, isProcessing) {
          setState(() {
            // 1. تحديث بيانات الملف النشط الجديد
            _activeFileId = fileId;
            _activeFileName = fileName;
            _totalPages = pageCount;

            // 2. إعادة تعيين الخيارات للشكل الافتراضي تماماً
            _selectedQuestionType = 'multiple';
            _selectedDifficulty = 'medium';
            _questionCount = 5;

            // 3. تصفير نطاق الصفحات والأسئلة القديمة بنظافة
            _selectedFromPage = 1;
            _selectedToPage = pageCount > 0 ? pageCount : 1;
            _generatedQuestions = [];
          });
        },
        onUploadStart: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'جاري بدء الرفع...' : 'Starting upload...',
            ),
          ),
        ),
        onError: (msg) {
          if (msg.startsWith('__JUST_SAVED_SUCCESS__')) {
            final savedName = msg.split(':')[1];
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isArabic
                      ? '$savedName تم حفظه بنجاح'
                      : '$savedName saved successfully',
                ),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            _showErrorSnackBar(msg);
          }
        },
      ),
    );
  }

  // ── دالة الحماية والتحقق التنبيهي لمنع المغادرة المفاجئة ──
  Future<bool> _onWillPop() async {
    if (!_isGenerating) return true;

    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 26,
            ),
            const SizedBox(width: 10),
            Text(
              isArabic ? 'تنبيه: جاري التحميل' : 'Warning: Generating',
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              // 🔒 إلغاء الـ Request من السيرفر فوراً في الخلفية
              if (_cancelToken != null && !_cancelToken!.isCancelled) {
                _cancelToken!.cancel(
                  isArabic
                      ? 'تم إلغاء العملية بواسطة المستخدم'
                      : 'Cancelled by user',
                );
              }
              Navigator.pop(dialogCtx, true); // اخرج بأمان
            },
            child: Text(isArabic ? 'إلغاء ومغادرة' : 'Cancel & Leave'),
          ),
        ],
      ),
    );

    return shouldCancel ?? false;
  }

  Future<void> _showPageRangeDialog() async {
    int fromPage = _selectedFromPage ?? 1;
    int toPage = _selectedToPage ?? (_totalPages > 0 ? _totalPages : 1);

    // تهيئة النص داخل الـ Controllers قبل فتح الديالوج مباشرة
    _fromController.text = '$fromPage';
    _toController.text = '$toPage';

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            isArabic
                ? 'اختر نطاق الصفحات للأسئلة'
                : 'Select Page Range for Questions',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _totalPages > 0
                      ? '${isArabic ? 'إجمالي صفحات المستند' : 'Total document pages'}: $_totalPages'
                      : (isArabic
                            ? 'تعذر تحديد عدد الصفحات'
                            : 'Page count unavailable'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _totalPages > 0
                        ? const Color(0xFF6366F1)
                        : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── سطر من الصفحة ──
              Text(
                isArabic ? 'من الصفحة' : 'From Page',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              _buildPageCounter(
                value: fromPage,
                min: 1,
                max: toPage, // حماية السهم العلوي
                controller: _fromController,
                onChanged: (val) => fromPage = val,
                onDecrement: () => setStateDialog(() {
                  if (fromPage > 1) {
                    fromPage--;
                    _fromController.text = '$fromPage';
                  }
                }),
                onIncrement: () => setStateDialog(() {
                  if (fromPage < toPage) {
                    fromPage++;
                    _fromController.text = '$fromPage';
                  }
                }),
              ),

              const SizedBox(height: 20),

              // ── سطر إلى الصفحة ──
              Text(
                isArabic ? 'إلى الصفحة' : 'To Page',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              _buildPageCounter(
                value: toPage,
                min: fromPage, // حماية السهم السفلي
                max: _totalPages > 0 ? _totalPages : 9999,
                controller: _toController,
                onChanged: (val) => toPage = val,
                onDecrement: () => setStateDialog(() {
                  if (toPage > fromPage) {
                    toPage--;
                    _toController.text = '$toPage';
                  }
                }),
                onIncrement: () => setStateDialog(() {
                  if (_totalPages == 0 || toPage < _totalPages) {
                    toPage++;
                    _toController.text = '$toPage';
                  }
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                // الفحص الذكي النهائي للمدخلات المكتوبة يدوياً عبر الكيبورد
                int finalFrom = int.tryParse(_fromController.text) ?? fromPage;
                int finalTo = int.tryParse(_toController.text) ?? toPage;

                if (finalFrom < 1 ||
                    (_totalPages > 0 && finalFrom > _totalPages)) {
                  _showErrorSnackBar(
                    isArabic
                        ? 'رقم بداية الصفحة غير صحيح! يجب أن يكون بين 1 و $_totalPages'
                        : 'Invalid start page! Must be between 1 and $_totalPages',
                  );
                  return;
                }

                if (finalTo < finalFrom ||
                    (_totalPages > 0 && finalTo > _totalPages)) {
                  _showErrorSnackBar(
                    isArabic
                        ? 'رقم نهاية الصفحة غير صحيح أو أقل من صفحة البداية!'
                        : 'Invalid end page or less than start page!',
                  );
                  return;
                }

                Navigator.pop(context, {'from': finalFrom, 'to': finalTo});
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
      await _generateQuestions();
    }
  }

  // ── Helper Widget ──
  Widget _buildPageCounter({
    required int value,
    required int min,
    required int max,
    required TextEditingController controller,
    required ValueChanged<int> onChanged,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // زر الناقص (-) الجانبي باللون الأزرق المعتاد
        IconButton(
          onPressed: value > min ? onDecrement : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          color: const Color(0xFF6366F1),
          iconSize: 28,
        ),

        // الحاوية المتدرجة الأنيقة التي بداخلها الحقل الشفاف للكتابة
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            cursorColor: Colors.white,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (text) {
              if (text.isEmpty) return;
              int? parsed = int.tryParse(text);
              if (parsed != null) {
                onChanged(parsed); // تحديث القيمة منطقياً في الخلفية فوراً
              }
            },
          ),
        ),

        // زر الزائد (+) الجانبي
        IconButton(
          onPressed: (_totalPages == 0 || value < max) ? onIncrement : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: const Color(0xFF6366F1),
          iconSize: 28,
        ),
      ],
    );
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
    _currentLanguage = Localizations.localeOf(context).languageCode;
  }

  bool get isArabic => _currentLanguage == 'ar';

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
                  isArabic ? 'تصدير الأسئلة' : 'Export Questions',
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
                PdfExporter.exportQuestions(
                  context: context,
                  questions: _generatedQuestions,
                  fileName: widget.fileName ?? 'Questions',
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
                WordExporter.exportQuestions(
                  context: context,
                  questions: _generatedQuestions,
                  fileName: widget.fileName ?? 'Questions',
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

  void _showTypeDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (ctx, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
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
                          Icons.quiz_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isArabic ? 'نوع السؤال' : 'Question Type',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      physics: const ClampingScrollPhysics(),
                      itemCount: kQuestionTypes.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Colors.grey.withOpacity(0.12),
                      ),
                      itemBuilder: (ctx, i) {
                        final type = kQuestionTypes[i];
                        final isSelected =
                            type['value'] == _selectedQuestionType;
                        final label = isArabic
                            ? type['labelAr'] as String
                            : type['labelEn'] as String;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF6366F1).withOpacity(0.12)
                                  : theme.dividerColor.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              type['icon'] as IconData,
                              size: 20,
                              color: isSelected
                                  ? const Color(0xFF6366F1)
                                  : Colors.grey[500],
                            ),
                          ),
                          title: Text(
                            label,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? const Color(0xFF6366F1)
                                  : theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF6366F1),
                                  size: 22,
                                )
                              : null,
                          onTap: () {
                            setState(
                              () => _selectedQuestionType =
                                  type['value'] as String,
                            );
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String mapType(String type) {
    const map = {
      'multiple': 'multiple_choice',
      'truefalse': 'true_false',
      'short': 'short_answer',
      'essay': 'essay',
      'fill': 'fill_blank',
      'matching': 'matching',
      'ordering': 'ordering',
      'definition': 'definition',
      'diagram': 'diagram',
      'calculation': 'calculation',
      'compare': 'compare',
      'casestudy': 'case_study',
    };
    return map[type] ?? 'multiple_choice';
  }

  Future<String?> _fetchQuestionsWithRetry({
    required int maxRetries,
    int? fromPage,
    int? toPage,
  }) async {
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        _cancelToken = CancelToken();

        final response = await _apiService.dio.post(
          '/files/$_activeFileId/questions',
          cancelToken: _cancelToken,
          data: {
            'type': mapType(_selectedQuestionType),
            'difficulty': _selectedDifficulty.toLowerCase(),
            'count': _questionCount,
            'force_regenerate': true,
            'seed': DateTime.now().millisecondsSinceEpoch,
            if (fromPage != null) 'from_page': fromPage,
            if (toPage != null) 'to_page': toPage,
          },
        );
        if (response.data['success'] == true) {
          debugPrint('=== QUESTIONS RAW RESPONSE ===');
          debugPrint(response.data.toString());
          debugPrint('==============================');
          final raw = response.data['data']['questions'];
          if (raw is String && raw.trim().isNotEmpty) return raw;
        }
      } on DioException catch (e) {
        // 🛑 لقطة ذكية: لو المستخدم لغى بنفسه، ارمي الإيرور برة فوراً عشان نوقف الـ محاولات الـ الـ 3
        if (CancelToken.isCancel(e)) {
          rethrow;
        }
        // لو إيرور تاني (زي الـ 500 اللي في اللوج)، سيبه يكمل الـ Retry عادي
      } catch (_) {}

      attempt++;
      if (attempt < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
    return null;
  }

  Future<void> _generateQuestions() async {
    if (_isGenerating) return;
    if (!mounted) return;

    if (_activeFileId == null) {
      _showErrorSnackBar(isArabic ? 'لم يتم اختيار ملف' : 'No file selected');
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedQuestions = [];
    });

    try {
      final rawQuestions = await _fetchQuestionsWithRetry(
        maxRetries: 3,
        fromPage: _selectedFromPage,
        toPage: _selectedToPage,
      );

      if (!mounted) return;

      if (rawQuestions == null) {
        setState(() => _isGenerating = false);
        _showErrorSnackBar(
          isArabic
              ? 'فشل توليد الأسئلة بعد عدة محاولات'
              : 'Failed to generate questions after retries',
        );
        return;
      }

      final parsed = parseQuestions(
        rawQuestions,
        mapType(_selectedQuestionType),
        _selectedDifficulty,
      );

      if (!mounted) return;
      setState(() {
        _generatedQuestions = parsed;
        _isGenerating = false;
      });

      _animationController.reset();
      _animationController.forward();

      if (_activeFileId != null && parsed.isNotEmpty) {
        await HistoryStore.add({
          'file_id': _activeFileId, // ← التعديل هنا
          'file_name': _activeFileName ?? '', // ← التعديل هنا
          'type': 'questions',
          'question_type': _selectedQuestionType,
          'difficulty': _selectedDifficulty,
          'count': parsed.length,
          'data': parsed,
          'from_page': _selectedFromPage, // ✅ أضف
          'to_page': _selectedToPage,
          'page_count': _totalPages,
          'date': DateTime.now().toIso8601String(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isArabic
                      ? 'تم إنشاء ${parsed.length} سؤال بنجاح'
                      : '${parsed.length} questions generated successfully',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);

      // لو الإلغاء مقصود، اخرج وماتطلعش SnackBar حمراء تبوظ الـ UX
      if (CancelToken.isCancel(e)) {
        debugPrint('Request cancelled cleanly from state.');
        return;
      }

      _showErrorSnackBar(isArabic ? 'حدث خطأ في الاتصال' : 'Connection error');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      _showErrorSnackBar(isArabic ? 'حدث خطأ: $e' : 'Error: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
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
          const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: baseColor,
          ),
      h2:
          theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF8B5CF6),
            letterSpacing: -0.3,
            height: 1.4,
          ) ??
          const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B5CF6),
          ),
      h3:
          theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: baseColor,
            height: 1.4,
          ) ??
          const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: baseColor,
          ),
      p:
          theme.textTheme.bodyMedium?.copyWith(
            height: 1.7,
            letterSpacing: 0.1,
          ) ??
          const TextStyle(fontSize: 14, height: 1.7),
      listBullet:
          theme.textTheme.bodyMedium?.copyWith(
            height: 1.7,
            color: const Color(0xFF10B981),
          ) ??
          const TextStyle(fontSize: 14, color: Color(0xFF10B981)),
      strong:
          theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: baseColor,
          ) ??
          const TextStyle(fontWeight: FontWeight.bold, color: baseColor),
      code: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        backgroundColor: Color(0x146366F1),
        color: baseColor,
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0x0D6366F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x266366F1)),
      ),
      codeblockPadding: const EdgeInsets.all(16),
      blockquote:
          theme.textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
            color: Colors.grey[600],
          ) ??
          const TextStyle(fontStyle: FontStyle.italic),
      blockquoteDecoration: BoxDecoration(
        border: const Border(
          left: BorderSide(color: Color(0x8010B981), width: 4),
        ),
        color: const Color(0x0A10B981),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      pPadding: const EdgeInsets.symmetric(vertical: 2),
      listIndent: 16,
      tableBorder: TableBorder.all(color: const Color(0x336366F1), width: 1),
      tableColumnWidth: const FlexColumnWidth(),
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      tableHead:
          theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: baseColor,
          ) ??
          const TextStyle(fontWeight: FontWeight.bold, color: baseColor),
      tableBody:
          theme.textTheme.bodySmall?.copyWith(height: 1.5) ??
          const TextStyle(fontSize: 12, height: 1.5),
    );
  }

  String locByKey(AppLocalizations loc, String key) {
    switch (key.toLowerCase().trim()) {
      case 'multiple':
      case 'multiple_choice':
        return isArabic ? 'اختيار من متعدد' : 'Multiple Choice';
      case 'truefalse':
      case 'true_false':
        return isArabic ? 'صح أم خطأ' : 'True / False';
      case 'short':
      case 'short_answer':
        return isArabic ? 'إجابة قصيرة' : 'Short Answer';
      case 'essay':
        return isArabic ? 'مقالي' : 'Essay';
      case 'fill':
      case 'fill_blank':
        return isArabic ? 'إملأ الفراغ' : 'Fill in the Blank';
      case 'matching':
        return isArabic ? 'مطابقة' : 'Matching';
      case 'ordering':
        return isArabic ? 'ترتيب' : 'Ordering';
      case 'definition':
        return isArabic ? 'تعريف' : 'Definition';
      case 'diagram':
        return isArabic ? 'رسم بياني' : 'Diagram';
      case 'calculation':
        return isArabic ? 'حساب' : 'Calculation';
      case 'compare':
        return isArabic ? 'مقارنة' : 'Compare';
      case 'casestudy':
      case 'case_study':
        return isArabic ? 'دراسة حالة' : 'Case Study';
      case 'easy':
        return loc.easy;
      case 'medium':
        return loc.medium;
      case 'hard':
        return loc.hard;
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () async {
            // تحسين الـ Shortcut ليمر بنفس حماية الـ PopScope
            final shouldPop = await _onWillPop();
            if (shouldPop && context.mounted) {
              if (Navigator.canPop(context)) Navigator.pop(context);
            }
          },
        },
        child: Focus(
          autofocus: true,
          // ── حماية الشاشة من الخروج المفاجئ أثناء التوليد ──
          child: PopScope(
            canPop:
                !_isGenerating, // يسمح بالخروج التلقائي فقط لو مش شغال توليد
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              appBar: AppBar(
                title: Text(
                  loc.questionsGeneratorTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                elevation: 0,
                backgroundColor: theme.cardColor,
                actions: [
                  if (_activeFileId != null)
                    IconButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            fileId: _activeFileId!,
                            fileName: _activeFileName ?? "",
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.lightbulb_rounded),
                      color: const Color(0xFFFBBF24),
                      tooltip: isArabic ? 'الشات الذكي' : 'Smart Chat',
                    ), // ← تأكد من قفلة القوس هنا
                  if (_generatedQuestions.isNotEmpty)
                    IconButton(
                      onPressed: _showExportSheet,
                      icon: const Icon(Icons.ios_share_rounded),
                      color: const Color(0xFF6366F1),
                      tooltip: isArabic ? 'تصدير' : 'Export',
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12, left: 12),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExamPage(isArabic: isArabic),
                            ),
                          ).then((_) => setState(() {})),
                          icon: const Icon(
                            Icons.assignment_rounded,
                            size: 18,
                            color: Color(0xFFF59E0B),
                          ),
                          label: Text(
                            isArabic ? 'الامتحان' : 'Exam',
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(
                              0xFFF59E0B,
                            ).withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        if (ExamStore.questions.isNotEmpty)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                '${ExamStore.questions.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
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
                                Text(
                                  loc.questionsGeneratorTitle,
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isArabic
                                      ? 'أنشئ أسئلة ذكية من مستنداتك'
                                      : 'Generate smart questions from your documents',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // ── كارت الملف التفاعلي لتبديل الملف بلمسة واحدة ──
                                GestureDetector(
                                  onTap: _changeActiveFile,
                                  child: MouseRegion(
                                    cursor: _isGenerating
                                        ? SystemMouseCursors.basic
                                        : SystemMouseCursors.click,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(
                                              0xFF6366F1,
                                            ).withOpacity(0.12),
                                            const Color(
                                              0xFF8B5CF6,
                                            ).withOpacity(0.06),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF6366F1,
                                          ).withOpacity(0.35),
                                          width: 1.2,
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
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                              _activeFileName ??
                                                  (isArabic
                                                      ? 'لم يتم اختيار ملف'
                                                      : 'No file selected'),
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: -0.3,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          // أيقونة التبديل لإعلام المستخدم بإمكانية الضغط
                                          Icon(
                                            Icons
                                                .swap_horizontal_circle_outlined,
                                            color: const Color(
                                              0xFF6366F1,
                                            ).withOpacity(0.7),
                                            size: 22,
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

                        const SizedBox(height: 12),

                        // ── Configuration Card ──
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
                                            Color(0xFF6366F1),
                                            Color(0xFF8B5CF6),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.tune_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      loc.configuration,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: -0.5,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Question Type
                                Text(
                                  loc.questionType,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                GestureDetector(
                                  onTap: _showTypeDropdown,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF6366F1,
                                      ).withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF6366F1,
                                        ).withOpacity(0.35),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF6366F1,
                                            ).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            _selectedTypeIcon,
                                            size: 18,
                                            color: const Color(0xFF6366F1),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _selectedTypeLabel,
                                            style: const TextStyle(
                                              color: Color(0xFF6366F1),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Color(0xFF6366F1),
                                          size: 22,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 28),

                                // Difficulty
                                Text(
                                  loc.difficultyLevel,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  children: _difficulties.map((d) {
                                    return _buildDifficultyChip(
                                      theme: theme,
                                      label: locByKey(
                                        loc,
                                        d['value'] as String,
                                      ),
                                      value: d['value'] as String,
                                      groupValue: _selectedDifficulty,
                                      color: d['color'] as Color,
                                      onSelected: (val) => setState(
                                        () => _selectedDifficulty = val,
                                      ),
                                    );
                                  }).toList(),
                                ),

                                const SizedBox(height: 28),

                                // Count
                                Text(
                                  isArabic
                                      ? 'عدد الأسئلة'
                                      : 'Number of Questions',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildCounterBtn(
                                      icon: Icons.remove_rounded,
                                      onTap: () {
                                        if (_questionCount > 1)
                                          setState(() => _questionCount--);
                                      },
                                      enabled: _questionCount > 1,
                                      theme: theme,
                                    ),
                                    const SizedBox(width: 20),
                                    Container(
                                      width: 80,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF6366F1),
                                            Color(0xFF8B5CF6),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        '$_questionCount',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    _buildCounterBtn(
                                      icon: Icons.add_rounded,
                                      onTap: () {
                                        if (_questionCount < _maxQuestions)
                                          setState(() => _questionCount++);
                                      },
                                      enabled: _questionCount < _maxQuestions,
                                      theme: theme,
                                    ),
                                  ],
                                ),
                                if (_questionCount >= _maxQuestions)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Center(
                                      child: Text(
                                        isArabic
                                            ? 'الحد الأقصى $_maxQuestions سؤال'
                                            : 'Maximum $_maxQuestions questions',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 32),

                                // Generate Button
                                InteractiveScale(
                                  onTap: _isGenerating
                                      ? null
                                      : () async {
                                          await _showPageRangeDialog();
                                        },
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
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
                                                  blurRadius: 15,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (_isGenerating)
                                            const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
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
                                                ? loc.generatingQuestions
                                                : loc.generateQuestions,
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
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Generated Questions ──
                        if (_generatedQuestions.isNotEmpty || _isGenerating)
                          SlideTransition(
                            position:
                                Tween<Offset>(
                                  begin: const Offset(0, 0.3),
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
                                              Color(0xFFF59E0B),
                                              Color(0xFFFBBF24),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.quiz_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        loc.generatedQuestions,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: -0.5,
                                            ),
                                      ),
                                      const Spacer(),
                                      if (!_isGenerating &&
                                          _generatedQuestions.isNotEmpty)
                                        TextButton.icon(
                                          onPressed: () {
                                            for (final q
                                                in _generatedQuestions) {
                                              ExamStore.addQuestion(
                                                ExamQuestion(
                                                  id:
                                                      DateTime.now()
                                                          .millisecondsSinceEpoch
                                                          .toString() +
                                                      (q['question'] ?? '')
                                                          .hashCode
                                                          .toString(),
                                                  question: q['question'] ?? '',
                                                  answer: q['answer'] ?? '',
                                                  type: q['type'] ?? '',
                                                  difficulty:
                                                      q['difficulty'] ?? '',
                                                ),
                                              );
                                            }
                                            setState(() {});
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .assignment_turned_in_rounded,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(
                                                      isArabic
                                                          ? 'تمت إضافة الكل للامتحان'
                                                          : 'All added to exam',
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor: const Color(
                                                  0xFFF59E0B,
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                duration: const Duration(
                                                  seconds: 2,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.playlist_add_rounded,
                                            size: 16,
                                            color: Color(0xFFF59E0B),
                                          ),
                                          label: Text(
                                            isArabic ? 'إضافة الكل' : 'Add all',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFF59E0B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFFF59E0B,
                                            ).withOpacity(0.1),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    loc.questionsBasedOnContent,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (_isGenerating)
                                    const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(24),
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  else
                                    ..._generatedQuestions.map(
                                      (question) => QuestionItem(
                                        theme: theme,
                                        question: question['question'] ?? '',
                                        answer: question['answer'] ?? '',
                                        rawType: question['type'] ?? '',
                                        rawDifficulty:
                                            question['difficulty'] ?? '',
                                        typeLabel: locByKey(
                                          loc,
                                          question['type'] ?? '',
                                        ),
                                        difficultyLabel: locByKey(
                                          loc,
                                          question['difficulty'] ?? '',
                                        ),
                                        loc: loc,
                                        markdownStyle: _buildMarkdownStyle(
                                          theme,
                                        ),
                                        onAddToExam: () {
                                          ExamStore.addQuestion(
                                            ExamQuestion(
                                              id:
                                                  DateTime.now()
                                                      .millisecondsSinceEpoch
                                                      .toString() +
                                                  (question['question'] ?? '')
                                                      .hashCode
                                                      .toString(),
                                              question:
                                                  question['question'] ?? '',
                                              answer: question['answer'] ?? '',
                                              type: question['type'] ?? '',
                                              difficulty:
                                                  question['difficulty'] ?? '',
                                            ),
                                          );
                                          setState(() {});
                                        },
                                        isInExam: ExamStore.containsNormalized(
                                          question['question'] ?? '',
                                        ),
                                        isArabic: isArabic,
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
        ),
      ),
    );
  }

  Widget _buildDifficultyChip({
    required ThemeData theme,
    required String label,
    required String value,
    required String groupValue,
    required Color color,
    required Function(String) onSelected,
  }) {
    final isSelected = groupValue == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.1)
                : theme.dividerColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? color : theme.dividerColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : theme.textTheme.bodyLarge?.color,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounterBtn({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFF6366F1).withOpacity(0.1)
              : theme.dividerColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? const Color(0xFF6366F1).withOpacity(0.4)
                : theme.dividerColor.withOpacity(0.2),
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: enabled ? const Color(0xFF6366F1) : Colors.grey[400],
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
// ─────────────────────────────────────────────────────────────
//  _preprocessAnswerLatex — تلف الـ bare LaTeX في $$ قبل العرض
// ─────────────────────────────────────────────────────────────

String _splitCodeLine(String line) {
  return line.replaceAllMapped(
    RegExp(r'(\))\s+(print\s*\()'),
    (m) => '${m[1]}\n${m[2]}',
  ).replaceAllMapped(
    RegExp(r'(\))\s+(print\s*\(\s*\))'),
    (m) => '${m[1]}\n${m[2]}',
  );
}

String _fixCodeFences(String text) {
  final lines  = text.split('\n');
  final result = <String>[];
  bool inFence = false;

  for (final line in lines) {
    if (line.trim().startsWith('```')) {
      inFence = !inFence;
      result.add(line);
      continue;
    }
    if (inFence) {
      final fixed = _splitCodeLine(line);
      result.addAll(fixed.split('\n'));
    } else {
      result.add(line);
    }
  }
  return result.join('\n');
}

// ─────────────────────────────────────────────────────────────
//  _preprocessAnswerLatex  [v23-fix]
// ─────────────────────────────────────────────────────────────

String _preprocessAnswerLatex(String text) {
  // [fix] وصّل السطور المكسورة قبل أي معالجة
  text = text.replaceAllMapped(
    RegExp(r'(\w\^\{[^}\n]*)\n([^}\n]*\})'),
    (m) => '${m[1]}${m[2]}',
  );
  text = text.replaceAllMapped(
    RegExp(r'(\\\w+\{[^}\n]*)\n([^}\n]*\})'),
    (m) => '${m[1]}${m[2]}',
  );

  final lines  = text.split('\n');
  final result = <String>[];
  bool inFence = false;

  for (int i = 0; i < lines.length; i++) {
    final line    = lines[i];
    final trimmed = line.trim();

    if (trimmed.startsWith('```')) {
      inFence = !inFence;
      result.add(line);
      continue;
    }
    if (inFence) { result.add(line); continue; }

    // سطر $ وحده أو $$ وحده → احذفه
    if (trimmed == r'$' || trimmed == r'$$') continue;
    if (RegExp(r'^\$\s*$').hasMatch(trimmed)) continue;

    // [fix] سطر بيبدأ بـ -x} أو closing brace → وصّله بالسطر السابق
    if (RegExp(r'^-?[a-zA-Z0-9]\s*\}').hasMatch(trimmed) && result.isNotEmpty) {
      for (int j = result.length - 1; j >= 0; j--) {
        if (result[j].trim().isNotEmpty) {
          result[j] = result[j].trimRight() + trimmed;
          break;
        }
      }
      continue;
    }

    // [fix] سطر فيه $ مخلوط مع \command برا الـ $ → لفّ الكل في $$
    if (trimmed.contains(r'$') && RegExp(r'\\[a-zA-Z]+').hasMatch(trimmed)) {
      final hasBare = _hasBareLatexOutsideDelimiters(trimmed);
      if (hasBare) {
        final stripped = _stripOrphanDollars(trimmed);
        if (stripped.isNotEmpty) {
          result.add('\$\$$stripped\$\$');
          continue;
        }
      }
    }

    // سطر بيبدأ بـ $ ويحتوي على LaTeX مخلوط
    if (trimmed.startsWith(r'$') && !trimmed.startsWith(r'$$')) {
      final inner = trimmed.replaceFirst(RegExp(r'^\$\s*'), '').trim();
      if (inner.isNotEmpty && !inner.startsWith(r'$')) {
        result.add('\$\$$inner\$\$');
        continue;
      }
    }

    if (trimmed.startsWith(r'$$') || trimmed.endsWith(r'$$')) {
      result.add(line);
      continue;
    }

    // سطر بيبدأ بـ = أو \ مباشرة → لفّه في $$
    if ((trimmed.startsWith('=') || trimmed.startsWith(r'\')) &&
        trimmed.isNotEmpty &&
        !trimmed.contains(r'$')) {
      result.add('\$\$$trimmed\$\$');
      continue;
    }

    final hasLatexCmd = RegExp(
      r'\\(?:phi|psi|chi|omega|alpha|beta|gamma|delta|'
      r'lambda|mu|sigma|theta|pi|int|sum|frac|sqrt|left|right|'
      r'implies|iff|forall|exists|nabla|partial|cdot|times|'
      r'text|mathbf|mathrm|vec|hat|bar|dot|e)\b',
    ).hasMatch(trimmed);

    final alreadyWrapped = trimmed.contains(r'$');
    final isCodeLine = RegExp(
      r'^\s*(?:def |class |import |function |const |let |var |'
      r'#include|cout|printf|public |private )',
    ).hasMatch(trimmed);

    final hasNormalText = RegExp(r'[A-Za-z\u0600-\u06FF]{5,}').hasMatch(trimmed);

  if (hasLatexCmd && !alreadyWrapped && !isCodeLine 
        && !hasNormalText   // ← الحاجة دي بس اللي ناقصة
        && trimmed.isNotEmpty) {
        result.add('\$\$$trimmed\$\$');
        continue;
    }

    result.add(line);
  }

  return result.join('\n');
}

// ─────────────────────────────────────
// ─────────────────────────────────────────────────────────────
//  QuestionItem Widget
// ─────────────────────────────────────────────────────────────
class QuestionItem extends StatefulWidget {
  final ThemeData theme;
  final String question;
  final String answer;
  final String rawType;
  final String rawDifficulty;
  final String typeLabel;
  final String difficultyLabel;
  final AppLocalizations loc;
  final MarkdownStyleSheet markdownStyle;
  final VoidCallback onAddToExam;
  final bool isInExam;
  final bool isArabic;

  const QuestionItem({
    Key? key,
    required this.theme,
    required this.question,
    required this.answer,
    required this.rawType,
    required this.rawDifficulty,
    required this.typeLabel,
    required this.difficultyLabel,
    required this.loc,
    required this.markdownStyle,
    required this.onAddToExam,
    required this.isInExam,
    required this.isArabic,
  }) : super(key: key);

  @override
  State<QuestionItem> createState() => _QuestionItemState();
}

class _QuestionItemState extends State<QuestionItem> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final difficultyColor = _difficultyColor(widget.rawDifficulty);
    final typeColor = _typeColor(widget.rawType);

    final questionBodyStyle =
        theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          height: 1.5,
        ) ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5);

    final answerBodyStyle =
        (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(
          height: 1.7,
          letterSpacing: 0.1,
          fontSize: theme.textTheme.bodyMedium?.fontSize ?? 14.0,
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tags
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.typeLabel,
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: difficultyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.difficultyLabel,
                    style: TextStyle(
                      color: difficultyColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Question
            MathMarkdown(
  data: widget.question,
              style: questionBodyStyle,
              styleSheet: MarkdownStyleSheet.fromTheme(
                Theme.of(context),
              ).copyWith(p: questionBodyStyle),
            ),

            const SizedBox(height: 16),

            // Add to Exam
            GestureDetector(
              onTap: widget.isInExam ? null : widget.onAddToExam,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: widget.isInExam
                      ? const Color(0xFFF59E0B).withOpacity(0.12)
                      : const Color(0xFFF59E0B).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isInExam
                        ? const Color(0xFFF59E0B).withOpacity(0.6)
                        : const Color(0xFFF59E0B).withOpacity(0.3),
                    width: widget.isInExam ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isInExam
                          ? Icons.assignment_turned_in_rounded
                          : Icons.assignment_add,
                      size: 15,
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isInExam
                          ? (widget.isArabic ? 'في الامتحان ✓' : 'In Exam ✓')
                          : (widget.isArabic ? 'أضف للامتحان' : 'Add to Exam'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Answer toggle
            if (widget.answer.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setState(() => _showAnswer = !_showAnswer),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _showAnswer
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _showAnswer
                          ? const Color(0xFF10B981).withOpacity(0.4)
                          : theme.dividerColor.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showAnswer
                            ? Icons.visibility_off_rounded
                            : Icons.lightbulb_outline_rounded,
                        size: 16,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showAnswer
                            ? '${widget.loc.answer} ▲'
                            : '${widget.loc.answer} ▼',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: MathMarkdown(
  data: widget.answer,
                    style: answerBodyStyle,
                    styleSheet: MarkdownStyleSheet.fromTheme(
                      Theme.of(context),
                    ).copyWith(p: answerBodyStyle),
                  ),
                ),
                crossFadeState: _showAnswer
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

