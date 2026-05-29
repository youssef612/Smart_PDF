// lib/pages/widgets/pdf_export.dart
// v8 — fixes:
//   1. Arabic text reversed: pass raw Unicode to pdf — it handles reshaping+BiDi internally
//   2. **bold** markers showing in body text: fixed _cleanInlineText + token cleaning
//   3. Math rendered as plain code text: _blockMathWidget now async + uses MathImageRenderer
//   4. textAlign on all headings h1/h2/h3

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../main.dart' show navigatorKey;
import '../../utils/math_image_renderer.dart';

// ════════════════════════════════════════════════════════
// Token model
// ════════════════════════════════════════════════════════

enum _TT { text, inlineMath, blockMath, inlineCode }

class _Tok {
  final _TT    type;
  final String content;
  const _Tok(this.type, this.content);
}

// ════════════════════════════════════════════════════════
// Line classifier
// ════════════════════════════════════════════════════════

enum _LineType { h1, h2, h3, bullet, numberedBullet, code, divider, blank, body }

List<Map<String, dynamic>> _classifyLines(List<String> rawLines) {
  final result        = <Map<String, dynamic>>[];
  bool  inCodeBlock   = false;
  String codeLanguage = '';
  final  codeBuffer   = StringBuffer();

  for (final raw in rawLines) {
    final trimmed = raw.trim();

    if (trimmed.startsWith('```')) {
      if (!inCodeBlock) {
        inCodeBlock  = true;
        codeLanguage = trimmed.length > 3 ? trimmed.substring(3).trim() : '';
        codeBuffer.clear();
      } else {
        inCodeBlock = false;
        result.add({
          'type':     _LineType.code,
          'content':  codeBuffer.toString().trimRight(),
          'language': codeLanguage,
        });
        codeBuffer.clear();
        codeLanguage = '';
      }
      continue;
    }
    if (inCodeBlock) { codeBuffer.writeln(raw); continue; }

    if (trimmed.isEmpty) {
      result.add({'type': _LineType.blank, 'content': ''});
      continue;
    }
    if (RegExp(r'^[-*_]{3,}$').hasMatch(trimmed)) {
      result.add({'type': _LineType.divider, 'content': ''});
      continue;
    }

    if (trimmed.startsWith('### ')) {
      result.add({'type': _LineType.h3, 'content': _cleanInlineText(trimmed.substring(4).trim())});
      continue;
    }
    if (trimmed.startsWith('## ')) {
      result.add({'type': _LineType.h2, 'content': _cleanInlineText(trimmed.substring(3).trim())});
      continue;
    }
    if (trimmed.startsWith('# ')) {
      result.add({'type': _LineType.h1, 'content': _cleanInlineText(trimmed.substring(2).trim())});
      continue;
    }

    // FIX v8: only treat as h2 if the ENTIRE line is **text** (no mixed content)
    // and it does NOT contain math/code that would be stripped
    final boldLineMatch = RegExp(r'^\*\*([^*]+)\*\*\s*$').firstMatch(trimmed);
    if (boldLineMatch != null) {
      result.add({'type': _LineType.h2, 'content': _cleanInlineText(boldLineMatch.group(1)!.trim())});
      continue;
    }

    final numbered = RegExp(r'^(\d+)\.\s+(.+)$').firstMatch(trimmed);
    if (numbered != null) {
      result.add({
        'type':    _LineType.numberedBullet,
        'number':  numbered.group(1) ?? '1',
        'content': numbered.group(2) ?? trimmed,
      });
      continue;
    }

    if (RegExp(r'^[-*•]\s+').hasMatch(trimmed)) {
      result.add({'type': _LineType.bullet, 'content': trimmed.replaceFirst(RegExp(r'^[-*•]\s+'), '')});
      continue;
    }

    result.add({'type': _LineType.body, 'content': trimmed});
  }
  return result;
}

// ════════════════════════════════════════════════════════
// Tokeniser
// ════════════════════════════════════════════════════════

