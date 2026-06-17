// lib/pages/exam_models.dart

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  ExamQuestion model
// ─────────────────────────────────────────────────────────────
class ExamQuestion {
  final String id;
  final String question;
  final String answer;
  final String type;
  final String difficulty;

  const ExamQuestion({
    required this.id,
    required this.question,
    required this.answer,
    required this.type,
    required this.difficulty,
  });

  // ← أضف ده
  factory ExamQuestion.fromMap(Map<String, dynamic> map) {
    return ExamQuestion(
      id        : map['id']?.toString()         ?? '',
      question  : map['question']?.toString()   ?? '',
      answer    : map['answer']?.toString()     ?? '',
      type      : map['type']?.toString()       ?? '',
      difficulty: map['difficulty']?.toString() ?? '',
    );
  }

  // ← أضف ده عشان الـ update يشتغل
  Map<String, dynamic> toMap() => {
    'id'        : id,
    'question'  : question,
    'answer'    : answer,
    'type'      : type,
    'difficulty': difficulty,
  };
}

// ─────────────────────────────────────────────────────────────
//  ExamSheet — ورقة امتحان كاملة
// ─────────────────────────────────────────────────────────────
class ExamSheet {
  final String id;
  String title;
  String subject;
  String duration;
  String? fileId;
  String? fileName;
  int? pageCount;
  final List<ExamQuestion> questions;
  final DateTime createdAt;
  String? dbId;

  ExamSheet({
    required this.id,
    this.title = 'Exam',
    this.subject = '',
    this.duration = '',
    this.fileId,       // ← أضف
    this.fileName,

    List<ExamQuestion>? questions,
    DateTime? createdAt,
  })  : questions = questions ?? [],
        createdAt = createdAt ?? DateTime.now();

  // عدد الأسئلة لكل نوع — هيفيد في الـ summary
  Map<String, int> get typeCounts {
    final map = <String, int>{};
    for (final q in questions) {
      map[q.type] = (map[q.type] ?? 0) + 1;
    }
    return map;
  }
}

// ─────────────────────────────────────────────────────────────
//  ExamStore — multi-exam in-memory store
// ─────────────────────────────────────────────────────────────
class ExamStore {
  ExamStore._();

  // ── كل الأوراق المحفوظة ──
  static final List<ExamSheet> sheets = [];

  // ── الورقة النشطة حالياً ──
  static ExamSheet? _active;

  static ExamSheet? get activeOrNull =>
      (_active != null && sheets.contains(_active)) ? _active : null;

  static ExamSheet get active {
    if (_active == null || !sheets.contains(_active)) {
      throw StateError('No active sheet');
    }
    return _active!;
  }

  static void setActive(ExamSheet sheet) => _active = sheet;

  // ── إنشاء ورقة جديدة وتنشيطها ──
  static ExamSheet newSheet({String title = 'Exam'}) {
    final sheet = ExamSheet(id: _newId(), title: title);
    sheets.add(sheet);
    _active = sheet;
    return sheet;
  }

  // ── حذف ورقة ──
  static void removeSheet(ExamSheet sheet) {
    sheets.remove(sheet);
    if (_active == sheet) _active = sheets.isNotEmpty ? sheets.last : null;
  }

  static void loadFromApi(List<Map<String, dynamic>> data) {
    sheets.clear();
    for (final json in data) {
      final rawId = (json['id'] ?? json['_id'])?.toString(); // ← غير هنا
      final sheet = ExamSheet(
        id       : rawId ?? '',
        title    : json['title']?.toString() ?? '',
        subject  : json['subject']?.toString() ?? '',
        duration : (json['pinned'] == true) ? 'PINNED' : '',
        fileId   : json['file_id']?.toString(),
        fileName : json['file_name']?.toString(),
        questions: (json['questions'] as List? ?? [])
            .map((q) => ExamQuestion.fromMap(Map<String, dynamic>.from(q)))
            .toList(),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')
            ?? DateTime.now(),
      )..dbId      = rawId
        ..pageCount = (json['page_count'] as num?)?.toInt() ?? 0;
      sheets.add(sheet);
    }
  }

  // ── Backward-compat: questions تشير للـ active sheet ──
  static List<ExamQuestion> get questions => activeOrNull?.questions ?? [];

  static void addQuestion(ExamQuestion q) {
    final list = activeOrNull?.questions;
    if (list == null) return;
    final alreadyExists =
    list.any((e) => _normalize(e.question) == _normalize(q.question));
    if (!alreadyExists) list.add(q);
  }

  static void clear() => activeOrNull?.questions.clear();

  static bool containsNormalized(String questionText) {
    final norm = _normalize(questionText);
    return activeOrNull?.questions
        .any((e) => _normalize(e.question) == norm) ?? false;
  }

  // ── Helpers ──
  static int _counter = 0;
  static String _newId() =>
      'sheet_${DateTime.now().millisecondsSinceEpoch}_${_counter++}';

  static String _normalize(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

// ─────────────────────────────────────────────────────────────
//  kQuestionTypes
// ─────────────────────────────────────────────────────────────
const List<Map<String, dynamic>> kQuestionTypes = [
  {
    'value':   'multiple',
    'labelEn': 'Multiple Choice',
    'labelAr': 'اختيار من متعدد',
    'icon':    Icons.list_rounded,
  },
  {
    'value':   'truefalse',
    'labelEn': 'True / False',
    'labelAr': 'صح أو خطأ',
    'icon':    Icons.check_circle_outline_rounded,
  },
  {
    'value':   'short',
    'labelEn': 'Short Answer',
    'labelAr': 'إجابة قصيرة',
    'icon':    Icons.short_text_rounded,
  },
  {
    'value':   'essay',
    'labelEn': 'Essay',
    'labelAr': 'مقالي',
    'icon':    Icons.article_rounded,
  },
  {
    'value':   'fill',
    'labelEn': 'Fill in the Blank',
    'labelAr': 'إملأ الفراغ',
    'icon':    Icons.edit_rounded,
  },
  {
    'value':   'matching',
    'labelEn': 'Matching',
    'labelAr': 'مطابقة',
    'icon':    Icons.compare_arrows_rounded,
  },
  {
    'value':   'ordering',
    'labelEn': 'Ordering',
    'labelAr': 'ترتيب',
    'icon':    Icons.sort_rounded,
  },
  {
    'value':   'definition',
    'labelEn': 'Definition',
    'labelAr': 'تعريف',
    'icon':    Icons.menu_book_rounded,
  },
  {
    'value':   'diagram',
    'labelEn': 'Diagram',
    'labelAr': 'رسم بياني',
    'icon':    Icons.schema_rounded,
  },
  {
    'value':   'calculation',
    'labelEn': 'Calculation',
    'labelAr': 'حساب',
    'icon':    Icons.calculate_rounded,
  },
  {
    'value':   'compare',
    'labelEn': 'Compare & Contrast',
    'labelAr': 'مقارنة',
    'icon':    Icons.compare_rounded,
  },
  {
    'value':   'casestudy',
    'labelEn': 'Case Study',
    'labelAr': 'دراسة حالة',
    'icon':    Icons.cases_rounded,
  },
];