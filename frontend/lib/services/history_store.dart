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

    String uniqueId =
        item['file_id']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final String type = item['type'] ?? '';
    item['id'] = "${uniqueId}_${type}";

    // السؤال: يتضاف دائماً كعنصر جديد (مع timestamp فريد في الـ id)
    if (type == 'quiz' || type == 'questions') {
      item['id'] =
          "${uniqueId}_${type}_${DateTime.now().millisecondsSinceEpoch}";
      list.add(item);
    } else {
      // شرح/تلخيص: احذف القديم وضيف الجديد
      list.removeWhere((e) => e['id'] == item['id']);
      list.add(item);
    }

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
