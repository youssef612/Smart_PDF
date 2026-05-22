// lib/services/history_store.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryStore {
  static const String key = 'history';

  // ✅ إضافة عنصر جديد مع id فريد
static Future<void> add(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);
    List list = data != null ? jsonDecode(data) : [];

    // استخدمي الـ id اللي جاي من الـ Laravel لو موجود، لو مش موجود خليه وقت
    // ده بيضمن إن الملف مربوط فعلاً بالداتا بيز
    String uniqueId = item['file_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    item['id'] = "${uniqueId}_${item['type']}"; // مثلاً 55_summary
    list.add(item);
    await prefs.setString(key, jsonEncode(list));
}

  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);
    if (data == null) return [];
    final list = jsonDecode(data);
    return List<Map<String, dynamic>>.from(list);
  }

  // ✅ حذف بالـ id مش بالـ index - ده بيحل مشكلة الـ filtered list
  static Future<void> deleteById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);
    if (data == null) return;

    List list = jsonDecode(data);
    list.removeWhere((item) => item['id']?.toString() == id);

    await prefs.setString(key, jsonEncode(list));
  }

  // ✅ محتفظين بـ delete القديمة عشان مفيش كود تاني بيستخدمها
  static Future<void> delete(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);
    if (data == null) return;

    List list = jsonDecode(data);
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
    }

    await prefs.setString(key, jsonEncode(list));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}