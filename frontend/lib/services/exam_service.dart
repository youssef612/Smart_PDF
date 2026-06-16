// exam_service.dart — النسخة المحدّثة

import 'package:dio/dio.dart';
import 'api_service.dart';

class ExamService {
  final ApiService _api = ApiService();

  // ─── Fetch All ────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchAll() async {
    try {
      final res = await _api.dio.get('/exams');
      if (res.data['success'] == true) {
        final List list = res.data['data'] ?? [];
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      print('fetchAll error: $e');
      return [];
    }
  }

  // ─── Create ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> create({
    required String title,
    String? subject,
    String? fileId,
    String? fileName,
    int? pageCount,
  }) async {
    try {
      final res = await _api.dio.post('/exams', data: {
        'title'    : title,
        if (subject  != null) 'subject'   : subject,
        if (fileId   != null) 'file_id'   : fileId,
        if (fileName != null) 'file_name' : fileName,
        if (pageCount != null) 'page_count' : pageCount,
        'questions': [],
      });
      if (res.data['success'] == true) {
        return Map<String, dynamic>.from(res.data['data']);
      }
      return null;
    } catch (e) {
      print('create error: $e');
      return null;
    }
  }

  // ─── Update Questions ─────────────────────────────────────────────────────
  Future<bool> update(String dbId, List<Map<String, dynamic>> questions) async {
    try {
      final res = await _api.dio.put('/exams/$dbId', data: {
        'questions': questions,
      });
      return res.data['success'] == true;
    } catch (e) {
      print('update error: $e');
      return false;
    }
  }

  // ─── Rename ───────────────────────────────────────────────────────────────
  /// يرسل فقط الـ title الجديد للـ endpoint المخصص للتسمية.
  /// لو الـ API بيستخدم نفس PUT /exams/:id، بس بترسل title بدل questions،
  /// غيّر الـ endpoint لـ '/exams/$dbId' واحذف '/rename'.
  Future<bool> rename(String dbId, String newTitle) async {
    try {
      final res = await _api.dio.put('/exams/$dbId', data: {
        'title': newTitle,
      });
      return res.data['success'] == true;
    } catch (e) {
      print('rename error: $e');
      return false;
    }
  }

  Future<bool> togglePin(String dbId, {required bool pinned}) async {
    try {
      final res = await _api.dio.put('/exams/$dbId', data: {
        'pinned': pinned,
      });
      return res.data['success'] == true;
    } catch (e) {
      print('togglePin error: $e');
      return false;
    }
  }
  // ─── Delete ───────────────────────────────────────────────────────────────
  Future<bool> delete(String dbId) async {
    try {
      final res = await _api.dio.delete('/exams/$dbId');
      return res.data['success'] == true;
    } catch (e) {
      print('delete error: $e');
      return false;
    }
  }

  // ─── Generate Exam Questions ──────────────────────────────────────────────
  Future<String?> generateQuestions({
    required String fileId,
    required String type,
    required String difficulty,
    required int count,
    int? fromPage,
    int? toPage,
  }) async {
    try {
      final Map<String, dynamic> requestData = {
        'type':             type,
        'difficulty':       difficulty.toLowerCase(),
        'count':            count,
        'force_regenerate': true,
        'seed':             DateTime.now().millisecondsSinceEpoch,
      };

      if (fromPage != null) requestData['from_page'] = fromPage;
      if (toPage   != null) requestData['to_page']   = toPage;

      final res = await _api.dio.post(
        '/files/$fileId/exam-questions',
        data: requestData,
      );

      if (res.data['success'] == true) {
        return res.data['data']['questions'] as String?;
      }
      return null;
    } catch (e) {
      print('generateQuestions error: $e');
      return null;
    }
  }
}