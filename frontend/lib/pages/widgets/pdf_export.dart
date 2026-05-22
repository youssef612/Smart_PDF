import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ════════════════════════════════════════════════════════
// Line classifier — outside PdfExporter class
// ════════════════════════════════════════════════════════

enum _LineType { h1, h2, h3, bullet, code, divider, blank, body }

List<Map<String, dynamic>> _classifyLines(List<String> rawLines) {
  final result = <Map<String, dynamic>>[];
  bool inCodeBlock = false;
  final codeBuffer = StringBuffer();

  for (final raw in rawLines) {
    final trimmed = raw.trim();

    if (trimmed.startsWith('```')) {
      if (!inCodeBlock) {
        inCodeBlock = true;
        codeBuffer.clear();
      } else {
        inCodeBlock = false;
        result.add({
          'type': _LineType.code,
          'content': codeBuffer.toString().trimRight(),
        });
        codeBuffer.clear();
      }
      continue;
    }
    if (inCodeBlock) {
      codeBuffer.writeln(raw);
      continue;
    }

    if (trimmed.isEmpty) {
      result.add({'type': _LineType.blank, 'content': ''});
      continue;
    }

    if (RegExp(r'^[-*_]{3,}$').hasMatch(trimmed)) {
      result.add({'type': _LineType.divider, 'content': ''});
      continue;
    }

    if (trimmed.startsWith('### ')) {
      result.add({
        'type': _LineType.h3,
        'content': _cleanInline(trimmed.substring(4).trim()),
      });
      continue;
    }
    if (trimmed.startsWith('## ')) {
      result.add({
        'type': _LineType.h2,
        'content': _cleanInline(trimmed.substring(3).trim()),
      });
      continue;
    }
    if (trimmed.startsWith('# ')) {
      result.add({
        'type': _LineType.h1,
        'content': _cleanInline(trimmed.substring(2).trim()),
      });
      continue;
    }

    if (trimmed.startsWith('**') &&
        trimmed.endsWith('**') &&
        !trimmed.substring(2, trimmed.length - 2).contains('**')) {
      result.add({
        'type': _LineType.h2,
        'content': _cleanInline(
          trimmed.substring(2, trimmed.length - 2).trim(),
        ),
      });
      continue;
    }

    if (RegExp(r'^[-*•]\s+').hasMatch(trimmed)) {
      final content = trimmed.replaceFirst(RegExp(r'^[-*•]\s+'), '');
      result.add({'type': _LineType.bullet, 'content': _cleanInline(content)});
      continue;
    }
    if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
      final content = trimmed.replaceFirst(RegExp(r'^\d+\.\s+'), '');
      result.add({'type': _LineType.bullet, 'content': _cleanInline(content)});
      continue;
    }

    result.add({'type': _LineType.body, 'content': _cleanInline(trimmed)});
  }

  return result;
}

String _fixReversedArabic(String text) {
  final arabicRatio =
      RegExp(r'[\u0600-\u06FF]').allMatches(text).length /
      (text.length > 0 ? text.length : 1);
  if (arabicRatio < 0.3) return text;
  return text
      .split(' ')
      .map((word) {
        final chars = word.split('');
        final isReversed =
            chars.length > 1 && RegExp(r'[\u0600-\u06FF]').hasMatch(word);
        return isReversed ? chars.reversed.join('') : word;
      })
      .join(' ');
}

pw.TextDirection _detectDirection(String text) {
  if (text.trim().isEmpty) return pw.TextDirection.ltr;
  final arabicCount = RegExp(r'[\u0600-\u06FF]').allMatches(text).length;
  final ratio = arabicCount / text.length;
  return ratio > 0.3 ? pw.TextDirection.rtl : pw.TextDirection.ltr;
}

String _cleanInline(String text) {

  text = PdfExporter._stripAndConvertMath(
    PdfExporter._normalizeDelimiters(text),
  );
  text = text.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*', dotAll: true),
    (m) => m[1] ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'\*(.+?)\*', dotAll: true),
    (m) => m[1] ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'__(.+?)__', dotAll: true),
    (m) => m[1] ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'_(.+?)_', dotAll: true),
    (m) => m[1] ?? '',
  );
  text = text.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1] ?? '');
  text = text.replaceAll(r'$$', '').replaceAll(r'$', '');
  return text.trim();
}

// ════════════════════════════════════════════════════════
// PdfExporter
// ════════════════════════════════════════════════════════