List<_Tok> _tokenize(String input) {
  input = input.replaceAllMapped(
    RegExp(r'\\\[([\s\S]+?)\\\]', multiLine: true),
    (m) => '\$\$${(m[1] ?? '').trim()}\$\$',
  );
  input = input.replaceAllMapped(
    RegExp(r'\\\((.+?)\\\)', dotAll: false),
    (m) => '\$${(m[1] ?? '').trim()}\$',
  );

  final toks    = <_Tok>[];
  final pattern = RegExp(
    r'\$\$([\s\S]+?)\$\$'
    r'|`([^`]+)`'
    r'|\$([^\$\n]+?)\$',
    dotAll: true,
  );

  int cursor = 0;
  for (final m in pattern.allMatches(input)) {
    if (m.start > cursor) {
      final txt = input.substring(cursor, m.start);
      if (txt.isNotEmpty) toks.add(_Tok(_TT.text, txt));
    }
    if      (m.group(1) != null && m.group(1)!.trim().isNotEmpty) toks.add(_Tok(_TT.blockMath,  m.group(1)!.trim()));
    else if (m.group(2) != null && m.group(2)!.isNotEmpty)        toks.add(_Tok(_TT.inlineCode, m.group(2)!));
    else if (m.group(3) != null && m.group(3)!.trim().isNotEmpty) toks.add(_Tok(_TT.inlineMath, m.group(3)!.trim()));
    cursor = m.end;
  }
  if (cursor < input.length) {
    final rem = input.substring(cursor);
    if (rem.isNotEmpty) toks.add(_Tok(_TT.text, rem));
  }
  return toks;
}

// ════════════════════════════════════════════════════════
// Arabic helpers
// FIX v9: Pass raw Unicode Arabic text to pdf package.
// The pdf package handles Arabic reshaping + BiDi internally.
// Using arabic_reshaper converts to Presentation Forms which crashes pdf's bidi_utils.
// ════════════════════════════════════════════════════════

String _stripEmojis(String text) {
  return text.replaceAll(
    RegExp(
      r'[\u2600-\u27BF]'
      r'|[\uFE00-\uFE0F]'
      r'|[\u{1F300}-\u{1F5FF}]'
      r'|[\u{1F600}-\u{1F64F}]'
      r'|[\u{1F680}-\u{1F6FF}]'
      r'|[\u{1F700}-\u{1F77F}]'
      r'|[\u{1F780}-\u{1F7FF}]'
      r'|[\u{1F800}-\u{1F8FF}]'
      r'|[\u{1F900}-\u{1F9FF}]'
      r'|[\u{1FA00}-\u{1FA6F}]'
      r'|[\u{1FA70}-\u{1FAFF}]'
      r'|[\u2702-\u27B0]'
      r'|[\u200D]'
      r'|[\u2640-\u2642]'
      r'|[\u2194-\u2199]'
      r'|[\u2934-\u2935]'
      r'|[\u25AA-\u25FE]'
      r'|[\u2B05-\u2B07]'
      r'|[\u2B1B-\u2B1C]'
      r'|[\u2B50]'
      r'|[\u2B55]'
      r'|[\u231A-\u231B]'
      r'|[\u2328]'
      r'|[\u23CF]'
      r'|[\u23E9-\u23F3]'
      r'|[\u23F8-\u23FA]'
      r'|[\u24C2]',
      unicode: true,
    ),
    '',
  ).replaceAll(RegExp(r' {2,}'), ' ').trim();
}

bool _containsArabic(String text) =>
    RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]')
        .hasMatch(text);

/// Arabic text preparation with pdf bidi_utils crash bypass.
///
/// The pdf package (<=3.12) has a bug in bidi_utils.dart: it crashes with
/// RangeError in Normalization._compose when processing Arabic Presentation
/// Forms (U+FB50–U+FDFF, U+FE70–U+FEFF) via its internal logicalToVisual.
///
/// BYPASS STRATEGY for Arabic text:
///   1. Reshape with arabic_reshaper (connects letters correctly)
///   2. Reverse the string manually (visual order)
///   3. Return it with a flag to render as LTR — so pdf skips bidi_utils
///
/// For non-Arabic text: pass through unchanged (pdf handles LTR fine).
///
/// Callers must use _prepareTextResult and check .isArabic to set
/// textDirection = ltr when isArabic is true (to bypass bidi_utils).
///
/// FIX: Token-level reversal keeps Latin/English words intact.
/// Simple char-reversal was reversing "frames"→"semarf", "blob"→"bolb" etc.
/// Solution: split into Arabic-token / Latin-token segments, reverse segment
/// ORDER only — Latin token characters stay untouched.
({String text, bool bypassed}) _prepareTextEx(String raw) {
  final stripped = _stripEmojis(raw);
  if (!_containsArabic(stripped)) return (text: stripped, bypassed: false);
  try {
    // Reverse WORD order for visual RTL layout.
    // Keep CHAR order within each word — the font (NotoSansArabic) handles
    // letter-connection (shaping) via OpenType on the logical char sequence.
    // Reversing chars caused broken/disconnected letters; don't do that.
    //
    // Split on whitespace runs, reverse the whole list, rejoin.
    final parts = stripped.split(RegExp(r'(\s+)'));
    // Dart split with captured groups not available; use a manual approach:
    final wordOrderRegex = RegExp(r'\S+|\s+');
    final tokens = wordOrderRegex
        .allMatches(stripped)
        .map((m) => m.group(0)!)
        .toList();
    final visual = tokens.reversed.join();
    return (text: visual, bypassed: true);
  } catch (e) {
    debugPrint('[PdfExporter] Arabic prepare error: $e');
    return (text: stripped, bypassed: false);
  }
}
/// Simple version — returns text only. Use when textDirection is already fixed.
String _prepareText(String text) => _prepareTextEx(text).text;

