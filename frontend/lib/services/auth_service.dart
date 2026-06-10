import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  String _avatarKey(String email) => 'user_avatar_bytes_$email';
  String _createdAtKey(String email) => 'user_created_at_$email';

  // -------------------- Authentication --------------------

  Future<Map<String, dynamic>> signUp({
    required String name,
    required String email,
    required String password,
    String? passwordConfirmation,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    try {
      FormData formData;

      if (imageBytes != null) {
        formData = FormData.fromMap({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation ?? password,
          'image': MultipartFile.fromBytes(
            imageBytes,
            filename: imageName ?? 'profile.jpg',
            contentType: DioMediaType('image', 'jpeg'),
          ),
        });
      } else {
        formData = FormData.fromMap({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation ?? password,
        });
      }

      final response = await _apiService.dio.post(
        '/auth/signup',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      if (response.data['success'] == true) {
        await _saveToken(response.data['data']['token']);

        Map<String, dynamic> userData = response.data['data']['user'];
        final userEmail = userData['email'] ?? email;

        final oldUser = await getCurrentUserFromStorage();
        if (oldUser != null && oldUser['email'] != userEmail) {
          await _clearUserSpecificData();
        }

        final now = DateTime.now().toIso8601String();
        userData['createdAt'] = now;

        if (imageBytes != null) {
          userData['avatarBytes'] = base64Encode(imageBytes);
        }

        await _saveUser(userData);
        return response.data;
      }

      throw Exception(response.data['message'] ?? 'Registration failed');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.data['success'] == true) {
        await _saveToken(response.data['data']['token']);

        Map<String, dynamic> userData = response.data['data']['user'];
        final userEmail = userData['email'] ?? email;

        final oldUser = await getCurrentUserFromStorage();
        if (oldUser != null && oldUser['email'] != userEmail) {
          await _clearUserSpecificData();
          debugPrint('✅ Cleared old user data (different account)');
        }

        final prefs = await SharedPreferences.getInstance();

        final savedAvatar = prefs.getString(_avatarKey(userEmail));
        if (savedAvatar != null) {
          userData['avatarBytes'] = savedAvatar;
        }

        final savedCreatedAt = prefs.getString(_createdAtKey(userEmail));
        if (savedCreatedAt != null) {
          userData['createdAt'] = savedCreatedAt;
        } else {
          userData['createdAt'] = DateTime.now().toIso8601String();
        }

        await _saveUser(userData);
        return response.data;
      }

      throw Exception(response.data['message'] ?? 'Login failed');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _apiService.dio.post(
        '/auth/forgot-password',
        data: {'email': email},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await _apiService.dio.post(
        '/auth/reset-password',
        data: {
          'email': email,
          'otp': otp,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.dio.post('/auth/logout');
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      await _clearAuthData();
      debugPrint('✅ Logout complete');
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _apiService.dio.get('/me');
      if (response.data['success'] == true) {
        Map<String, dynamic> userData = response.data['data'];
        final userEmail = userData['email'] ?? '';

        final prefs = await SharedPreferences.getInstance();

        final savedAvatar = prefs.getString(_avatarKey(userEmail));
        if (savedAvatar != null) {
          userData['avatarBytes'] = savedAvatar;
        }

        final savedCreatedAt = prefs.getString(_createdAtKey(userEmail));
        if (savedCreatedAt != null) {
          userData['createdAt'] = savedCreatedAt;
        }

        await _saveUser(userData);
        return response.data;
      }
      throw Exception('Failed to get user');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // -------------------- Profile Update --------------------

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    try {
      FormData formData = FormData.fromMap({});

      if (name != null) {
        formData.fields.add(MapEntry('name', name));
      }

      if (imageBytes != null) {
        formData.files.add(MapEntry(
          'image',
          MultipartFile.fromBytes(
            imageBytes,
            filename: imageName ?? 'profile.jpg',
            contentType: DioMediaType('image', 'jpeg'),
          ),
        ));
      }

      final response = await _apiService.dio.post(
        '/me',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      if (response.data['success'] == true) {
        Map<String, dynamic> userData = response.data['data'];
        final userEmail = userData['email'] ?? '';
        final prefs = await SharedPreferences.getInstance();

        if (imageBytes != null) {
          userData['avatarBytes'] = base64Encode(imageBytes);
          await updateAvatarLocally(imageBytes);
        } else {
          final savedAvatar = prefs.getString(_avatarKey(userEmail));
          if (savedAvatar != null) {
            userData['avatarBytes'] = savedAvatar;
          }
        }

        final savedCreatedAt = prefs.getString(_createdAtKey(userEmail));
        if (savedCreatedAt != null) {
          userData['createdAt'] = savedCreatedAt;
        }

        await _saveUser(userData);
        return response.data;
      }

      throw Exception(response.data['message'] ?? 'Update failed');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // -------------------- Local Storage --------------------

  // ✅ التعديل هنا: بنحفظ وقت انتهاء التوكن
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);

    // ✅ احفظ وقت الانتهاء (4 ساعات = 14400 ثانية)
    final expiry = DateTime.now()
        .add(const Duration(seconds: 14400))
        .millisecondsSinceEpoch;
    await prefs.setInt('token_expiry', expiry);
    debugPrint('✅ Token saved, expires at: ${DateTime.fromMillisecondsSinceEpoch(expiry)}');
  }

  Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', json.encode(user));

    final email = user['email'] ?? '';

    if (user['avatarBytes'] != null) {
      await prefs.setString(_avatarKey(email), user['avatarBytes']);
    }

    if (user['createdAt'] != null) {
      await prefs.setString(_createdAtKey(email), user['createdAt']);
    }
  }

  // ✅ التعديل هنا: بنمسح token_expiry كمان
  Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('token_expiry'); // ✅ السطر الجديد
    await prefs.remove('user');
    debugPrint('✅ Cleared auth data (avatar and createdAt kept per user)');
  }

  Future<void> _clearUserSpecificData() async {
    final prefs = await SharedPreferences.getInstance();
    final oldUser = await getCurrentUserFromStorage();
    if (oldUser != null) {
      final oldEmail = oldUser['email'] ?? '';
      if (oldEmail.isNotEmpty) {
        await prefs.remove(_avatarKey(oldEmail));
        await prefs.remove(_createdAtKey(oldEmail));
        debugPrint('✅ Cleared specific data for old user: $oldEmail');
      }
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, dynamic>?> getCurrentUserFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');

    if (userString != null) {
      Map<String, dynamic> userData = json.decode(userString);
      final email = userData['email'] ?? '';

      if (email.isNotEmpty) {
        final savedAvatar = prefs.getString(_avatarKey(email));
        if (savedAvatar != null && userData['avatarBytes'] == null) {
          userData['avatarBytes'] = savedAvatar;
        }

        final savedCreatedAt = prefs.getString(_createdAtKey(email));
        if (savedCreatedAt != null && userData['createdAt'] == null) {
          userData['createdAt'] = savedCreatedAt;
        }
      }

      return userData;
    }
    return null;
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Uint8List? getUserAvatarBytes(Map<String, dynamic>? user) {
    if (user == null) return null;
    if (user['avatarBytes'] != null) {
      try {
        return base64Decode(user['avatarBytes']);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> updateAvatarLocally(Uint8List? imageBytes) async {
    final prefs = await SharedPreferences.getInstance();
    final user = await getCurrentUserFromStorage();
    final email = user?['email'] ?? '';

    if (email.isEmpty) return;

    if (imageBytes != null) {
      final avatarBase64 = base64Encode(imageBytes);
      await prefs.setString(_avatarKey(email), avatarBase64);
      if (user != null) {
        user['avatarBytes'] = avatarBase64;
        await _saveUser(user);
      }
    } else {
      await prefs.remove(_avatarKey(email));
    }
  }

  Future<Uint8List?> getStoredAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final user = await getCurrentUserFromStorage();
    final email = user?['email'] ?? '';
    if (email.isEmpty) return null;
    final avatarString = prefs.getString(_avatarKey(email));
    if (avatarString != null) {
      try {
        return base64Decode(avatarString);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<String?> getStoredCreatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final user = await getCurrentUserFromStorage();
    final email = user?['email'] ?? '';
    if (email.isEmpty) return null;
    return prefs.getString(_createdAtKey(email));
  }

  Future<void> updateCreatedAtLocally(String createdAt) async {
    final prefs = await SharedPreferences.getInstance();
    final user = await getCurrentUserFromStorage();
    final email = user?['email'] ?? '';
    if (email.isEmpty) return;
    await prefs.setString(_createdAtKey(email), createdAt);
  }

  Future<Uint8List?> getCurrentUserAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final user = await getCurrentUserFromStorage();
    final email = user?['email'] ?? '';
    if (email.isEmpty) return null;
    final avatarString = prefs.getString(_avatarKey(email));
    if (avatarString != null) {
      try {
        return base64Decode(avatarString);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCurrentUserWithAvatar() async {
    final user = await getCurrentUserFromStorage();
    if (user != null) {
      final avatar = await getCurrentUserAvatar();
      if (avatar != null) {
        user['avatarBytes'] = base64Encode(avatar);
      }
    }
    return user;
  }

  // -------------------- OTP --------------------

  Future<Map<String, dynamic>> sendOtp({required String email}) async {
    try {
      final response = await _apiService.dio.post(
        '/send-otp',
        data: {'email': email},
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? 'Failed to send OTP');
      }
      throw Exception('Network error: ${e.message}');
    }
  }


  Future<void> updateName({required String name}) async {
    try {
      final response = await _apiService.dio.put('/me/name', data: {'name': name});
      final user = await getCurrentUserFromStorage();
      if (user != null) {
        user['name'] = name;
        await _saveUser(user);
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _apiService.dio.post('/auth/change-password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> changeEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    try {
      await _apiService.dio.post('/auth/change-email/send-otp', data: {
        'new_email': newEmail,
        'password': currentPassword,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> changeEmailVerify({
    required String otp,
    required String newEmail,
  }) async {
    try {
      final response = await _apiService.dio.post('/auth/change-email/verify', data: {
        'otp': otp,
      });
      final user = await getCurrentUserFromStorage();
      if (user != null) {
        user['email'] = newEmail;
        await _saveUser(user);
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteAvatar() async {
    try {
      await _apiService.dio.delete('/auth/avatar');
      final prefs = await SharedPreferences.getInstance();
      final user = await getCurrentUserFromStorage();
      if (user != null) {
        await prefs.remove(_avatarKey(user['email'] ?? ''));
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _apiService.dio.post(
        '/verify-otp',
        data: {'email': email, 'otp': otp},
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? 'Invalid OTP');
      }
      throw Exception('Network error: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> resendOtp({required String email}) async {
    try {
      final response = await _apiService.dio.post(
        '/resend-otp',
        data: {'email': email},
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? 'Failed to resend OTP');
      }
      throw Exception('Network error: ${e.message}');
    }
  }

  // -------------------- Error Handling --------------------

  String _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      if (data is Map) {
        if (data['success'] == false) {
          if (data['message'] != null) return data['message'];
          if (data['errors'] != null) {
            final errors = data['errors'] as Map;
            if (errors.isNotEmpty) {
              final firstError = errors.values.first;
              if (firstError is List && firstError.isNotEmpty) {
                return firstError[0];
              }
            }
          }
        }
        if (data['message'] != null) return data['message'];
      }
      return 'Server error: ${e.response?.statusCode}';
    } else if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout - check your internet';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return 'Server is not responding';
    } else if (e.type == DioExceptionType.cancel) {
      return 'Request cancelled';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection';
    } else {
      return 'Network error: ${e.message}';
    }
  }
}