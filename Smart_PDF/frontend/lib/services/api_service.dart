import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_flutter/main.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() { _init(); }

  late Dio dio;
  bool _initialized  = false;
  bool _isRefreshing = false;

  // ══════════════════════════════════════════════════════════
  //  ⚠️ لو بتتيست على موبايل حقيقي:
  //     غيّر _devMachineIP لـ IP جهازك على الـ WiFi
  //     (ipconfig على Windows / ifconfig على Mac)
  //     وتأكد إن الموبايل على نفس الـ WiFi
  // ══════════════════════════════════════════════════════════
  static const String _devMachineIP = '192.168.1.X';
  static const int    _backendPort  = 8000;

  static String get baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:$_backendPort/api';
      }
      return '/api'; // Production: Nginx proxy
    }
    if (Platform.isAndroid) {
      return kDebugMode
          ? 'http://10.0.2.2:$_backendPort/api'        // Emulator
          : 'http://$_devMachineIP:$_backendPort/api'; // جهاز حقيقي
    }
    if (Platform.isIOS) {
      return kDebugMode
          ? 'http://localhost:$_backendPort/api'         // Simulator
          : 'http://$_devMachineIP:$_backendPort/api';  // جهاز حقيقي
    }
    return 'http://localhost:$_backendPort/api'; // Windows / macOS / Linux
  }

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
          final expiry = prefs.getInt('token_expiry');
          if (expiry != null && !_isRefreshing) {
            final timeLeft = DateTime.fromMillisecondsSinceEpoch(expiry)
                .difference(DateTime.now());
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
          debugPrint('🔑 Token added: ${options.method} ${options.path}');
        } else {
          debugPrint('⚠️ No token: ${options.method} ${options.path}');
        }
        debugPrint('🌐 ${options.method} ${options.baseUrl}${options.path}');
        return handler.next(options);
      },

      onResponse: (response, handler) {
        debugPrint('✅ ${response.statusCode} ${response.requestOptions.path}');
        return handler.next(response);
      },

      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401 && !_isRefreshing) {
          debugPrint('🔄 401 — trying refresh...');
          final prefs    = await SharedPreferences.getInstance();
          final oldToken = prefs.getString('auth_token');
          if (oldToken != null) {
            final newToken = await _refreshToken(oldToken);
            if (newToken != null) {
              final retryOptions = e.requestOptions
                ..headers['Authorization'] = 'Bearer $newToken';
              try {
                return handler.resolve(await dio.fetch(retryOptions));
              } catch (_) {}
            } else {
              await _forceLogout();
            }
          }
        }
        debugPrint('❌ ${e.response?.statusCode} ${e.requestOptions.baseUrl}${e.requestOptions.path}');
        return handler.next(e);
      },
    ));
  }

  Future<String?> _refreshToken(String currentToken) async {
    if (_isRefreshing) return null;
    _isRefreshing = true;
    try {
      final prefs  = await SharedPreferences.getInstance();
      final expiry = prefs.getInt('token_expiry');
      if (expiry != null) {
        final deadline = DateTime.fromMillisecondsSinceEpoch(expiry)
            .add(const Duration(hours: 20));
        if (DateTime.now().isAfter(deadline)) {
          debugPrint('❌ Outside 24h refresh window');
          _isRefreshing = false;
          return null;
        }
      }

      final resp = await Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $currentToken',
        },
      )).post('/auth/refresh');

      if (resp.data['success'] == true) {
        final newToken  = resp.data['data']['token'];
        final expiresIn = resp.data['data']['expires_in'] ?? 14400;
        await prefs.setString('auth_token', newToken);
        await prefs.setInt(
          'token_expiry',
          DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch,
        );
        debugPrint('✅ Token refreshed');
        _isRefreshing = false;
        return newToken;
      }
    } catch (e) {
      debugPrint('❌ Refresh error: $e');
    }
    _isRefreshing = false;
    return null;
  }

  Future<String?> refreshToken(String token) => _refreshToken(token);

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

  // ── History ───────────────────────────────────────────────
  Future<List<dynamic>> getHistory() async {
    try {
      final r = await dio.get('/files/history');
      if (r.data['success'] == true) return r.data['data'];
    } catch (e) { debugPrint('❌ getHistory: $e'); }
    return [];
  }

  // ── File Results ──────────────────────────────────────────
  Future<Map<String, dynamic>?> getFileResults(String fileId) async {
    try {
      final r = await dio.get('/files/$fileId/results');
      if (r.data['success'] == true) return r.data['data'];
    } catch (e) { debugPrint('❌ getFileResults: $e'); }
    return null;
  }

  // ── Conversations ─────────────────────────────────────────
  Future<Map<String, dynamic>> getConversations() async {
    try { return (await dio.get('/conversations')).data; }
    catch (e) { return {'success': false, 'message': e.toString()}; }
  }

  Future<Map<String, dynamic>> deleteConversation(String id) async {
    try { return (await dio.delete('/conversations/$id')).data; }
    catch (e) { return {'success': false, 'message': e.toString()}; }
  }
}

class _LoginRedirect extends StatelessWidget {
  const _LoginRedirect();
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Navigator.pushReplacementNamed(context, '/login'),
    );
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
