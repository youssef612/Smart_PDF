import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// api_config.dart — lib/config/api_config.dart

class ApiConfig {
  ApiConfig._();

  /// ══════════════════════════════════════════════════════
  ///  غيّر السطر ده بـ IP جهازك لما تتيست على موبايل حقيقي
  ///  اعرف الـ IP بـ: ipconfig (Windows) أو ifconfig (Mac/Linux)
  /// ══════════════════════════════════════════════════════
  static const String _devMachineIP = '192.168.1.X'; // ← غيّر ده
  static const int    _backendPort  = 8000;
  /// ══════════════════════════════════════════════════════

  static String get baseUrl {
    // ── Web ──────────────────────────────────────────────
    if (kIsWeb) {
      final host = Uri.base.host;
      // Dev على localhost
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:$_backendPort';
      }
      // Production: Nginx proxy
      return '/api';
    }

    // ── Android ──────────────────────────────────────────
    if (Platform.isAndroid) {
      // Emulator: 10.0.2.2 = localhost الكمبيوتر
      // جهاز حقيقي: IP الكمبيوتر على الـ network
      return kDebugMode
          ? 'http://10.0.2.2:$_backendPort'       // emulator
          : 'http://$_devMachineIP:$_backendPort'; // جهاز حقيقي
    }

    // ── iOS ──────────────────────────────────────────────
    if (Platform.isIOS) {
      // Simulator: localhost يشتغل
      // جهاز حقيقي: IP الكمبيوتر
      return kDebugMode
          ? 'http://localhost:$_backendPort'        // simulator
          : 'http://$_devMachineIP:$_backendPort';  // جهاز حقيقي
    }

    // ── Windows / macOS / Linux ───────────────────────────
    // نفس الجهاز اللي Docker شغال عليه
    return 'http://localhost:$_backendPort';
  }

  // ── Endpoints ──────────────────────────────────────────
  static String get login     => '$baseUrl/api/login';
  static String get register  => '$baseUrl/api/register';
  static String get uploadPdf => '$baseUrl/api/pdfs/upload';
  static String get pdfs      => '$baseUrl/api/pdfs';
  static String get chat      => '$baseUrl/api/chat';
  static String get summarize => '$baseUrl/api/summarize';
  static String get questions => '$baseUrl/api/questions';
}
