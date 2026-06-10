// lib/utils/math_image_renderer.dart
// v7-fix: more aggressive frame waiting for complex math widgets

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../main.dart' show navigatorKey;

class ParagraphToken {
  final String text;
  final bool isMath;
  const ParagraphToken({required this.text, required this.isMath});
}

class MathImageRenderer {

  // ───────────────────────────────────────────────────────────────────────────
  // render() — single LaTeX → PNG bytes
  // ───────────────────────────────────────────────────────────────────────────
  static Future<Uint8List?> render(
    String latex, {
    double fontSize   = 18,
    double pixelRatio = 3.0,
  }) async {
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) {
      debugPrint('[MathImageRenderer] render: overlay is NULL — navigatorKey not ready');
      return null;
    }

    debugPrint('[MathImageRenderer] render: starting for latex="${latex.substring(0, latex.length.clamp(0, 80))}"');
    final repaintKey = GlobalKey();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -99999, top: -99999,
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(
            key: repaintKey,
            child: Container(
              color:   Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Math.tex(
                  latex,
                  mathStyle: MathStyle.display,
                  textStyle: TextStyle(fontSize: fontSize, color: Colors.black),
                  onErrorFallback: (e) {
                    debugPrint('[MathImageRenderer] Math.tex parse error for "$latex": $e');
                    return Text(latex,
                      style: TextStyle(fontFamily: 'monospace',
                          fontSize: fontSize, color: Colors.red.shade700));
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    debugPrint('[MathImageRenderer] render: overlay entry inserted, waiting for render...');
    await _waitForRender();
    debugPrint('[MathImageRenderer] render: wait complete, capturing image...');

    try {
      final boundary = repaintKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('[MathImageRenderer] render: boundary not found — context=${repaintKey.currentContext}');
        entry.remove();
        return null;
      }
      final image    = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      debugPrint('[MathImageRenderer] render: SUCCESS bytes=${byteData?.lengthInBytes ?? "NULL"}');
      entry.remove();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[MathImageRenderer] render() error: $e');
      entry.remove();
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // renderParagraph() — mixed text+math → ONE PNG image
  // ───────────────────────────────────────────────────────────────────────────
  static Future<Uint8List?> renderParagraph(
    List<ParagraphToken> tokens, {
    double maxWidth             = 500,
    double fontSize             = 16,
    double mathScale            = 1.15,
    double pixelRatio           = 3.0,
    TextDirection textDirection = TextDirection.ltr,
    double lineHeight           = 1.6,
  }) async {
    if (tokens.isEmpty) return null;

    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) {
      debugPrint('[MathImageRenderer] No overlay available');
      return null;
    }

    final double mathFontSize = fontSize * mathScale;
    final spans = <InlineSpan>[];

    for (final token in tokens) {
      if (!token.isMath) {
        spans.add(TextSpan(
          text: token.text,
          style: TextStyle(
            fontSize:   fontSize,
            color:      Colors.black,
            height:     lineHeight,
            fontFamily: 'Roboto',
          ),
        ));
      } else {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline:  TextBaseline.alphabetic,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: fontSize * 0.12),
              child: Math.tex(
                token.text,
                mathStyle:  MathStyle.text,
                textStyle:  TextStyle(fontSize: mathFontSize, color: Colors.black),
                onErrorFallback: (e) => Text(token.text,
                  style: TextStyle(fontFamily: 'monospace',
                      fontSize: mathFontSize, color: Colors.red.shade700)),
              ),
            ),
          ),
        ));
      }
    }

    final repaintKey = GlobalKey();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -99999, top: -99999,
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(
            key: repaintKey,
            child: Container(
              color:   Colors.white,
              width:   maxWidth,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Directionality(
                textDirection: textDirection,
                child: RichText(
                  textDirection: textDirection,
                  softWrap:      true,
                  overflow:      TextOverflow.visible,
                  text: TextSpan(children: spans),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    await _waitForRender();

    try {
      final boundary = repaintKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('[MathImageRenderer] renderParagraph: boundary not found');
        entry.remove();
        return null;
      }
      final image    = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      entry.remove();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[MathImageRenderer] renderParagraph() error: $e');
      entry.remove();
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // parseParagraph()
  // ───────────────────────────────────────────────────────────────────────────
  static List<ParagraphToken> parseParagraph(String text) {
    final tokens  = <ParagraphToken>[];
    final pattern = RegExp(
      r'\$\$(.+?)\$\$|\$(.+?)\$|\\\[(.+?)\\\]|\\\((.+?)\\\)',
      dotAll: true,
    );
    int lastEnd = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        final chunk = text.substring(lastEnd, match.start).replaceAll('\n', ' ');
        if (chunk.isNotEmpty) tokens.add(ParagraphToken(text: chunk, isMath: false));
      }
      final latex = (match.group(1) ?? match.group(2) ??
                     match.group(3) ?? match.group(4) ?? '').trim();
      if (latex.isNotEmpty) tokens.add(ParagraphToken(text: latex, isMath: true));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      final tail = text.substring(lastEnd).replaceAll('\n', ' ');
      if (tail.isNotEmpty) tokens.add(ParagraphToken(text: tail, isMath: false));
    }
    return tokens;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // _waitForRender — flutter_math needs many frames to fully build WidgetSpans
  // FIX v7: more aggressive waiting — 8 initial frames + 500ms + 5 final frames
  // ───────────────────────────────────────────────────────────────────────────
  static Future<void> _waitForRender() async {
    // First pass: pump enough frames for widget tree to build
    for (int i = 0; i < 8; i++) {
      await WidgetsBinding.instance.endOfFrame;
    }
    // Give flutter_math time to complete async layout
    await Future.delayed(const Duration(milliseconds: 500));
    // Final pass: ensure painting is complete
    for (int i = 0; i < 5; i++) {
      await WidgetsBinding.instance.endOfFrame;
    }
  }
}