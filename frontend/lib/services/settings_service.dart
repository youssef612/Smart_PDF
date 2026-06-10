import 'package:dio/dio.dart';
import 'api_service.dart';

class SettingsService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> changeLanguage(String language) async {
    try {
      final response = await _apiService.dio.put(
        '/settings/language',
        data: {'language': language},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> changeTheme(String theme) async {
    try {
      final response = await _apiService.dio.put(
        '/settings/theme',
        data: {'theme': theme},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    try {
      final response = await _apiService.dio.put(
        '/settings/password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': newPasswordConfirmation,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      return e.response?.data['message'] ?? 'An error occurred';  // ✅
    }
    return 'Network error - check your connection';  // ✅
  }
}