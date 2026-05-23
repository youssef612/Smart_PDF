import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'api_service.dart';

class FilesService {
  final ApiService _apiService = ApiService();

  // الحصول على جميع الملفات
  Future<List<Map<String, dynamic>>> getRecentFiles() async {
    try {
      final response = await _apiService.dio.get('/files');
      if (response.data['success'] == true) {
        final List list = response.data['data'] ?? [];
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting files: $e');
      return [];
    }
  }

  // الحصول على ملف محدد
  Future<Map<String, dynamic>?> getFile(String fileId) async {
    try {
      final response = await _apiService.dio.get('/files/$fileId');
      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('Error getting file: $e');
      return null;
    }
  }

  // دالة تجيب تاريخ الملفات (History)
Future<List<Map<String, dynamic>>> getHistory() async {
  try {
    // بنادي على الـ API اللي عملناه في لارافيل
    final response = await _apiService.dio.get('/files/history');
    
    if (response.data['success'] == true) {
      List list = response.data['data'];
      return list.map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  } catch (e) {
    print('Error getting history: $e');
    return [];
  }
}

  // رفع ملف عن طريق الاختيار
  Future<Map<String, dynamic>?> pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null) return null;

      final pickedFile = result.files.single;
      final bytes = pickedFile.bytes;
      final fileName = pickedFile.name;

      if (bytes == null) return null;

      return await uploadFileBytes(bytes, fileName: fileName);
    } catch (e) {
      print('Error picking and uploading file: $e');
      return null;
    }
  }

  // رفع ملف من بايتات
  // رفع ملف من بايتات (نسخة محسنة للويب و ngrok)
  Future<Map<String, dynamic>?> uploadFileBytes(
      Uint8List bytes, {
        required String fileName,
        String type = 'PDF',
      }) async {
    try {
      // 1. تجهيز البيانات (تأكد من استخدام DioMediaType من حزمة dio)
      print('📁 File name: $fileName');
      print('📦 Bytes length: ${bytes.length}');
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
        ),
        'type': type,
      });

      // 2. إرسال الطلب مع الهيدرز التصحيحية
      final response = await _apiService.dio.post(
        '/files/upload',
        data: formData,
        options: Options(
          headers: {
            // إجبار السيرفر على الرد بـ JSON حتى في حالة الخطأ (يحل مشكلة الـ 422)
            'Accept': 'application/json',
            // تخطي صفحة التحذير الخاصة بـ ngrok التي قد تكسر الـ API
            'ngrok-skip-browser-warning': 'true',
            // ملاحظة: لا نضع Content-Type يدوياً هنا، Dio سيتكفل به مع FormData
          },
        ),
      );

      print('📤 Upload response: ${response.data}');

      // 3. التحقق من النجاح بناءً على هيكلة الـ Backend الخاصة بك
      if (response.data['success'] == true || response.statusCode == 200 || response.statusCode == 201) {
        print('✅ File uploaded successfully: ${response.data['data']}');
        return response.data['data'];
      }

      print('⚠️ Upload failed: ${response.data['message']}');
      return null;

    } on DioException catch (e) {
      print('❌ Dio error uploading file: ${e.message}');
      if (e.response != null) {
        // هذا السطر سيطبع لك تفاصيل الـ Validation Error من السيرفر (مثل Laravel)
        print('📦 Error details from server: ${e.response?.data}');
      }
      return null;
    } catch (e) {
      print('⚠️ Unexpected error: $e');
      return null;
    }
  }

  // دالة عامة للرفع (مرونة أكثر)
  Future<Map<String, dynamic>?> uploadFile(
      Uint8List bytes, {
        required String fileName,
        String type = 'Summary',
      }) async {
    return await uploadFileBytes(bytes, fileName: fileName, type: type);
  }

  // حذف ملف
  Future<bool> deleteFile(String fileId) async {
    try {
      print('Deleting file with ID: $fileId');  // ✅ للتأكد
      final response = await _apiService.dio.delete('/files/$fileId');

      print('Delete response: ${response.data}');  // ✅ للتأكد

      if (response.data['success'] == true) {
        print('File deleted successfully');
        return true;
      } else {
        print('Delete failed: ${response.data['message']}');
        return false;
      }
    } on DioException catch (e) {
      print('Dio error deleting file: ${e.message}');
      if (e.response != null) {
        print('Response status: ${e.response?.statusCode}');
        print('Response data: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  // تحديث ملف (إذا كان لديك هذه الميزة)
  Future<Map<String, dynamic>?> updateFile(
      String fileId, {
        String? name,
        Uint8List? bytes,
      }) async {
    try {
      final formData = FormData.fromMap({});

      if (name != null) {
        formData.fields.add(MapEntry('name', name));
      }

      if (bytes != null) {
        formData.files.add(
          MapEntry(
            'file',
            MultipartFile.fromBytes(
              bytes,
              filename: name ?? 'file.pdf',
            ),
          ),
        );
      }

      final response = await _apiService.dio.post(
        '/files/$fileId',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('Error updating file: $e');
      return null;
    }
  }

  // تحميل ملف
  Future<Uint8List?> downloadFile(String fileId) async {
    try {
      final response = await _apiService.dio.get(
        '/files/$fileId/download',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data;
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }

  // الحصول على إحصائيات الملفات
  Future<Map<String, int>> getFilesStats() async {
    try {
      final files = await getRecentFiles();
      return {
        'total': files.length,
        'completed': files.where((f) => f['status'] == 'Completed').length,
        'processing': files.where((f) => f['status'] == 'Processing').length,
        'summary': files.where((f) => f['type'] == 'summary').length,
        'translation': files.where((f) => f['type'] == 'translation').length,
        'questions': files.where((f) => f['type'] == 'questions').length,
      };
    } catch (e) {
      print('Error getting files stats: $e');
      return {
        'total': 0,
        'completed': 0,
        'processing': 0,
        'summary': 0,
        'translation': 0,
        'questions': 0,
      };
    }
  }
}