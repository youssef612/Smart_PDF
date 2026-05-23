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
}

// ─────────────────────────────────────────────────────────────
//  ExamStore — global in-memory store
// ─────────────────────────────────────────────────────────────
class ExamStore {
  ExamStore._();

  static final List<ExamQuestion> questions = [];

  static void addQuestion(ExamQuestion q) {
    final alreadyExists =
    questions.any((e) => _normalize(e.question) == _normalize(q.question));
    if (!alreadyExists) questions.add(q);
  }

  static void clear() => questions.clear();

  static bool containsNormalized(String questionText) {
    final norm = _normalize(questionText);
    return questions.any((e) => _normalize(e.question) == norm);
  }

  static String _normalize(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

// ─────────────────────────────────────────────────────────────
//  kQuestionTypes — used in QuestionsPage dropdown
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