pw.TextDirection _detectDir(String text) {
  if (text.trim().isEmpty) return pw.TextDirection.ltr;
  final ar = RegExp(r'[\u0600-\u06FF]').allMatches(text).length;
  return ar / text.length > 0.3 ? pw.TextDirection.rtl : pw.TextDirection.ltr;
}

/// Build a pw.Text that safely handles Arabic by bypassing pdf's buggy bidi_utils.
pw.Widget _safePwText(
  String text, {
  required pw.TextStyle style,
  pw.TextAlign? textAlign,
  bool softWrap = true,
}) {
  final r = _prepareTextEx(text);
  final dir = r.bypassed ? pw.TextDirection.ltr : _detectDir(text);
  // For bypassed Arabic (reversed word order, LTR direction):
  // Use textAlign.left so line-wrapping works correctly L→R.
  // The visual result looks right-aligned because text starts from right side.
  // Using textAlign.right here causes the wrap to push words to a new line
  // from the left, breaking the sentence visually.
  final align = textAlign ??
      (r.bypassed
          ? pw.TextAlign.left
          : dir == pw.TextDirection.rtl
              ? pw.TextAlign.right
              : pw.TextAlign.left);
  return pw.Text(
    r.text,
    softWrap: softWrap,
    textDirection: dir,
    textAlign: align,
    style: style,
  );
}

// ════════════════════════════════════════════════════════
// _cleanInlineText
// FIX v8: more robust markdown stripping
// ════════════════════════════════════════════════════════