class PdfExporter {
  // ════════════════════════════════════════════════════════
  // exportQuestions
  // ════════════════════════════════════════════════════════
  static Future<void> exportQuestions({
    required BuildContext context,
    required List<Map<String, String>> questions,
    required String fileName,
    required bool isArabic,
  }) async {
    final fontRegular = pw.Font.ttf(
      await rootBundle.load(
        isArabic
            ? 'assets/fonts/NotoSansArabic-Regular.ttf'
            : 'assets/fonts/Inter-Regular.ttf',
      ),
    );
    final fontBold = pw.Font.ttf(
      await rootBundle.load(
        isArabic
            ? 'assets/fonts/NotoSansArabic-Bold.ttf'
            : 'assets/fonts/Inter-Bold.ttf',
      ),
    );
    final fontMath = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansMath-Regular.ttf'),
    );

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
      fontFallback: [fontMath],
    );

    // ✅ FIX: إعلان pdf مرة واحدة، وloop واحدة بس
    final pdf = pw.Document(theme: theme);

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final qText = _prepareText(q['question'] ?? '');
      final aText = _prepareText(q['answer'] ?? '');
      final type = q['type'] ?? '';
      final difficulty = q['difficulty'] ?? '';
      final diffBg = _diffColorBg(difficulty);
      final diffFg = _diffColorFg(difficulty);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          maxPages:      100000,
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          header: (_) => pw.Column(
            crossAxisAlignment: isArabic
                ? pw.CrossAxisAlignment.end
                : pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    fileName,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 16,
                      color: PdfColors.indigo700,
                    ),
                  ),
                  pw.Text(
                    'Q${i + 1} / ${questions.length}',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 11,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.indigo200, thickness: 1.5),
              pw.SizedBox(height: 6),
            ],
          ),
          build: (_) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.indigo100),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: isArabic
                    ? pw.CrossAxisAlignment.end
                    : pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: diffBg,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Text(
                      [
                        'Q${i + 1}',
                        if (type.isNotEmpty) '[$type]',
                        if (difficulty.isNotEmpty) '[$difficulty]',
                      ].join('  '),
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 14,
                        color: diffFg,
                      ),
                      textDirection: isArabic
                          ? pw.TextDirection.rtl
                          : pw.TextDirection.ltr,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    qText,
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 13,
                      lineSpacing: 4,
                    ),
                    textDirection: isArabic
                        ? pw.TextDirection.rtl
                        : pw.TextDirection.ltr,
                  ),
                  if (aText.isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    pw.Divider(color: PdfColors.green200),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      isArabic ? 'الإجابة:' : 'Answer:',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 12,
                        color: PdfColors.green700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor(0.945, 0.973, 0.914),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4),
                        ),
                      ),
                      child: pw.Text(
                        aText,
                        softWrap: true,
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 12,
                          color: PdfColors.grey800,
                          lineSpacing: 3,
                        ),
                        textDirection: isArabic
                            ? pw.TextDirection.rtl
                            : pw.TextDirection.ltr,
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

  // ════════════════════════════════════════════════════════
  // exportSummary
  // ════════════════════════════════════════════════════════
  static Future<void> exportSummary({
    required BuildContext context,
    required String summary,
    required String fileName,
    required bool isArabic,
  }) async {
    final fontArabicRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
    );
    final fontArabicBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'),
    );
    final fontLatinRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
    );
    final fontLatinBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
    );
    final fontMath = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansMath-Regular.ttf'),
    );

    final fontRegular = isArabic ? fontArabicRegular : fontLatinRegular;
    final fontBold = isArabic ? fontArabicBold : fontLatinBold;
    final fontMono = fontMath;

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
      fontFallback: isArabic
          ? [fontLatinRegular, fontMath]
          : [fontArabicRegular, fontMath],
    );

    final pdf = pw.Document(theme: theme);
    final classifiedLines = _classifyLines(summary.split('\n'));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        maxPages:      1000000,
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,

        header: (_) => pw.Column(
          crossAxisAlignment: isArabic
              ? pw.CrossAxisAlignment.end
              : pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  fileName,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 16,
                    color: PdfColors.indigo700,
                  ),
                ),
                pw.Text(
                  isArabic ? 'الملخص الذكي' : 'Smart Summary',
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 11,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
            pw.Divider(color: PdfColors.indigo200, thickness: 1.5),
            pw.SizedBox(height: 6),
          ],
        ),

        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.indigo100),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: isArabic
                  ? pw.CrossAxisAlignment.end
                  : pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  fileName,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 20,
                    color: PdfColors.indigo800,
                  ),
                  textDirection: isArabic
                      ? pw.TextDirection.rtl
                      : pw.TextDirection.ltr,
                ),
                pw.SizedBox(height: 4),
                pw.Divider(color: PdfColors.indigo200),
                pw.SizedBox(height: 12),

                ...classifiedLines.map((cl) {
                  final type = cl['type'] as _LineType;
                  final content = cl['content'] as String;

                  if (type == _LineType.blank) return pw.SizedBox(height: 8);

                  switch (type) {
                    case _LineType.h1:
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
                        child: pw.Text(
                          content,
                          softWrap: true,
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 16,
                            color: PdfColors.indigo800,
                          ),
                          textDirection: _detectDirection(content),
                        ),
                      );

                    case _LineType.h2:
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 14, bottom: 5),
                        child: pw.Text(
                          content,
                          softWrap: true,
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 14,
                            color: PdfColors.indigo700,
                          ),
                          textDirection: _detectDirection(content),
                        ),
                      );

                    case _LineType.h3:
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
                        child: pw.Text(
                          content,
                          softWrap: true,
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 13,
                            color: PdfColors.indigo600,
                          ),
                          textDirection: _detectDirection(content),
                        ),
                      );

                    case _LineType.bullet:
                      final bDir = _detectDirection(content);
                      final bRtl = bDir == pw.TextDirection.rtl;
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(
                          bottom: 4,
                          left: 12,
                          right: 12,
                        ),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (!bRtl)
                              pw.Text(
                                '• ',
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 12,
                                  color: PdfColors.indigo400,
                                ),
                              ),
                            pw.Expanded(
                              child: pw.Text(
                                content,
                                softWrap: true,
                                style: pw.TextStyle(
                                  font: fontRegular,
                                  fontSize: 12,
                                  color: PdfColors.grey900,
                                  lineSpacing: 3,
                                ),
                                textAlign: bRtl
                                    ? pw.TextAlign.right
                                    : pw.TextAlign.left,
                              ),
                            ),
                            if (bRtl)
                              pw.Text(
                                ' •',
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 12,
                                  color: PdfColors.indigo400,
                                ),
                              ),
                          ],
                        ),
                      );

                    case _LineType.code:
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6),
                        child: pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(4),
                            ),
                            border: pw.Border.all(color: PdfColors.grey300),
                          ),
                          child: pw.Text(
                            content,
                            softWrap: true,
                            style: pw.TextStyle(
                              font: fontMono,
                              fontSize: 11,
                              color: PdfColors.grey800,
                              lineSpacing: 3,
                            ),
                          ),
                        ),
                      );

                    case _LineType.divider:
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8),
                        child: pw.Divider(
                          color: PdfColors.indigo100,
                          thickness: 1,
                        ),
                      );

                    case _LineType.body:
                    default:
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(
                          content,
                          softWrap: true,
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 12,
                            color: PdfColors.grey900,
                            lineSpacing: 3,
                          ),
                          textDirection: _detectDirection(content),
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

  // ════════════════════════════════════════════════════════
  // Difficulty colors
  // ════════════════════════════════════════════════════════
  static PdfColor _diffColorBg(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const PdfColor(0.88, 0.97, 0.88);
      case 'medium':
        return const PdfColor(1.0, 0.95, 0.80);
      case 'hard':
        return const PdfColor(1.0, 0.87, 0.87);
      default:
        return PdfColors.indigo50;
    }
  }

  static PdfColor _diffColorFg(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return PdfColors.green800;
      case 'medium':
        return PdfColors.amber900;
      case 'hard':
        return PdfColors.red800;
      default:
        return PdfColors.indigo700;
    }
  }

  // ════════════════════════════════════════════════════════
  // Pipeline helpers
  // ════════════════════════════════════════════════════════

  static String _normalizeDelimiters(String text) {
    text = text.replaceAllMapped(
      RegExp(r'\\\[([\s\S]+?)\\\]', multiLine: true),
      (m) => '\n\$\$${(m[1] ?? '').trim()}\$\$\n',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\\((.+?)\\\)', dotAll: false),
      (m) => '\$${(m[1] ?? '').trim()}\$',
    );
    return text;
  }

  static String _fixOptionsLineBreaks(String text) {
    return text.replaceAllMapped(
      RegExp(r'(?<!\n)([A-D])\)\s+'),
      (m) => '\n${m[1]}) ',
    );
  }

  static String _fixPunctuationNewlines(String text) {
    return text.replaceAll(RegExp(r'\n+([.,;:])'), r'\1');
  }

  static String _fixInlineMathNewlines(String text) {
    return text.replaceAllMapped(
      RegExp(r'\n(\$[^\$\n]+\$)\n'),
      (m) => ' ${m[1]} ',
    );
  }

  // ════════════════════════════════════════════════════════
  // Matrix converter
  // ════════════════════════════════════════════════════════
  static String _convertMatrices(String text) {
    final matrixRe = RegExp(
      r'\\begin\{(p?matrix|b?matrix|[vVB]matrix|smallmatrix|array)\}([\s\S]+?)\\end\{\1\}',
    );

    return text.replaceAllMapped(matrixRe, (m) {
      final env = m[1] ?? 'matrix';
      final content = (m[2] ?? '').trim();

      String lDel = '', rDel = '';
      switch (env) {
        case 'pmatrix':
          lDel = '(';
          rDel = ')';
        case 'bmatrix':
          lDel = '[';
          rDel = ']';
        case 'vmatrix':
          lDel = '|';
          rDel = '|';
        case 'Vmatrix':
          lDel = '‖';
          rDel = '‖';
        case 'Bmatrix':
          lDel = '{';
          rDel = '}';
      }

      final rows = content.split(RegExp(r'\\\\'));
      final rowStrs = rows
          .map((row) {
            final cells = row.split('&').map((c) => c.trim()).join('  ');
            return cells;
          })
          .join('; ');

      return '$lDel$rowStrs$rDel';
    });
  }

  // ════════════════════════════════════════════════════════
  // LaTeX → readable Unicode
  // ════════════════════════════════════════════════════════
  static String _latexToReadable(String text) {
    text = _convertMatrices(text);

    text = text
        .replaceAll(RegExp(r'\\\['), '')
        .replaceAll(RegExp(r'\\\]'), '')
        .replaceAll(RegExp(r'\\\('), '')
        .replaceAll(RegExp(r'\\\)'), '');

    for (int pass = 0; pass < 8; pass++) {
      final before = text;
      text = _replaceFrac(text);
      if (text == before) break;
    }

    text = text.replaceAllMapped(
      RegExp(r'\\sqrt\[([^\]]+)\]\{([^{}]+)\}'),
      (m) => '${_toSuperscript(m[1] ?? '')}√(${m[2]})',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\sqrt\{([^{}]+)\}'),
      (m) => '√(${m[1]})',
    );
    text = text.replaceAllMapped(RegExp(r'\\sqrt\s+(\S+)'), (m) => '√${m[1]}');

    text = text.replaceAllMapped(
      RegExp(r'\\int_\{([^}]+)\}\^\{([^}]+)\}'),
      (m) => '∫[${m[1]}→${m[2]}]',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\int_(\S+)\^(\S+)'),
      (m) => '∫[${m[1]}→${m[2]}]',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\int_\{([^}]+)\}'),
      (m) => '∫[${m[1]}]',
    );
    text = text.replaceAll(r'\int', '∫');

    text = text.replaceAllMapped(
      RegExp(r'\\sum_\{([^}]+)\}\^\{([^}]+)\}'),
      (m) => 'Σ[${m[1]}→${m[2]}]',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\sum_(\S+)\^\{([^}]+)\}'),
      (m) => 'Σ[${m[1]}→${m[2]}]',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\sum_\{([^}]+)\}'),
      (m) => 'Σ[${m[1]}]',
    );
    text = text.replaceAllMapped(RegExp(r'\\sum_(\S+)'), (m) => 'Σ[${m[1]}]');
    text = text.replaceAll(r'\sum', 'Σ');

    text = text.replaceAllMapped(
      RegExp(r'\\prod_\{([^}]+)\}\^\{([^}]+)\}'),
      (m) => 'Π[${m[1]}→${m[2]}]',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\prod_(\S+)\^\{([^}]+)\}'),
      (m) => 'Π[${m[1]}→${m[2]}]',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\prod_\{([^}]+)\}'),
      (m) => 'Π[${m[1]}]',
    );
    text = text.replaceAllMapped(RegExp(r'\\prod_(\S+)'), (m) => 'Π[${m[1]}]');
    text = text.replaceAll(r'\prod', 'Π');

    text = text.replaceAllMapped(RegExp(r'\\lim_\{([^}]+)\}'), (m) {
      final inside = (m[1] ?? '')
          .replaceAll(r'\to', '→')
          .replaceAll(r'\rightarrow', '→');
      return 'lim[${inside.trim()}]';
    });
    text = text.replaceAllMapped(RegExp(r'\\lim_(\S+)'), (m) {
      final inside = (m[1] ?? '')
          .replaceAll(r'\to', '→')
          .replaceAll(r'\rightarrow', '→');
      return 'lim[${inside.trim()}]';
    });
    text = text.replaceAll(r'\lim', 'lim');

    text = text.replaceAllMapped(
      RegExp(r'\^\{([^}]+)\}'),
      (m) => _toSuperscriptStr(m[1] ?? ''),
    );
    const supMap = {
      '0': '⁰',
      '1': '¹',
      '2': '²',
      '3': '³',
      '4': '⁴',
      '5': '⁵',
      '6': '⁶',
      '7': '⁷',
      '8': '⁸',
      '9': '⁹',
      '+': '⁺',
      '-': '⁻',
      'n': 'ⁿ',
      'm': 'ᵐ',
      'k': 'ᵏ',
    };
    text = text.replaceAllMapped(
      RegExp(r'\^([0-9+\-nmk])'),
      (m) => supMap[m[1]] ?? '^${m[1]}',
    );
    text = text.replaceAllMapped(RegExp(r'\^\{([^}]*)\}'), (m) => '^(${m[1]})');

    text = text.replaceAllMapped(
      RegExp(r'_\{([^}]+)\}'),
      (m) => _toSubscriptStr(m[1] ?? ''),
    );
    const subMap = {
      '0': '₀',
      '1': '₁',
      '2': '₂',
      '3': '₃',
      '4': '₄',
      '5': '₅',
      '6': '₆',
      '7': '₇',
      '8': '₈',
      '9': '₉',
      'n': 'ₙ',
      'm': 'ₘ',
      'k': 'ₖ',
      'i': 'ᵢ',
    };
    text = text.replaceAllMapped(
      RegExp(r'_([0-9nmki])'),
      (m) => subMap[m[1]] ?? '_${m[1]}',
    );

    text = text.replaceAllMapped(
      RegExp(r'\\math(?:bf|rm|it|cal|bb|sf|tt)\{([^}]+)\}'),
      (m) => m[1] ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\text(?:rm|bf|it|normal)?\{([^}]+)\}'),
      (m) => m[1] ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\operatorname\{([^}]+)\}'),
      (m) => m[1] ?? '',
    );

    text = text.replaceAllMapped(
      RegExp(r'\\vec\{([^}]+)\}'),
      (m) => '${m[1]}⃗',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\hat\{([^}]+)\}'),
      (m) => '${m[1]}̂',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\bar\{([^}]+)\}'),
      (m) => '${m[1]}̄',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\tilde\{([^}]+)\}'),
      (m) => '${m[1]}̃',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\dot\{([^}]+)\}'),
      (m) => '${m[1]}̇',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\ddot\{([^}]+)\}'),
      (m) => '${m[1]}̈',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\overline\{([^}]+)\}'),
      (m) => '${m[1]}̄',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\underline\{([^}]+)\}'),
      (m) => '${m[1]}',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\widehat\{([^}]+)\}'),
      (m) => '${m[1]}̂',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\widetilde\{([^}]+)\}'),
      (m) => '${m[1]}̃',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\acute\{([^}]+)\}'),
      (m) => '${m[1]}́',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\grave\{([^}]+)\}'),
      (m) => '${m[1]}̀',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\check\{([^}]+)\}'),
      (m) => '${m[1]}̌',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\breve\{([^}]+)\}'),
      (m) => '${m[1]}̆',
    );

    text = text.replaceAllMapped(
      RegExp(r'\\underbrace\{([^}]+)\}_\{([^}]+)\}'),
      (m) => '${m[1]}[${m[2]}]',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\overbrace\{([^}]+)\}\^\{([^}]+)\}'),
      (m) => '${m[1]}[${m[2]}]',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\underbrace\{([^}]+)\}'),
      (m) => m[1] ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\overbrace\{([^}]+)\}'),
      (m) => m[1] ?? '',
    );

    text = text
        .replaceAll(r'\varphi', 'φ')
        .replaceAll(r'\phi', 'φ')
        .replaceAll(r'\psi', 'ψ')
        .replaceAll(r'\chi', 'χ')
        .replaceAll(r'\alpha', 'α')
        .replaceAll(r'\beta', 'β')
        .replaceAll(r'\gamma', 'γ')
        .replaceAll(r'\Gamma', 'Γ')
        .replaceAll(r'\delta', 'δ')
        .replaceAll(r'\Delta', 'Δ')
        .replaceAll(r'\epsilon', 'ε')
        .replaceAll(r'\varepsilon', 'ε')
        .replaceAll(r'\zeta', 'ζ')
        .replaceAll(r'\eta', 'η')
        .replaceAll(r'\theta', 'θ')
        .replaceAll(r'\Theta', 'Θ')
        .replaceAll(r'\vartheta', 'ϑ')
        .replaceAll(r'\iota', 'ι')
        .replaceAll(r'\kappa', 'κ')
        .replaceAll(r'\lambda', 'λ')
        .replaceAll(r'\Lambda', 'Λ')
        .replaceAll(r'\mu', 'μ')
        .replaceAll(r'\nu', 'ν')
        .replaceAll(r'\xi', 'ξ')
        .replaceAll(r'\Xi', 'Ξ')
        .replaceAll(r'\pi', 'π')
        .replaceAll(r'\Pi', 'Π')
        .replaceAll(r'\varpi', 'ϖ')
        .replaceAll(r'\rho', 'ρ')
        .replaceAll(r'\varrho', 'ϱ')
        .replaceAll(r'\sigma', 'σ')
        .replaceAll(r'\Sigma', 'Σ')
        .replaceAll(r'\varsigma', 'ς')
        .replaceAll(r'\tau', 'τ')
        .replaceAll(r'\upsilon', 'υ')
        .replaceAll(r'\omega', 'ω')
        .replaceAll(r'\Omega', 'Ω');

    text = text
        .replaceAll(r'\partial', '∂')
        .replaceAll(r'\nabla', '∇')
        .replaceAll(r'\infty', '∞')
        .replaceAll(r'\hbar', 'ℏ')
        .replaceAll(r'\ell', 'ℓ')
        .replaceAll(r'\Re', 'ℜ')
        .replaceAll(r'\Im', 'ℑ')
        .replaceAll(r'\wp', '℘')
        .replaceAll(r'\aleph', 'ℵ')
        .replaceAll(r'\cdot', '·')
        .replaceAll(r'\cdots', '…')
        .replaceAll(r'\ldots', '…')
        .replaceAll(r'\vdots', '⋮')
        .replaceAll(r'\ddots', '⋱')
        .replaceAll(r'\times', '×')
        .replaceAll(r'\div', '÷')
        .replaceAll(r'\pm', '±')
        .replaceAll(r'\mp', '∓')
        .replaceAll(r'\circ', '∘')
        .replaceAll(r'\bullet', '•')
        .replaceAll(r'\oplus', '⊕')
        .replaceAll(r'\otimes', '⊗')
        .replaceAll(r'\ominus', '⊖')
        .replaceAll(r'\wedge', '∧')
        .replaceAll(r'\land', '∧')
        .replaceAll(r'\vee', '∨')
        .replaceAll(r'\lor', '∨')
        .replaceAll(r'\neg', '¬')
        .replaceAll(r'\leq', '≤')
        .replaceAll(r'\le', '≤')
        .replaceAll(r'\geq', '≥')
        .replaceAll(r'\ge', '≥')
        .replaceAll(r'\ll', '≪')
        .replaceAll(r'\gg', '≫')
        .replaceAll(r'\neq', '≠')
        .replaceAll(r'\ne', '≠')
        .replaceAll(r'\approx', '≈')
        .replaceAll(r'\simeq', '≃')
        .replaceAll(r'\sim', '∼')
        .replaceAll(r'\cong', '≅')
        .replaceAll(r'\equiv', '≡')
        .replaceAll(r'\propto', '∝')
        .replaceAll(r'\perp', '⊥')
        .replaceAll(r'\parallel', '∥')
        .replaceAll(r'\in', '∈')
        .replaceAll(r'\notin', '∉')
        .replaceAll(r'\ni', '∋')
        .replaceAll(r'\subset', '⊂')
        .replaceAll(r'\supset', '⊃')
        .replaceAll(r'\subseteq', '⊆')
        .replaceAll(r'\supseteq', '⊇')
        .replaceAll(r'\cup', '∪')
        .replaceAll(r'\cap', '∩')
        .replaceAll(r'\setminus', '∖')
        .replaceAll(r'\emptyset', '∅')
        .replaceAll(r'\varnothing', '∅')
        .replaceAll(r'\forall', '∀')
        .replaceAll(r'\exists', '∃')
        .replaceAll(r'\nexists', '∄')
        .replaceAll(r'\Rightarrow', '⟹')
        .replaceAll(r'\Leftarrow', '⟸')
        .replaceAll(r'\Leftrightarrow', '⟺')
        .replaceAll(r'\rightarrow', '→')
        .replaceAll(r'\leftarrow', '←')
        .replaceAll(r'\leftrightarrow', '↔')
        .replaceAll(r'\longrightarrow', '⟶')
        .replaceAll(r'\longleftarrow', '⟵')
        .replaceAll(r'\mapsto', '↦')
        .replaceAll(r'\hookrightarrow', '↪')
        .replaceAll(r'\to', '→')
        .replaceAll(r'\gets', '←')
        .replaceAll(r'\uparrow', '↑')
        .replaceAll(r'\downarrow', '↓')
        .replaceAll(r'\nearrow', '↗')
        .replaceAll(r'\searrow', '↘');

    text = text
        .replaceAll(r'\sin', 'sin')
        .replaceAll(r'\cos', 'cos')
        .replaceAll(r'\tan', 'tan')
        .replaceAll(r'\cot', 'cot')
        .replaceAll(r'\sec', 'sec')
        .replaceAll(r'\csc', 'csc')
        .replaceAll(r'\arcsin', 'arcsin')
        .replaceAll(r'\arccos', 'arccos')
        .replaceAll(r'\arctan', 'arctan')
        .replaceAll(r'\sinh', 'sinh')
        .replaceAll(r'\cosh', 'cosh')
        .replaceAll(r'\tanh', 'tanh')
        .replaceAll(r'\ln', 'ln')
        .replaceAll(r'\log', 'log')
        .replaceAll(r'\exp', 'exp')
        .replaceAll(r'\max', 'max')
        .replaceAll(r'\min', 'min')
        .replaceAll(r'\sup', 'sup')
        .replaceAll(r'\inf', 'inf')
        .replaceAll(r'\det', 'det')
        .replaceAll(r'\deg', 'deg')
        .replaceAll(r'\dim', 'dim')
        .replaceAll(r'\ker', 'ker')
        .replaceAll(r'\gcd', 'gcd');

    text = text
        .replaceAll(r'\left(', '(')
        .replaceAll(r'\right)', ')')
        .replaceAll(r'\left[', '[')
        .replaceAll(r'\right]', ']')
        .replaceAll(r'\left\{', '{')
        .replaceAll(r'\right\}', '}')
        .replaceAll(r'\left|', '|')
        .replaceAll(r'\right|', '|')
        .replaceAll(r'\left\|', '‖')
        .replaceAll(r'\right\|', '‖')
        .replaceAll(r'\langle', '⟨')
        .replaceAll(r'\rangle', '⟩')
        .replaceAll(r'\lceil', '⌈')
        .replaceAll(r'\rceil', '⌉')
        .replaceAll(r'\lfloor', '⌊')
        .replaceAll(r'\rfloor', '⌋')
        .replaceAll(r'\left', '')
        .replaceAll(r'\right', '');

    text = text
        .replaceAll(r'\quad', ' ')
        .replaceAll(r'\qquad', '  ')
        .replaceAll(r'\,', ' ')
        .replaceAll(r'\;', ' ')
        .replaceAll(r'\:', ' ')
        .replaceAll(r'\!', '')
        .replaceAll(r'\prime', "'")
        .replaceAll(r"\'", "'")
        .replaceAll(r'\%', '%')
        .replaceAll(r'\#', '#')
        .replaceAll(r'\&', '&')
        .replaceAll(r'\\', ' ');

    text = text.replaceAll(r'$$', '').replaceAll(r'$', '');

    for (int pass = 0; pass < 5; pass++) {
      final before = text;
      text = text.replaceAllMapped(RegExp(r'\{([^{}]*)\}'), (m) => m[1] ?? '');
      if (text == before) break;
    }

    text = text.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');
    text = text.replaceAll('\\', '');
    text = text.replaceAll(RegExp(r' {2,}'), ' ').trim();

    return text;
  }

  // ════════════════════════════════════════════════════════
  // \frac parser
  // ════════════════════════════════════════════════════════
  static String _replaceFrac(String text) {
    final buf = StringBuffer();
    int i = 0;
    while (i < text.length) {
      final fracIdx = text.indexOf(r'\frac', i);
      if (fracIdx == -1) {
        buf.write(text.substring(i));
        break;
      }
      buf.write(text.substring(i, fracIdx));
      i = fracIdx + 5;

      final numResult = _extractBraces(text, i);
      if (numResult == null) {
        buf.write(r'\frac');
        continue;
      }
      i = numResult.$2;

      final denResult = _extractBraces(text, i);
      if (denResult == null) {
        buf.write('(${numResult.$1} / ?)');
        continue;
      }
      i = denResult.$2;

      buf.write('(${numResult.$1} / ${denResult.$1})');
    }
    return buf.toString();
  }

  static (String, int)? _extractBraces(String text, int start) {
    int i = start;
    while (i < text.length && text[i] == ' ') i++;
    if (i >= text.length || text[i] != '{') return null;

    int depth = 0;
    final content = StringBuffer();
    i++;
    while (i < text.length) {
      final c = text[i];
      if (c == '{') {
        depth++;
        content.write(c);
      } else if (c == '}') {
        if (depth == 0) {
          return (content.toString(), i + 1);
        }
        depth--;
        content.write(c);
      } else {
        content.write(c);
      }
      i++;
    }
    return null;
  }

  // ════════════════════════════════════════════════════════
  // Superscript / subscript helpers
  // ════════════════════════════════════════════════════════
  static String _toSuperscript(String s) {
    const map = {
      '0': '⁰',
      '1': '¹',
      '2': '²',
      '3': '³',
      '4': '⁴',
      '5': '⁵',
      '6': '⁶',
      '7': '⁷',
      '8': '⁸',
      '9': '⁹',
      '+': '⁺',
      '-': '⁻',
      'n': 'ⁿ',
      'm': 'ᵐ',
      'k': 'ᵏ',
    };
    return s.split('').map((c) => map[c] ?? c).join();
  }

  static String _toSuperscriptStr(String s) {
    const map = {
      '0': '⁰',
      '1': '¹',
      '2': '²',
      '3': '³',
      '4': '⁴',
      '5': '⁵',
      '6': '⁶',
      '7': '⁷',
      '8': '⁸',
      '9': '⁹',
      '+': '⁺',
      '-': '⁻',
      'n': 'ⁿ',
      'm': 'ᵐ',
      'k': 'ᵏ',
      'a': 'ᵃ',
      'b': 'ᵇ',
      'c': 'ᶜ',
      'd': 'ᵈ',
      'e': 'ᵉ',
      'f': 'ᶠ',
      'g': 'ᵍ',
      'h': 'ʰ',
      'i': 'ⁱ',
      'j': 'ʲ',
      'p': 'ᵖ',
      'r': 'ʳ',
      's': 'ˢ',
      't': 'ᵗ',
      'u': 'ᵘ',
      'v': 'ᵛ',
      'w': 'ʷ',
      'x': 'ˣ',
      'y': 'ʸ',
      'z': 'ᶻ',
    };
    final chars = s.split('');
    final converted = chars.map((c) => map[c]).toList();
    if (converted.every((c) => c != null)) {
      return converted.join();
    }
    return '^($s)';
  }

  static String _toSubscriptStr(String s) {
    const map = {
      '0': '₀',
      '1': '₁',
      '2': '₂',
      '3': '₃',
      '4': '₄',
      '5': '₅',
      '6': '₆',
      '7': '₇',
      '8': '₈',
      '9': '₉',
      'n': 'ₙ',
      'm': 'ₘ',
      'k': 'ₖ',
      'i': 'ᵢ',
      'j': 'ⱼ',
      'a': 'ₐ',
      'e': 'ₑ',
      'o': 'ₒ',
      'r': 'ᵣ',
      'u': 'ᵤ',
      'v': 'ᵥ',
      'x': 'ₓ',
    };
    final chars = s.split('');
    final converted = chars.map((c) => map[c]).toList();
    if (converted.every((c) => c != null)) {
      return converted.join();
    }
    return '₍$s₎';
  }

  // ════════════════════════════════════════════════════════
  // _stripAndConvertMath
  // ════════════════════════════════════════════════════════
  static String _stripAndConvertMath(String text) {
    text = text.replaceAllMapped(
      RegExp(r'\$\$([\s\S]+?)\$\$', dotAll: true),
      (m) => '\n${_latexToReadable(m[1] ?? '')}\n',
    );
    text = text.replaceAllMapped(
      RegExp(r'\$([^\$\n]+?)\$'),
      (m) => _latexToReadable(m[1] ?? ''),
    );
    text = text.replaceAllMapped(
      RegExp(r'\\\[([\s\S]+?)\\\]', multiLine: true),
      (m) => '\n${_latexToReadable(m[1] ?? '')}\n',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\\((.+?)\\\)', dotAll: false),
      (m) => _latexToReadable(m[1] ?? ''),
    );
    return text;
  }

  // ════════════════════════════════════════════════════════
  // _prepareText — pipeline كامل
  // ════════════════════════════════════════════════════════
  static String _prepareText(String text) {
    text = _normalizeDelimiters(text);
    text = _fixInlineMathNewlines(text);
    text = _fixPunctuationNewlines(text);
    text = _fixOptionsLineBreaks(text);
    text = text.replaceAll(RegExp(r'#{0,2}QSEP##', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
    text = _stripAndConvertMath(text);
    text = text.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*', dotAll: true),
      (m) => m[1] ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'\*(.+?)\*', dotAll: true),
      (m) => m[1] ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'__(.+?)__', dotAll: true),
      (m) => m[1] ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'_(.+?)_', dotAll: true),
      (m) => m[1] ?? '',
    );
    text = text.replaceAll(RegExp(r'^-{3,}\s*$', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return text;
  }
}
