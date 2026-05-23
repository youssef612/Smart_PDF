import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_flutter/main.dart'; // ✅ عشان navigatorKey
import 'package:flutter/material.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _init();
  }

  late Dio dio;
  static const String baseUrl = "https://grant-aplitic-dhooly.ngrok-free.dev/api";
  bool _initialized = false;
  bool _isRefreshing = false;

  void _init() {
    if (_initialized) return;
    _initialized = true;

    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(minutes: 15),
      receiveTimeout: const Duration(hours: 24),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');

        if (token != null) {
          // ✅ افحص لو التوكن هينتهي خلال 5 دقايق
          final expiry = prefs.getInt('token_expiry');
          if (expiry != null && !_isRefreshing) {
            final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiry);
            final timeLeft = expiryTime.difference(DateTime.now());

            if (timeLeft.inMinutes <= 5) {
              debugPrint('⏰ Token expires in ${timeLeft.inMinutes} min, refreshing...');
              final newToken = await _refreshToken(token);
              if (newToken != null) {
                options.headers['Authorization'] = 'Bearer $newToken';
                return handler.next(options);
              }
            }
          }

          options.headers['Authorization'] = 'Bearer $token';
          debugPrint('🔑 Token added to request: ${options.method} ${options.path}');
        } else {
          debugPrint('⚠️ No token for: ${options.method} ${options.path}');
        }

        debugPrint('🌐 Request: ${options.method} ${options.path}');
        debugPrint('📦 Headers: ${options.headers}');
        return handler.next(options);
      },

      onResponse: (response, handler) {
        debugPrint('✅ Response: ${response.statusCode} - ${response.requestOptions.path}');
        return handler.next(response);
      },

      onError: (DioException e, handler) async {
        // ✅ لو جه 401 → جرب refresh تلقائي
        if (e.response?.statusCode == 401 && !_isRefreshing) {
          debugPrint('🔄 Got 401, trying to refresh token...');

          final prefs = await SharedPreferences.getInstance();
          final oldToken = prefs.getString('auth_token');

          if (oldToken != null) {
            final newToken = await _refreshToken(oldToken);

            if (newToken != null) {
              // ✅ أعد الـ request الأصلي بالتوكن الجديد
              debugPrint('✅ Retrying original request with new token...');
              final retryOptions = e.requestOptions;
              retryOptions.headers['Authorization'] = 'Bearer $newToken';

              try {
                final retryResponse = await dio.fetch(retryOptions);
                return handler.resolve(retryResponse);
              } catch (_) {
                return handler.next(e);
              }
            } else {
              // ❌ فشل الـ refresh → روح Login
              debugPrint('❌ Refresh failed, forcing logout...');
              await _forceLogout();
              return handler.next(e);
            }
          }
        }

        debugPrint('❌ Error: ${e.message}');
        debugPrint('Status: ${e.response?.statusCode}');
        debugPrint('URL: ${e.requestOptions.path}');
        return handler.next(e);
      },
    ));
  }

  // ✅ دالة الـ Refresh (private)
  Future<String?> _refreshToken(String currentToken) async {
    if (_isRefreshing) return null;
    _isRefreshing = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // افحص لو لسه في الـ 24 ساعة
      final expiry = prefs.getInt('token_expiry');
      if (expiry != null) {
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiry);
        // التوكن 4 ساعات + 20 ساعة = 24 ساعة refresh window
        final refreshDeadline = expiryTime.add(const Duration(hours: 20));
        if (DateTime.now().isAfter(refreshDeadline)) {
          debugPrint('❌ Outside 24h refresh window');
          _isRefreshing = false;
          return null;
        }
      }

      // استخدم Dio منفصل عشان ميدخلش في loop
      final refreshDio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $currentToken',
        },
      ));

      final response = await refreshDio.post('/auth/refresh');

      if (response.data['success'] == true) {
        final newToken = response.data['data']['token'];
        final expiresIn = response.data['data']['expires_in'] ?? 14400;

        await prefs.setString('auth_token', newToken);
        final newExpiry = DateTime.now()
            .add(Duration(seconds: expiresIn))
            .millisecondsSinceEpoch;
        await prefs.setInt('token_expiry', newExpiry);

        debugPrint('✅ Token refreshed successfully');
        _isRefreshing = false;
        return newToken;
      }

      _isRefreshing = false;
      return null;
    } catch (e) {
      debugPrint('❌ Refresh error: $e');
      _isRefreshing = false;
      return null;
    }
  }

  // ✅ public عشان splash_screen تستخدمها
  Future<String?> refreshToken(String token) => _refreshToken(token);

  // ✅ Logout إجباري من غير context
  Future<void> _forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('token_expiry');
    await prefs.remove('user');

    navigatorKey.currentState?.pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const _LoginRedirect(),
        transitionDuration: Duration.zero,
      ),
      (route) => false,
    );
  }



    // =========================
  // 📂 HISTORY
  // =========================
  Future<List<dynamic>> getHistory() async {
    try {
      final response = await dio.get('/files/history');

      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return [];
    } catch (e) {
      debugPrint('❌ getHistory error: $e');
      return [];
    }
  }

  // =========================
  // 📄 FILE RESULTS (IMPORTANT)
  // =========================
  Future<Map<String, dynamic>?> getFileResults(String fileId) async {
    try {
      final response = await dio.get('/files/$fileId/results');

      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      debugPrint('❌ getFileResults error: $e');
      return null;
    }
  }
}

// Widget مؤقت للـ redirect لـ SignInPage
class _LoginRedirect extends StatelessWidget {
  const _LoginRedirect();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/login');
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }


  
}