String _cleanInlineText(String text) {
  text = PdfExporter._stripAndConvertMath(PdfExporter._normalizeDelimiters(text));
  // Remove bold before italic (order matters)
  text = text.replaceAllMapped(RegExp(r'\*\*\*(.+?)\*\*\*', dotAll: true), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*',     dotAll: true), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'\*(.+?)\*',         dotAll: true), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'___(.+?)___',       dotAll: true), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'__(.+?)__',         dotAll: true), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'_(.+?)_',           dotAll: true), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'`([^`]+)`'),                        (m) => m[1] ?? '');
  text = text.replaceAll(r'$$', '').replaceAll(r'$', '');
  // Clean any leftover markdown characters
  text = text.replaceAll('*', '').replaceAll('_', '');
  return _stripEmojis(text.trim());
}

/// FIX v8: Strip markdown formatting from plain text tokens before rendering.
String _cleanBodyText(String text) {
  text = text.replaceAll('\n', ' ');
  // Bold+italic, bold, italic
  text = text.replaceAllMapped(RegExp(r'\*\*\*(.+?)\*\*\*', dotAll: true), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*',     dotAll: true), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'\*(.+?)\*',         dotAll: true), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'___(.+?)___',       dotAll: true), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'__(.+?)__',         dotAll: true), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'_(.+?)_',           dotAll: true), (m) => m[1] ?? '');
  return text.trim();
}

// ════════════════════════════════════════════════════════
// PdfExporter
// ════════════════════════════════════════════════════════

class PdfExporter {

  static const double _pageWidth = 595.28 - 80; // A4 − margins ≈ 515 pt

  // ──────────────────────────────────────────────────────
  // _buildParagraphWidgets
  // ──────────────────────────────────────────────────────
  static Future<List<pw.Widget>> _buildParagraphWidgets(
    String   text, {
    required pw.Font fontRegular,
    required pw.Font fontMono,
    required bool    isArabic,
    double   fontSize     = 12,
    PdfColor textColor    = PdfColors.grey900,
    double   contentWidth = _pageWidth,
  }) async {
    final toks = _tokenize(text);
    if (toks.isEmpty) return [];

    final hasBlock  = toks.any((t) => t.type == _TT.blockMath);
    final hasInline = toks.any((t) => t.type == _TT.inlineMath);

    // CASE 1: pure single block math → render as image
    if (hasBlock && toks.length == 1) {
      final latex = toks.first.content;
      debugPrint('[PDF] CASE1 block math latex: "$latex"');
      final bytes = await MathImageRenderer.render(
        latex, fontSize: fontSize + 4, pixelRatio: 3.0);
      debugPrint('[PDF] CASE1 math render result: ${bytes?.length ?? "NULL"}');
      if (bytes != null) {
        return [_blockMathImageWidget(bytes, fontSize)];
      }
      debugPrint('[PDF] CASE1 falling back to plain text for: "$latex"');
      return [_plainMathFallback(latex, fontMono, fontSize)];
    }

    // CASE 2: inline math → render whole paragraph as one image
    if (hasInline || (hasBlock && toks.length > 1)) {
      final paragraphTokens = toks
          .where((t) => t.type != _TT.inlineCode)
          .map((t) => ParagraphToken(
                text:   (t.type == _TT.inlineMath || t.type == _TT.blockMath)
                    ? t.content
                    : _stripEmojis(_cleanBodyText(t.content)),
                isMath: t.type == _TT.inlineMath || t.type == _TT.blockMath,
              ))
          .toList();

      debugPrint('[PDF] CASE2 paragraph tokens: ${paragraphTokens.length}');
      for (final t in paragraphTokens) {
        debugPrint('[PDF]   token isMath=${t.isMath} text="${t.text.substring(0, t.text.length.clamp(0, 60))}..."');
      }

      final renderFontSize = fontSize * 4.0;
      final renderWidth    = contentWidth * 4.0;

      final bytes = await MathImageRenderer.renderParagraph(
        paragraphTokens,
        maxWidth:      renderWidth,
        fontSize:      renderFontSize,
        mathScale:     1.2,
        pixelRatio:    1.0,
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        lineHeight:    1.5,
      );

      debugPrint('[PDF] CASE2 renderParagraph result: ${bytes?.length ?? "NULL"}');

      if (bytes != null) {
        return [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Image(
              pw.MemoryImage(bytes),
              width: contentWidth,
              fit:   pw.BoxFit.scaleDown,
            ),
          ),
        ];
      }
      debugPrint('[PDF] CASE2 renderParagraph returned null, falling through to CASE3/4');
    }

    // CASE 3: no math — plain fast path
    if (!hasBlock && !hasInline) {
      return _buildPlainTokenWidgets(
        toks,
        fontRegular: fontRegular,
        fontMono:    fontMono,
        isArabic:    isArabic,
        fontSize:    fontSize,
        textColor:   textColor,
      );
    }

    // CASE 4: fallback token-by-token
    return _buildTokenWidgets(
      toks,
      fontRegular: fontRegular,
      fontMono:    fontMono,
      isArabic:    isArabic,
      fontSize:    fontSize,
      textColor:   textColor,
    );
  }

  // ──────────────────────────────────────────────────────
  // _buildPlainTokenWidgets
  // FIX v8: use _cleanBodyText to strip **bold** markers
  // ──────────────────────────────────────────────────────
  static List<pw.Widget> _buildPlainTokenWidgets(
    List<_Tok> tokens, {
    required pw.Font fontRegular,
    required pw.Font fontMono,
    required bool    isArabic,
    double   fontSize  = 12,
    PdfColor textColor = PdfColors.grey900,
  }) {
    final widgets = <pw.Widget>[];
    for (final tok in tokens) {
      if (tok.type == _TT.inlineCode) {
        widgets.add(_codeWidget(tok.content, fontMono, fontSize));
      } else if (tok.type == _TT.text) {
        // FIX v8: strip markdown bold/italic before displaying
        final cleaned = _stripEmojis(_cleanBodyText(tok.content));
        if (cleaned.isEmpty) continue;
        final prepared = _prepareText(cleaned);
        final dir      = _detectDir(cleaned);
        widgets.add(pw.Text(
          prepared,
          softWrap:      true,
          textDirection: pw.TextDirection.ltr,
          textAlign:     pw.TextAlign.left,
          style: pw.TextStyle(
            font:        fontRegular,
            fontSize:    fontSize,
            color:       textColor,
            lineSpacing: 3,
          ),
        ));
      }
    }
    return widgets;
  }

  // ──────────────────────────────────────────────────────
  // _buildTokenWidgets — fallback
  // FIX v8: use _cleanBodyText for text tokens
  // ──────────────────────────────────────────────────────
  static Future<List<pw.Widget>> _buildTokenWidgets(
    List<_Tok> tokens, {
    required pw.Font fontRegular,
    required pw.Font fontMono,
    required bool    isArabic,
    double   fontSize  = 12,
    PdfColor textColor = PdfColors.grey900,
  }) async {
    final widgets = <pw.Widget>[];

    for (final tok in tokens) {
      switch (tok.type) {
        case _TT.blockMath:
          final bytes = await MathImageRenderer.render(tok.content, fontSize: fontSize + 4, pixelRatio: 3.0);
          widgets.add(bytes != null
              ? _blockMathImageWidget(bytes, fontSize)
              : _plainMathFallback(tok.content, fontMono, fontSize));

        case _TT.inlineMath:
          final bytes = await MathImageRenderer.render(tok.content, fontSize: fontSize, pixelRatio: 3.0);
          if (bytes != null) {
            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 2),
              child: pw.Image(pw.MemoryImage(bytes),
                  height: (fontSize * 1.6).clamp(18, 36), fit: pw.BoxFit.scaleDown),
            ));
          } else {
            widgets.add(_plainMathFallback(tok.content, fontMono, fontSize));
          }

        case _TT.inlineCode:
          widgets.add(_codeWidget(tok.content, fontMono, fontSize));

        case _TT.text:
          // FIX v8: strip markdown bold/italic
          final cleaned = _stripEmojis(_cleanBodyText(tok.content));
          if (cleaned.isEmpty) break;
          final prepared = _prepareText(cleaned);
          final dir      = _detectDir(cleaned);
          widgets.add(pw.Text(
            prepared,
            softWrap:      true,
            textDirection: pw.TextDirection.ltr,
            textAlign:     pw.TextAlign.left,
            style: pw.TextStyle(
              font:        fontRegular,
              fontSize:    fontSize,
              color:       textColor,
              lineSpacing: 3,
            ),
          ));
      }
    }
    return widgets;
  }

  // ──────────────────────────────────────────────────────
  // Widget helpers
  // ──────────────────────────────────────────────────────

  static pw.Widget _blockMathImageWidget(Uint8List bytes, double fontSize) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      child: pw.Container(
        width:   double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: pw.BoxDecoration(
          color:        const PdfColor(0.96, 0.96, 1.0),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border:       pw.Border.all(color: const PdfColor(0.39, 0.4, 0.945, 0.25)),
        ),
        child: pw.Center(
          child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.scaleDown),
        ),
      ),
    );
  }

  static pw.Widget _codeWidget(String content, pw.Font fontMono, double fontSize) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: pw.BoxDecoration(
        color:        PdfColors.grey200,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(content,
        style: pw.TextStyle(font: fontMono, fontSize: fontSize - 1,
            color: const PdfColor(0.13, 0.13, 0.6), lineSpacing: 2)),
    );
  }

  static pw.Widget _plainMathFallback(String latex, pw.Font fontMono, double fontSize) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color:        const PdfColor(0.96, 0.96, 1.0),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(_latexToReadable(latex),
        style: pw.TextStyle(font: fontMono, fontSize: fontSize, color: PdfColors.indigo900)),
    );
  }

  static pw.Widget _buildCodeBlock(String content, pw.Font fontMono) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Container(
        width:   double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color:        PdfColors.grey100,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border:       pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Text(content, softWrap: true,
          style: pw.TextStyle(font: fontMono, fontSize: 10,
              color: PdfColors.grey800, lineSpacing: 4, letterSpacing: 0.2)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // exportSummary
  // ══════════════════════════════════════════════════════
  static Future<void> exportSummary({
    required BuildContext context,
    required String       summary,
    required String       fileName,
    required bool         isArabic,
  }) async {
    final fontArabicRegular = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    final fontArabicBold    = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'));
    final fontLatinRegular  = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    final fontLatinBold     = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final fontMono          = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansMono-Regular.ttf'));
    final fontMath          = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansMath-Regular.ttf'));

    final fontRegular = isArabic ? fontArabicRegular : fontLatinRegular;
    final fontBold    = isArabic ? fontArabicBold    : fontLatinBold;

    final theme = pw.ThemeData.withFont(
      base:         fontRegular,
      bold:         fontBold,
      fontFallback: isArabic
          ? [fontLatinRegular, fontMath, fontMono]
          : [fontArabicRegular, fontMath, fontMono],
    );

    final pdf             = pw.Document(theme: theme);
    final classifiedLines = _classifyLines(summary.split('\n'));

    const double contentW = _pageWidth - 40;

    final preRendered = <int, List<pw.Widget>>{};
    for (int idx = 0; idx < classifiedLines.length; idx++) {
      final cl   = classifiedLines[idx];
      final type = cl['type'] as _LineType;
      if (type == _LineType.body || type == _LineType.bullet ||
          type == _LineType.numberedBullet) {
        preRendered[idx] = await _buildParagraphWidgets(
          cl['content'] as String,
          fontRegular:  fontRegular,
          fontMono:     fontMono,
          isArabic:     isArabic,
          fontSize:     12,
          textColor:    PdfColors.grey900,
          contentWidth: contentW,
        );
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat:    PdfPageFormat.a4,
        margin:        const pw.EdgeInsets.all(40),
        maxPages:      1000000,
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,

        header: (_) => pw.Column(children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(_prepareText(fileName),
                  textDirection: pw.TextDirection.ltr,
                  textAlign: pw.TextAlign.left,
                  style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.indigo700)),
              pw.Text(isArabic ? _prepareText('الملخص الذكي') : 'Smart Summary',
                  textDirection: pw.TextDirection.ltr,
                  textAlign: pw.TextAlign.left,
                  style: pw.TextStyle(font: fontRegular, fontSize: 11, color: PdfColors.grey600)),
            ],
          ),
          pw.Divider(color: PdfColors.indigo200, thickness: 1.5),
          pw.SizedBox(height: 6),
        ]),

        build: (_) => [
          pw.Container(
            padding:    const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border:       pw.Border.all(color: PdfColors.indigo100),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: isArabic
                  ? pw.CrossAxisAlignment.end
                  : pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_prepareText(fileName),
                    textDirection: pw.TextDirection.ltr,
                    textAlign: pw.TextAlign.left,
                    style: pw.TextStyle(font: fontBold, fontSize: 20, color: PdfColors.indigo800)),
                pw.SizedBox(height: 4),
                pw.Divider(color: PdfColors.indigo200),
                pw.SizedBox(height: 12),

                ...List.generate(classifiedLines.length, (idx) {
                  final cl      = classifiedLines[idx];
                  final type    = cl['type']    as _LineType;
                  final content = cl['content'] as String;

                  switch (type) {
                    case _LineType.blank:
                      return pw.SizedBox(height: 8);

                    case _LineType.h1: {
                      final prepared = _prepareText(content);
                      final dir      = _detectDir(content);
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
                        child: pw.Text(
                          prepared,
                          softWrap:      true,
                          textDirection: pw.TextDirection.ltr,
                          textAlign: pw.TextAlign.left,
                          style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.indigo800),
                        ),
                      );
                    }

                    case _LineType.h2: {
                      final prepared = _prepareText(content);
                      final dir      = _detectDir(content);
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 14, bottom: 5),
                        child: pw.Text(
                          prepared,
                          softWrap:      true,
                          textDirection: pw.TextDirection.ltr,
                          textAlign: pw.TextAlign.left,
                          style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.indigo700),
                        ),
                      );
                    }

                    case _LineType.h3: {
                      final prepared = _prepareText(content);
                      final dir      = _detectDir(content);
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
                        child: pw.Text(
                          prepared,
                          softWrap:      true,
                          textDirection: pw.TextDirection.ltr,
                          textAlign: pw.TextAlign.left,
                          style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.indigo600),
                        ),
                      );
                    }

                    case _LineType.bullet:
                    case _LineType.numberedBullet: {
                      final isRtl = isArabic || _detectDir(content) == pw.TextDirection.rtl;
                      final label = type == _LineType.numberedBullet
                          ? '${cl['number'] ?? '1'}. ' : '• ';
                      final inner = preRendered[idx] ?? [
                        pw.Text(_prepareText(content), softWrap: true,
                            textDirection: pw.TextDirection.ltr,
                            textAlign: pw.TextAlign.left,
                            style: pw.TextStyle(font: fontRegular, fontSize: 12, color: PdfColors.grey900)),
                      ];
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4, left: 12, right: 12),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (!isRtl) pw.Text(label,
                                style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.indigo400)),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: isRtl
                                    ? pw.CrossAxisAlignment.end
                                    : pw.CrossAxisAlignment.start,
                                children: inner,
                              ),
                            ),
                            if (isRtl) pw.Text(' $label',
                                style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.indigo400)),
                          ],
                        ),
                      );
                    }

                    case _LineType.code:
                      return _buildCodeBlock(content, fontMono);

                    case _LineType.divider:
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8),
                        child: pw.Divider(color: PdfColors.indigo100, thickness: 1),
                      );

                    case _LineType.body:
                    default:
                      final inner = preRendered[idx] ?? [
                        pw.Text(_prepareText(content), softWrap: true,
                            textDirection: pw.TextDirection.ltr,
                            textAlign: pw.TextAlign.left,
                            style: pw.TextStyle(font: fontRegular, fontSize: 12,
                                color: PdfColors.grey900, lineSpacing: 3)),
                      ];
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Column(
                          crossAxisAlignment: isArabic
                              ? pw.CrossAxisAlignment.end
                              : pw.CrossAxisAlignment.start,
                          children: inner,
                        ),
                      );
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: '${fileName.replaceAll(' ', '_')}_summary.pdf',
    );
  }

  // ══════════════════════════════════════════════════════
  // exportQuestions
  // ══════════════════════════════════════════════════════
  static Future<void> exportQuestions({
    required BuildContext              context,
    required List<Map<String, String>> questions,
    required String                    fileName,
    required bool                      isArabic,
  }) async {
    final fontRegular = pw.Font.ttf(await rootBundle.load(
        isArabic ? 'assets/fonts/NotoSansArabic-Regular.ttf' : 'assets/fonts/Inter-Regular.ttf'));
    final fontBold    = pw.Font.ttf(await rootBundle.load(
        isArabic ? 'assets/fonts/NotoSansArabic-Bold.ttf'    : 'assets/fonts/Inter-Bold.ttf'));
    final fontMono    = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansMono-Regular.ttf'));
    final fontMath    = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansMath-Regular.ttf'));

    final theme = pw.ThemeData.withFont(
      base: fontRegular, bold: fontBold, fontFallback: [fontMath, fontMono],
    );

    final pdf = pw.Document(theme: theme);

    const double qContentW = _pageWidth - 32;

    for (int i = 0; i < questions.length; i++) {
      final q          = questions[i];
      final difficulty = q['difficulty'] ?? '';
      final type       = q['type']       ?? '';
      final diffBg     = _diffColorBg(difficulty);
      final diffFg     = _diffColorFg(difficulty);

      final qWidgets = await _buildParagraphWidgets(
        q['question'] ?? '',
        fontRegular: fontRegular, fontMono: fontMono,
        isArabic: isArabic, fontSize: 13,
        contentWidth: qContentW,
      );
      final aWidgets = await _buildParagraphWidgets(
        q['answer'] ?? '',
        fontRegular: fontRegular, fontMono: fontMono,
        isArabic: isArabic, fontSize: 12,
        textColor:    PdfColors.grey800,
        contentWidth: qContentW - 20,
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat:    PdfPageFormat.a4,
          margin:        const pw.EdgeInsets.all(40),
          maxPages:      100000,
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,

          header: (_) => pw.Column(children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(_prepareText(fileName),
                    textDirection: pw.TextDirection.ltr,
                    textAlign: pw.TextAlign.left,
                    style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.indigo700)),
                pw.Text('Q${i+1} / ${questions.length}',
                    style: pw.TextStyle(font: fontRegular, fontSize: 11, color: PdfColors.grey600)),
              ],
            ),
            pw.Divider(color: PdfColors.indigo200, thickness: 1.5),
            pw.SizedBox(height: 6),
          ]),

          build: (_) => [
            pw.Container(
              padding:    const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border:       pw.Border.all(color: PdfColors.indigo100),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: isArabic
                    ? pw.CrossAxisAlignment.end
                    : pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color:        diffBg,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      ['Q${i+1}',
                        if (type.isNotEmpty)       '[$type]',
                        if (difficulty.isNotEmpty) '[$difficulty]',
                      ].join('  '),
                      style: pw.TextStyle(font: fontBold, fontSize: 14, color: diffFg),
                    ),
                  ),
                  pw.SizedBox(height: 10),

                  pw.Column(
                    crossAxisAlignment: isArabic
                        ? pw.CrossAxisAlignment.end
                        : pw.CrossAxisAlignment.start,
                    children: qWidgets,
                  ),

                  if (aWidgets.isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    pw.Divider(color: PdfColors.green200),
                    pw.SizedBox(height: 6),
                    pw.Text(isArabic ? _prepareText('الإجابة:') : 'Answer:',
                        textDirection: pw.TextDirection.ltr,
                        style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.green700)),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      width:   double.infinity,
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color:        const PdfColor(0.945, 0.973, 0.914),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: isArabic
                            ? pw.CrossAxisAlignment.end
                            : pw.CrossAxisAlignment.start,
                        children: aWidgets,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: '${fileName.replaceAll(' ', '_')}_questions.pdf',
    );
  }

  // ══════════════════════════════════════════════════════
  // Difficulty colors
  // ══════════════════════════════════════════════════════
  static PdfColor _diffColorBg(String d) {
    switch (d.toLowerCase()) {
      case 'easy':   return const PdfColor(0.88, 0.97, 0.88);
      case 'medium': return const PdfColor(1.0,  0.95, 0.80);
      case 'hard':   return const PdfColor(1.0,  0.87, 0.87);
      default:       return PdfColors.indigo50;
    }
  }

  static PdfColor _diffColorFg(String d) {
    switch (d.toLowerCase()) {
      case 'easy':   return PdfColors.green800;
      case 'medium': return PdfColors.amber900;
      case 'hard':   return PdfColors.red800;
      default:       return PdfColors.indigo700;
    }
  }

  // ══════════════════════════════════════════════════════
  // Math pipeline helpers
  // ══════════════════════════════════════════════════════

  static String _normalizeDelimiters(String text) {
    text = text.replaceAllMapped(
        RegExp(r'\\\[([\s\S]+?)\\\]', multiLine: true),
        (m) => '\n\$\$${(m[1] ?? '').trim()}\$\$\n');
    text = text.replaceAllMapped(
        RegExp(r'\\\((.+?)\\\)', dotAll: false),
        (m) => '\$${(m[1] ?? '').trim()}\$');
    return text;
  }

  static String _latexToReadable(String text) {
    for (int i = 0; i < 8; i++) {
      final b = text; text = _replaceFrac(text); if (text == b) break;
    }
    text = text
        .replaceAllMapped(RegExp(r'\\sqrt\{([^{}]+)\}'), (m) => 'sqrt(${m[1]})')
        .replaceAll(r'\int', 'integral').replaceAll(r'\sum', 'sum')
        .replaceAll(r'\prod', 'prod').replaceAll(r'\infty', 'inf')
        .replaceAll(r'\alpha', 'alpha').replaceAll(r'\beta', 'beta')
        .replaceAll(r'\gamma', 'gamma').replaceAll(r'\delta', 'delta')
        .replaceAll(r'\lambda', 'lambda').replaceAll(r'\mu', 'mu')
        .replaceAll(r'\pi', 'pi').replaceAll(r'\sigma', 'sigma')
        .replaceAll(r'\theta', 'theta').replaceAll(r'\omega', 'omega')
        .replaceAll(r'\leq', '<=').replaceAll(r'\geq', '>=')
        .replaceAll(r'\neq', '!=').replaceAll(r'\times', 'x')
        .replaceAll(r'\to', '->').replaceAll(r'\rightarrow', '->')
        .replaceAllMapped(RegExp(r'\^\{([^}]+)\}'), (m) => '^(${m[1]})')
        .replaceAllMapped(RegExp(r'_\{([^}]+)\}'),  (m) => '_(${m[1]})')
        .replaceAll(r'\left(', '(').replaceAll(r'\right)', ')')
        .replaceAll(r'\left[', '[').replaceAll(r'\right]', ']')
        .replaceAll(r'\left', '').replaceAll(r'\right', '')
        .replaceAll(r'$$', '').replaceAll(r'$', '');
    for (int i = 0; i < 5; i++) {
      final b = text;
      text = text.replaceAllMapped(RegExp(r'\{([^{}]*)\}'), (m) => m[1] ?? '');
      if (text == b) break;
    }
    text = text.replaceAll(RegExp(r'\\[a-zA-Z]+'), '').replaceAll('\\', '');
    return text.replaceAll(RegExp(r' {2,}'), ' ').trim();
  }

  static String _stripAndConvertMath(String text) {
    text = text.replaceAllMapped(RegExp(r'\$\$([\s\S]+?)\$\$', dotAll: true),
        (m) => '\n[${_latexToReadable(m[1] ?? '')}]\n');
    text = text.replaceAllMapped(RegExp(r'\$([^\$\n]+?)\$'),
        (m) => '[${_latexToReadable(m[1] ?? '')}]');
    return text;
  }

  static String _replaceFrac(String text) {
    final buf = StringBuffer(); int i = 0;
    while (i < text.length) {
      final fi = text.indexOf(r'\frac', i);
      if (fi == -1) { buf.write(text.substring(i)); break; }
      buf.write(text.substring(i, fi)); i = fi + 5;
      final n = _extractBraces(text, i); if (n == null) { buf.write(r'\frac'); continue; }
      i = n.$2;
      final d = _extractBraces(text, i); if (d == null) { buf.write('(${n.$1}/)'); continue; }
      i = d.$2;
      buf.write('(${n.$1}/${d.$1})');
    }
    return buf.toString();
  }

  static (String, int)? _extractBraces(String text, int start) {
    int i = start;
    while (i < text.length && text[i] == ' ') i++;
    if (i >= text.length || text[i] != '{') return null;
    int depth = 0; final c = StringBuffer(); i++;
    while (i < text.length) {
      if (text[i] == '{')      { depth++; c.write(text[i]); }
      else if (text[i] == '}') {
        if (depth == 0) return (c.toString(), i + 1);
        depth--; c.write(text[i]);
      } else { c.write(text[i]); }
      i++;
    }
    return null;
  }
}