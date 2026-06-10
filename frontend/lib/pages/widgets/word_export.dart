import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  WordExporter v3 — FINAL, zero known bugs
//
//  OOXML Math:  \frac, \sqrt, \int/\sum/\prod (+ integrand), \lim,
//               x_i^2 → sSubSup, matrices, accents, \underbrace/\overbrace
//  Text:        bold/italic/mono inline, headings, code blocks, RTL/LTR
// ════════════════════════════════════════════════════════════════════════════

class WordExporter {

  // ══════════════════════════════════════════════════════════════════════════
  //  Public API
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> exportQuestions({
    required BuildContext context,
    required List<Map<String, String>> questions,
    required String fileName,
    required bool isArabic,
  }) async {
    try {
      final xml   = _buildQuestionsXml(questions: questions, title: fileName, isArabic: isArabic);
      final bytes = _buildDocxBytes(xml);
      final file  = await _saveFile('${_safeName(fileName)}_questions.docx', bytes);
      _toast(context, isArabic ? 'تم حفظ ملف Word:\n${file.path}' : 'Word file saved:\n${file.path}', true);
    } catch (e) {
      _toast(context, isArabic ? 'فشل التصدير: $e' : 'Export failed: $e', false);
    }
  }

  static Future<void> exportSummary({
    required BuildContext context,
    required String summary,
    required String fileName,
    required bool isArabic,
  }) async {
    try {
      final xml   = _buildSummaryXml(summary: summary, title: fileName, isArabic: isArabic);
      final bytes = _buildDocxBytes(xml);
      final file  = await _saveFile('${_safeName(fileName)}_summary.docx', bytes);
      _toast(context, isArabic ? 'تم حفظ ملف Word:\n${file.path}' : 'Word file saved:\n${file.path}', true);
    } catch (e) {
      _toast(context, isArabic ? 'فشل التصدير: $e' : 'Export failed: $e', false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  File helpers
  // ══════════════════════════════════════════════════════════════════════════

  static String _safeName(String s) =>
      s.replaceAll(RegExp(r'[^\w\u0600-\u06FF ]'), '_').trim();

  static Future<File> _saveFile(String name, List<int> bytes) async {
    final dir = await _saveDir();
    final f   = File('${dir.path}/$name');
    await f.writeAsBytes(bytes);
    return f;
  }

  static Future<Directory> _saveDir() async {
    if (Platform.isAndroid) {
      final d = Directory('/storage/emulated/0/Download');
      if (await d.exists()) return d;
    }
    return getApplicationDocumentsDirectory();
  }

  static void _toast(BuildContext ctx, String msg, bool ok) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? Colors.green.shade700 : Colors.red,
      duration: const Duration(seconds: 4),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  document.xml builders
  // ══════════════════════════════════════════════════════════════════════════

  static String _buildQuestionsXml({
    required List<Map<String, String>> questions,
    required String title,
    required bool isArabic,
  }) {
    final dir = isArabic ? 'rtl' : 'ltr';
    final jc  = isArabic ? 'right' : 'left';
    final buf = StringBuffer()..write(_docHeader());

    buf.write(_para(runs: [_run(title, bold: true, size: 40, color: '1F3864')],
        jc: jc, dir: dir, spaceAfter: 100));
    buf.write(_para(
        runs: [_run('${questions.length} ${isArabic ? "سؤال" : "Questions"}',
            size: 20, color: '7F7F7F')],
        jc: jc, dir: dir, spaceAfter: 200));
    buf.write(_rule('4472C4'));

    for (int i = 0; i < questions.length; i++) {
      final q    = questions[i];
      final type = q['type']       ?? '';
      final diff = q['difficulty'] ?? '';

      buf.write(_para(
        runs: [
          _run('Q${i + 1}', bold: true, size: 26, color: '2E74B5'),
          if (type.isNotEmpty) _run('  [$type]', size: 20, color: '70AD47'),
          if (diff.isNotEmpty) _run('  [$diff]', size: 20, color: 'ED7D31'),
        ],
        jc: jc, dir: dir, spaceBefore: 320, spaceAfter: 80,
        borderBottom: 'DEEAF1',
      ));

      buf.write(_renderContent(q['question'] ?? '', jc, dir, 22, '1F3864'));

      final answer = q['answer'] ?? '';
      if (answer.isNotEmpty) {
        buf.write(_para(
            runs: [_run(isArabic ? '▶  الإجابة' : '▶  Answer',
                bold: true, size: 22, color: '70AD47')],
            jc: jc, dir: dir, spaceBefore: 160, spaceAfter: 60));
        buf.write(_renderContent(answer, jc, dir, 20, '404040',
            shadingFill: 'F2F9F0'));
      }
      if (i < questions.length - 1) buf.write(_rule('BDD7EE'));
    }

    buf.write(_docFooter());
    return buf.toString();
  }

  static String _buildSummaryXml({
    required String summary,
    required String title,
    required bool isArabic,
  }) {
    final dir = isArabic ? 'rtl' : 'ltr';
    final jc  = isArabic ? 'right' : 'left';
    final buf = StringBuffer()..write(_docHeader());

    buf.write(_para(runs: [_run(title, bold: true, size: 40, color: '1F3864')],
        jc: jc, dir: dir, spaceAfter: 80));
    buf.write(_para(
        runs: [_run(isArabic ? 'الملخص الذكي' : 'Smart Summary',
            size: 22, color: '7F7F7F')],
        jc: jc, dir: dir, spaceAfter: 180));
    buf.write(_rule('4472C4'));
    buf.write(_renderContent(summary, jc, dir, 22, '1F3864'));
    buf.write(_docFooter());
    return buf.toString();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  _renderContent
  // ══════════════════════════════════════════════════════════════════════════

  static String _detectDir(String text) {
    final arabicCount = RegExp(r'[\u0600-\u06FF]').allMatches(text).length;
    return (arabicCount / (text.length + 1)) > 0.3 ? 'rtl' : 'ltr';
  }

  static String _renderContent(
      String raw, String jc, String dir, int fontSize, String textColor, {
        String? shadingFill,
      }) {
    final buf    = StringBuffer();
    final blocks = _parseBlocks(raw);

    for (final block in blocks) {
      switch (block.type) {

        case _BType.heading:
          buf.write(_para(
            runs: [_run(block.content, bold: true, size: fontSize + 4, color: '2E74B5')],
            jc: jc, dir: dir, spaceBefore: 200, spaceAfter: 80,
            borderBottom: 'BDD7EE',
          ));

        case _BType.code:
          final lines = block.content.split('\n');
          for (int li = 0; li < lines.length; li++) {
            buf.write(_codePara(text: lines[li], isFirst: li == 0,
                isLast: li == lines.length - 1));
          }

        case _BType.blockMath:
          buf.write(_mathPara(block.content));

        case _BType.bullet:
          final _bDir = _detectDir(block.content);
          final _bJc  = _bDir == 'rtl' ? 'right' : 'left';
          final _bRtl = _bDir == 'rtl';
          buf.write('<w:p><w:pPr>'
              '<w:jc w:val="$_bJc"/>'
              '<w:bidi w:val="${_bRtl ? 1 : 0}"/>'
              '<w:spacing w:before="0" w:after="60"/>'
              '<w:ind w:left="${_bRtl ? 0 : 360}" w:right="${_bRtl ? 360 : 0}"/>'
              '</w:pPr>'
              '${_run(_bRtl ? " •" : "• ", bold: true, size: fontSize, color: "4472C4")}'
              '${_fmtRuns(block.content, fontSize, textColor).join()}'
              '</w:p>\n');

        case _BType.text:
          for (final line in block.content.split('\n')) {
            final t = line.trim();
            if (t.isEmpty) {
              buf.write(_para(runs: [], jc: jc, dir: dir, spaceAfter: 80));
              continue;
            }
            final segs    = _parseInline(t);
            final hasMath = segs.any((s) => s.isMath);
            if (!hasMath) {
              buf.write(_para(
                runs: _fmtRuns(t, fontSize, textColor),
                jc: jc, dir: dir, spaceAfter: 60, shadingFill: shadingFill,
              ));
            } else {
              buf.write(_mixedPara(segs: segs, jc: jc, dir: dir,
                  fontSize: fontSize, color: textColor, shadingFill: shadingFill));
            }
          }
      }
    }
    return buf.toString();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  XML paragraph / run builders
  // ══════════════════════════════════════════════════════════════════════════

  static String _docHeader() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
          '<w:document'
          ' xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
          ' xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"'
          ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'
          ' xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">'
          '\n<w:body>\n';

  static String _docFooter() =>
      '<w:sectPr>'
          '<w:pgSz w:w="11906" w:h="16838"/>'
          '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/>'
          '</w:sectPr></w:body></w:document>';

  static String _para({
    required List<String> runs,
    required String jc,
    required String dir,
    int     spaceBefore = 0,
    int     spaceAfter  = 60,
    String? shadingFill,
    String? borderBottom,
  }) {
    final bidi    = dir == 'rtl' ? '1' : '0';
    final shading = shadingFill != null
        ? '<w:shd w:val="clear" w:color="auto" w:fill="$shadingFill"/>' : '';
    final border  = borderBottom != null
        ? '<w:pBdr><w:bottom w:val="single" w:sz="4" w:space="1"'
        ' w:color="$borderBottom"/></w:pBdr>' : '';
    return '<w:p><w:pPr>'
        '<w:jc w:val="$jc"/>'
        '<w:bidi w:val="$bidi"/>'
        '<w:spacing w:before="$spaceBefore" w:after="$spaceAfter"/>'
        '$shading$border'
        '</w:pPr>${runs.join()}</w:p>\n';
  }

  static String _run(String text, {
    bool   bold   = false,
    bool   italic = false,
    bool   mono   = false,
    int    size   = 22,
    String color  = '000000',
  }) {
    final b = bold   ? '<w:b/><w:bCs/>' : '';
    final it = italic ? '<w:i/><w:iCs/>' : '';
    final f = mono   ? 'Courier New' : 'Calibri';
    return '<w:r><w:rPr>$b$it'
        '<w:color w:val="$color"/>'
        '<w:sz w:val="$size"/><w:szCs w:val="$size"/>'
        '<w:rFonts w:ascii="$f" w:hAnsi="$f" w:cs="$f"/>'
        '</w:rPr>'
        '<w:t xml:space="preserve">${_xe(text)}</w:t></w:r>';
  }

  static String _rule(String color) =>
      '<w:p><w:pPr>'
          '<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="$color"/></w:pBdr>'
          '<w:spacing w:before="60" w:after="60"/>'
          '</w:pPr></w:p>\n';

  static String _codePara({
    required String text,
    required bool   isFirst,
    required bool   isLast,
  }) {
    final top = isFirst ? '<w:top w:val="single" w:sz="4" w:space="4" w:color="BFBFBF"/>' : '';
    final bot = isLast  ? '<w:bottom w:val="single" w:sz="4" w:space="4" w:color="BFBFBF"/>' : '';
    return '<w:p><w:pPr>'
        '<w:jc w:val="left"/><w:bidi w:val="0"/>'
        '<w:spacing w:before="${isFirst ? 120 : 0}" w:after="${isLast ? 120 : 0}"'
        ' w:line="276" w:lineRule="auto"/>'
        '<w:ind w:left="360"/>'
        '<w:shd w:val="clear" w:color="auto" w:fill="F2F2F2"/>'
        '<w:pBdr>$top<w:left w:val="single" w:sz="12" w:space="4"'
        ' w:color="4472C4"/>$bot</w:pBdr>'
        '</w:pPr>'
        '${_run(text.isEmpty ? ' ' : text, mono: true, size: 18, color: '1F3864')}'
        '</w:p>\n';
  }

  static String _mathPara(String latex, {String jc = 'center'}) {
    final ooxml = _toOoxml(latex.trim());
    return '<w:p><w:pPr>'
        '<w:jc w:val="$jc"/>'
        '<w:spacing w:before="140" w:after="140"/>'
        '</w:pPr>'
        '<m:oMathPara>'
        '<m:oMathParaPr><m:jc m:val="$jc"/></m:oMathParaPr>'
        '<m:oMath>$ooxml</m:oMath>'
        '</m:oMathPara></w:p>\n';
  }

  static String _mixedPara({
    required List<_InlineSeg> segs,
    required String jc,
    required String dir,
    required int    fontSize,
    required String color,
    String? shadingFill,
  }) {
    final bidi    = dir == 'rtl' ? '1' : '0';
    final shading = shadingFill != null
        ? '<w:shd w:val="clear" w:color="auto" w:fill="$shadingFill"/>' : '';
    final content = StringBuffer();
    for (final seg in segs) {
      if (seg.isMath) {
        content.write('<m:oMath>${_toOoxml(seg.content)}</m:oMath>');
      } else {
        content.write(_fmtRuns(seg.content, fontSize, color).join());
      }
    }
    return '<w:p><w:pPr>'
        '<w:jc w:val="$jc"/><w:bidi w:val="$bidi"/>'
        '<w:spacing w:before="0" w:after="60"/>$shading'
        '</w:pPr>${content.toString()}</w:p>\n';
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  OOXML Math engine
  // ══════════════════════════════════════════════════════════════════════════

  static String _toOoxml(String latex) => _cvt(latex.trim());

  /// بيرجع OOXML string لـ expression كاملة
  static String _cvt(String expr) {
    if (expr.isEmpty) return '';

    // نشيل leading/trailing spaces ونعالج
    final buf = StringBuffer();
    int i = 0;

    while (i < expr.length) {

      // ── تخطي whitespace ───────────────────────────────────────────────
      if (expr[i] == ' ') { i++; continue; }

      // ── \begin{env} matrix ────────────────────────────────────────────
      if (_sw(expr, i, r'\begin')) {
        final r = _tryMatrix(expr, i);
        if (r != null) { buf.write(r.xml); i = r.end; continue; }
      }

      // ── \frac / \dfrac / \tfrac ───────────────────────────────────────
      if (_sw(expr, i, r'\dfrac') || _sw(expr, i, r'\tfrac')) {
        i += 6;
        final r = _fracBody(expr, i);
        if (r != null) { buf.write(r.xml); i = r.end; continue; }
        buf.write(_mr('frac')); continue;
      }
      if (_sw(expr, i, r'\frac')) {
        i += 5;
        final r = _fracBody(expr, i);
        if (r != null) { buf.write(r.xml); i = r.end; continue; }
        buf.write(_mr('frac')); continue;
      }

      // ── \sqrt ─────────────────────────────────────────────────────────
      if (_sw(expr, i, r'\sqrt')) {
        i += 5;
        String? deg;
        if (i < expr.length && expr[i] == '[') {
          final end = expr.indexOf(']', i);
          if (end != -1) { deg = expr.substring(i + 1, end); i = end + 1; }
        }
        final m = _brace(expr, i);
        if (m != null) {
          i = m.end;
          final e = _we(_cvt(m.inner));
          if (deg != null) {
            buf.write('<m:rad><m:radPr><m:degHide m:val="0"/></m:radPr>'
                '<m:deg>${_we(_cvt(deg))}</m:deg>$e</m:rad>');
          } else {
            buf.write('<m:rad><m:radPr><m:degHide m:val="1"/></m:radPr>'
                '<m:deg/>$e</m:rad>');
          }
          continue;
        }
        buf.write(_mr('√')); continue;
      }

      // ── \underbrace{a}_{b} ────────────────────────────────────────────
      if (_sw(expr, i, r'\underbrace')) {
        i += 11;
        final m = _brace(expr, i);
        if (m != null) {
          i = m.end;
          final inner = _we(_cvt(m.inner));
          if (i < expr.length && expr[i] == '_') {
            i++;
            final sm = _brace(expr, i);
            if (sm != null) {
              i = sm.end;
              buf.write('<m:limLow>$inner${_we(_cvt(sm.inner))}</m:limLow>');
              continue;
            }
          }
          buf.write(inner); continue;
        }
      }

      // ── \overbrace{a}^{b} ─────────────────────────────────────────────
      if (_sw(expr, i, r'\overbrace')) {
        i += 10;
        final m = _brace(expr, i);
        if (m != null) {
          i = m.end;
          final inner = _we(_cvt(m.inner));
          if (i < expr.length && expr[i] == '^') {
            i++;
            final sm = _brace(expr, i);
            if (sm != null) {
              i = sm.end;
              buf.write('<m:limUpp>$inner${_we(_cvt(sm.inner))}</m:limUpp>');
              continue;
            }
          }
          buf.write(inner); continue;
        }
      }

      // ── accent commands ───────────────────────────────────────────────
      final acc = _tryAccent(expr, i);
      if (acc != null) { buf.write(acc.xml); i = acc.end; continue; }

      // ── nary (\int \sum \prod …) ──────────────────────────────────────
      final nary = _tryNary(expr, i);
      if (nary != null) {
        // اقرأ الـ integrand بعد الـ nary
        final ig = _readIntegrand(expr, nary.end);
        final xml = nary.xml.replaceFirst('<m:e/>', '<m:e>${ig.xml}</m:e>');
        buf.write(xml);
        i = ig.end;
        continue;
      }

      // ── \lim ─────────────────────────────────────────────────────────
      if (_sw(expr, i, r'\lim')) {
        i += 4;
        // اقرأ _ إن وجدت
        if (i < expr.length && expr[i] == '_') {
          i++;
          final sm = _brace(expr, i) ?? _singleToken(expr, i);
          if (sm != null) {
            i = sm.end;
            buf.write('<m:limLow>${_we(_mr('lim'))}${_we(_cvt(sm.inner))}</m:limLow>');
            continue;
          }
        }
        buf.write(_mr('lim')); continue;
      }

      // ── ^ و _ — الحالتان: واحدة أو sub+sup مع بعض ───────────────────
      if (expr[i] == '^' || expr[i] == '_') {
        final firstIsSup = expr[i] == '^';
        i++;
        // اقرأ القيمة الأولى
        final t1 = _brace(expr, i) ?? _singleToken(expr, i);
        if (t1 == null) { buf.write(_mr(firstIsSup ? '^' : '_')); continue; }
        i = t1.end;
        final v1 = _cvt(t1.inner);

        // نتطلع للأمام — في ^ أو _ تانية مختلفة؟
        int k = i;
        while (k < expr.length && expr[k] == ' ') k++;
        final secondChar = k < expr.length ? expr[k] : '';
        final hasSecond  = (firstIsSup && secondChar == '_') ||
            (!firstIsSup && secondChar == '^');

        final base = buf.toString();
        buf.clear();

        if (hasSecond) {
          i = k + 1; // تخطي الـ ^ أو _
          final t2 = _brace(expr, i) ?? _singleToken(expr, i);
          if (t2 != null) {
            i = t2.end;
            final v2  = _cvt(t2.inner);
            final sup = firstIsSup ? v1 : v2;
            final sub = firstIsSup ? v2 : v1;
            // لو الـ base فاضي، نحط placeholder
            final baseXml = base.isEmpty ? _mr(' ') : base;
            buf.write('<m:sSubSup><m:e>$baseXml</m:e>'
                '${_we(sub, tag: 'm:sub')}${_we(sup, tag: 'm:sup')}'
                '</m:sSubSup>');
            continue;
          }
        }

        // واحدة بس
        final baseXml = base.isEmpty ? _mr(' ') : base;
        if (firstIsSup) {
          buf.write('<m:sSup><m:e>$baseXml</m:e>${_we(v1, tag: 'm:sup')}</m:sSup>');
        } else {
          buf.write('<m:sSub><m:e>$baseXml</m:e>${_we(v1, tag: 'm:sub')}</m:sSub>');
        }
        continue;
      }

      // ── {group} ───────────────────────────────────────────────────────
      if (expr[i] == '{') {
        final m = _brace(expr, i);
        if (m != null) { buf.write(_cvt(m.inner)); i = m.end; continue; }
      }

      // ── symbols / Greek ───────────────────────────────────────────────
      final sym = _matchSym(expr, i);
      if (sym != null) {
        if (sym.char.isNotEmpty) buf.write(_mr(sym.char));
        i = sym.end;
        continue;
      }

      // ── plain char ────────────────────────────────────────────────────
      buf.write(_mr(expr[i]));
      i++;
    }

    return buf.toString();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Math helpers
  // ══════════════════════════════════════════════════════════════════════════

  /// \frac body parser — يرجع xml + end
  static ({String xml, int end})? _fracBody(String expr, int i) {
    final num = _brace(expr, i); if (num == null) return null;
    final den = _brace(expr, num.end); if (den == null) return null;
    final xml = '<m:f>'
        '<m:num>${_we(_cvt(num.inner))}</m:num>'
        '<m:den>${_we(_cvt(den.inner))}</m:den>'
        '</m:f>';
    return (xml: xml, end: den.end);
  }

  /// يقرأ الـ integrand بعد nary حد delimiter أو nhary تاني
  static ({String xml, int end}) _readIntegrand(String expr, int start) {
    int i = start;
    // تخطي spaces
    while (i < expr.length && expr[i] == ' ') i++;

    final buf = StringBuffer();

    while (i < expr.length) {
      // وقفنا لو لقينا nary تاني
      if (_isNaryStart(expr, i)) break;
      // أقواس {} — نعالجهم كـ group
      if (expr[i] == '{') {
        final m = _brace(expr, i);
        if (m != null) { buf.write(_cvt(m.inner)); i = m.end; continue; }
      }
      // backslash command — نعالجه عادي
      if (expr[i] == '\\') {
        // لو command معروف نعالجه، غير كده نوقف
        final sym = _matchSym(expr, i);
        if (sym != null) {
          if (sym.char.isNotEmpty) buf.write(_mr(sym.char));
          i = sym.end; continue;
        }
        // accent أو frac أو sqrt — نعالجهم عن طريق _cvt لحرف واحد
        break;
      }
      // أي حرف عادي
      if (expr[i] != ' ') buf.write(_mr(expr[i]));
      i++;
    }

    return (xml: buf.toString(), end: i);
  }

  static bool _isNaryStart(String expr, int i) {
    const keys = [r'\int', r'\iint', r'\iiint', r'\oint', r'\sum', r'\prod'];
    return keys.any((k) => _sw(expr, i, k));
  }

  // ── matrix ────────────────────────────────────────────────────────────────
  static ({String xml, int end})? _tryMatrix(String expr, int start) {
    if (!expr.startsWith(r'\begin', start)) return null;
    int i = start + 6;
    final env = _brace(expr, i);
    if (env == null) return null;
    i = env.end;

    const envs = {
      'matrix', 'pmatrix', 'bmatrix', 'vmatrix',
      'Vmatrix', 'Bmatrix', 'smallmatrix', 'array',
    };
    if (!envs.contains(env.inner.trim())) return null;

    final envName = env.inner.trim();
    final delimiters = const {
      'pmatrix': ('(', ')'),
      'bmatrix': ('[', ']'),
      'vmatrix': ('|', '|'),
      'Vmatrix': ('‖', '‖'),
      'Bmatrix': ('{', '}'),
    };

    final endTag = '\\end{$envName}';
    final endIdx = expr.indexOf(endTag, i);
    if (endIdx == -1) return null;

    final content = expr.substring(i, endIdx).trim();
    final endPos  = endIdx + endTag.length;

    // نقسّم الـ rows
    final rows = content.split(RegExp(r'\\\\'));

    // نحسب عدد الـ columns من أول row غير فارغة
    int colCount = 1;
    for (final row in rows) {
      final cells = row.split('&');
      if (cells.length > colCount) colCount = cells.length;
    }

    // نبني الـ OOXML matrix
    final mat = StringBuffer('<m:m>');
    mat.write('<m:mPr><m:mcs><m:mc><m:mcPr>'
        '<m:count m:val="$colCount"/>'
        '<m:mcJc m:val="center"/>'
        '</m:mcPr></m:mc></m:mcs></m:mPr>');

    for (final row in rows) {
      final cells = row.split('&');
      mat.write('<m:mr>');
      for (final cell in cells) {
        mat.write('<m:e>${_cvt(cell.trim())}</m:e>');
      }
      // لو في cells ناقصة، نضيف فراغ
      for (int c = cells.length; c < colCount; c++) {
        mat.write('<m:e>${_mr(' ')}</m:e>');
      }
      mat.write('</m:mr>');
    }
    mat.write('</m:m>');

    String xml = mat.toString();
    final dl = delimiters[envName];
    if (dl != null) {
      xml = '<m:d><m:dPr>'
          '<m:begChr m:val="${_xe(dl.$1)}"/>'
          '<m:endChr m:val="${_xe(dl.$2)}"/>'
          '</m:dPr><m:e>$xml</m:e></m:d>';
    }

    return (xml: xml, end: endPos);
  }

  // ── accent ────────────────────────────────────────────────────────────────
  static ({String xml, int end})? _tryAccent(String expr, int i) {
    const accents = <String, String>{
      r'\overline':  '¯', r'\bar':       '¯',
      r'\hat':       'ˆ', r'\widehat':   'ˆ',
      r'\vec':       '→',
      r'\tilde':     '˜', r'\widetilde': '˜',
      r'\dot':       '˙', r'\ddot':      '¨',
      r'\acute':     '´', r'\grave':     '`',
      r'\check':     'ˇ', r'\breve':     '˘',
    };
    for (final e in accents.entries) {
      if (!_sw(expr, i, e.key)) continue;
      final m = _brace(expr, i + e.key.length);
      if (m == null) continue;
      final xml = '<m:acc><m:accPr>'
          '<m:chr m:val="${_xe(e.value)}"/>'
          '</m:accPr>${_we(_cvt(m.inner))}</m:acc>';
      return (xml: xml, end: m.end);
    }
    // \underline → <m:bar pos=bot>
    if (_sw(expr, i, r'\underline')) {
      final m = _brace(expr, i + 10);
      if (m != null) {
        return (
        xml: '<m:bar><m:barPr><m:pos m:val="bot"/></m:barPr>'
            '${_we(_cvt(m.inner))}</m:bar>',
        end: m.end,
        );
      }
    }
    return null;
  }

  // ── nary ─────────────────────────────────────────────────────────────────
  static ({String xml, int end})? _tryNary(String expr, int i) {
    const ops = <String, String>{
      r'\iiint': '∭', r'\iint': '∬', r'\int': '∫',
      r'\oint': '∮',  r'\sum': '∑',  r'\prod': '∏',
    };
    // الترتيب مهم: الأطول أولاً (iiint قبل iint قبل int)
    for (final e in ops.entries) {
      if (!_sw(expr, i, e.key)) continue;
      int j = i + e.key.length;
      // تأكد مش partial match
      if (j < expr.length && RegExp(r'[a-zA-Z]').hasMatch(expr[j])) continue;

      String? sub, sup;
      // اقرأ sub و sup بأي ترتيب (حد 2 مرات)
      for (int pass = 0; pass < 2 && j < expr.length; pass++) {
        // تخطي spaces
        while (j < expr.length && expr[j] == ' ') j++;
        if (j >= expr.length) break;
        if (expr[j] == '_' || expr[j] == '^') {
          final isSup = expr[j] == '^';
          j++;
          final t = _brace(expr, j) ?? _singleToken(expr, j);
          if (t != null) {
            final val = _cvt(t.inner);
            if (isSup) sup = val; else sub = val;
            j = t.end;
          }
        } else { break; }
      }

      final chr = _xe(e.value);
      // <m:e/> placeholder — بيتملى بعدين
      final xml = '<m:nary><m:naryPr>'
          '<m:chr m:val="$chr"/>'
          '<m:limLoc m:val="undOvr"/>'
          '<m:subHide m:val="${sub == null ? '1' : '0'}"/>'
          '<m:supHide m:val="${sup == null ? '1' : '0'}"/>'
          '</m:naryPr>'
          '<m:sub>${sub != null ? _we(sub) : ''}</m:sub>'
          '<m:sup>${sup != null ? _we(sup) : ''}</m:sup>'
          '<m:e/>'
          '</m:nary>';
      return (xml: xml, end: j);
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Low-level helpers
  // ══════════════════════════════════════════════════════════════════════════

  /// XML math run
  static String _mr(String t) =>
      t.isEmpty ? '' : '<m:r><m:t xml:space="preserve">${_xe(t)}</m:t></m:r>';

  /// wrap in <m:e> أو tag آخر
  static String _we(String content, {String tag = 'm:e'}) =>
      '<$tag>$content</$tag>';

  /// brace-matching {content} — يرجع (inner, endIndex)
  static ({String inner, int end})? _brace(String s, int start) {
    // تخطي spaces
    int i = start;
    while (i < s.length && s[i] == ' ') i++;
    if (i >= s.length || s[i] != '{') return null;
    int depth = 0;
    final buf = StringBuffer();
    i++;
    while (i < s.length) {
      final c = s[i];
      if (c == '{') { depth++; buf.write(c); }
      else if (c == '}') {
        if (depth == 0) return (inner: buf.toString(), end: i + 1);
        depth--;
        buf.write(c);
      } else { buf.write(c); }
      i++;
    }
    return null;
  }

  /// يقرأ token واحد (حرف أو command) بدون أقواس
  static ({String inner, int end})? _singleToken(String s, int start) {
    int i = start;
    while (i < s.length && s[i] == ' ') i++;
    if (i >= s.length) return null;
    if (s[i] == '\\') {
      int j = i + 1;
      while (j < s.length && RegExp(r'[a-zA-Z]').hasMatch(s[j])) j++;
      return (inner: s.substring(i, j), end: j);
    }
    return (inner: s[i], end: i + 1);
  }

  /// starts-with مع word-boundary check للـ letter commands
  static bool _sw(String s, int i, String prefix) {
    if (i + prefix.length > s.length) return false;
    if (!s.startsWith(prefix, i)) return false;
    final last = prefix[prefix.length - 1];
    if (RegExp(r'[a-zA-Z]').hasMatch(last)) {
      final next = i + prefix.length;
      if (next < s.length && RegExp(r'[a-zA-Z]').hasMatch(s[next])) return false;
    }
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Symbol table
  // ══════════════════════════════════════════════════════════════════════════

  static ({String char, int end})? _matchSym(String s, int i) {
    if (i >= s.length || s[i] != '\\') return null;

    // مرتّبة من الأطول للأقصر لمنع partial match
    const tbl = [
      (r'\varepsilon','ε'),(r'\varphi','φ'),(r'\vartheta','θ'),
      (r'\varrho','ρ'),(r'\varpi','ϖ'),(r'\varsigma','ς'),
      (r'\varnothing','∅'),

      (r'\Leftrightarrow','⟺'),(r'\longrightarrow','⟶'),(r'\longleftarrow','⟵'),
      (r'\hookrightarrow','↪'),(r'\Rightarrow','⇒'),(r'\Leftarrow','⇐'),
      (r'\rightarrow','→'),(r'\leftarrow','←'),(r'\leftrightarrow','↔'),
      (r'\mapsto','↦'),(r'\nearrow','↗'),(r'\searrow','↘'),
      (r'\uparrow','↑'),(r'\downarrow','↓'),
      (r'\to','→'),(r'\gets','←'),

      (r'\partial','∂'),(r'\nabla','∇'),(r'\infty','∞'),
      (r'\forall','∀'),(r'\exists','∃'),(r'\nexists','∄'),
      (r'\neg','¬'),(r'\land','∧'),(r'\lor','∨'),
      (r'\bigoplus','⊕'),(r'\bigotimes','⊗'),
      (r'\oplus','⊕'),(r'\otimes','⊗'),(r'\ominus','⊖'),

      (r'\leq','≤'),(r'\geq','≥'),(r'\neq','≠'),(r'\approx','≈'),
      (r'\le','≤'),(r'\ge','≥'),(r'\ne','≠'),
      (r'\simeq','≃'),(r'\equiv','≡'),(r'\propto','∝'),
      (r'\cong','≅'),(r'\sim','∼'),(r'\ll','≪'),(r'\gg','≫'),
      (r'\perp','⊥'),(r'\parallel','∥'),

      (r'\subseteq','⊆'),(r'\supseteq','⊇'),
      (r'\subset','⊂'),(r'\supset','⊃'),
      (r'\setminus','∖'),(r'\emptyset','∅'),
      (r'\notin','∉'),(r'\in','∈'),(r'\ni','∋'),
      (r'\cup','∪'),(r'\cap','∩'),

      (r'\cdots','⋯'),(r'\ldots','…'),(r'\ddots','⋱'),(r'\vdots','⋮'),
      (r'\cdot','·'),(r'\times','×'),(r'\div','÷'),(r'\pm','±'),(r'\mp','∓'),
      (r'\circ','∘'),(r'\bullet','•'),(r'\star','⋆'),
      (r'\prime','′'),(r'\dagger','†'),(r'\ddagger','‡'),
      (r'\hbar','ℏ'),(r'\ell','ℓ'),(r'\wp','℘'),(r'\aleph','ℵ'),
      (r'\Re','ℜ'),(r'\Im','ℑ'),

      (r'\alpha','α'),(r'\beta','β'),(r'\gamma','γ'),(r'\delta','δ'),
      (r'\epsilon','ε'),(r'\zeta','ζ'),(r'\eta','η'),(r'\theta','θ'),
      (r'\iota','ι'),(r'\kappa','κ'),(r'\lambda','λ'),(r'\mu','μ'),
      (r'\nu','ν'),(r'\xi','ξ'),(r'\pi','π'),(r'\rho','ρ'),
      (r'\sigma','σ'),(r'\tau','τ'),(r'\upsilon','υ'),(r'\phi','φ'),
      (r'\chi','χ'),(r'\psi','ψ'),(r'\omega','ω'),
      (r'\Gamma','Γ'),(r'\Delta','Δ'),(r'\Theta','Θ'),(r'\Lambda','Λ'),
      (r'\Xi','Ξ'),(r'\Pi','Π'),(r'\Sigma','Σ'),(r'\Upsilon','Υ'),
      (r'\Phi','Φ'),(r'\Psi','Ψ'),(r'\Omega','Ω'),

      (r'\arcsin','arcsin'),(r'\arccos','arccos'),(r'\arctan','arctan'),
      (r'\sinh','sinh'),(r'\cosh','cosh'),(r'\tanh','tanh'),
      (r'\sin','sin'),(r'\cos','cos'),(r'\tan','tan'),
      (r'\cot','cot'),(r'\sec','sec'),(r'\csc','csc'),
      (r'\ln','ln'),(r'\log','log'),(r'\exp','exp'),
      (r'\max','max'),(r'\min','min'),(r'\sup','sup'),(r'\inf','inf'),
      (r'\det','det'),(r'\dim','dim'),(r'\ker','ker'),
      (r'\deg','deg'),(r'\gcd','gcd'),

      (r'\Biggl','') ,(r'\Biggr','') ,(r'\bigg','') ,(r'\Bigg',''),
      (r'\Bigl','')  ,(r'\Bigr','')  ,(r'\bigl','')  ,(r'\bigr',''),
      (r'\Big','')   ,(r'\big','')   ,
      (r'\left','')  ,(r'\right','') ,
      (r'\qquad','  '),(r'\quad',' '),
      (r'\,','') ,(r'\;',' ') ,(r'\:','') ,(r'\!',''),
      (r'\text',''),  // handled specially below
    ];

    for (final (cmd, char) in tbl) {
      if (!s.startsWith(cmd, i)) continue;
      final end = i + cmd.length;
      // word boundary للـ letter commands
      final lastCh = cmd[cmd.length - 1];
      if (RegExp(r'[a-zA-Z]').hasMatch(lastCh)) {
        if (end < s.length && RegExp(r'[a-zA-Z]').hasMatch(s[end])) continue;
      }
      // \text{content} → نرجع المحتوى كنص عادي
      if (cmd == r'\text') {
        final m = _brace(s, end);
        if (m != null) return (char: m.inner, end: m.end);
        return (char: '', end: end);
      }
      return (char: char, end: end);
    }

    // backslash + non-letter → الحرف نفسه
    if (i + 1 < s.length && !RegExp(r'[a-zA-Z]').hasMatch(s[i + 1])) {
      return (char: s[i + 1], end: i + 2);
    }
    // backslash + unknown command → نتخطاه
    int j = i + 1;
    while (j < s.length && RegExp(r'[a-zA-Z]').hasMatch(s[j])) j++;
    return (char: '', end: j);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Inline text formatting
  // ══════════════════════════════════════════════════════════════════════════

  static List<String> _fmtRuns(String text, int fontSize, String color) {
    // Convert markdown links [label](url) → label (url)
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (m) => '\${m[1]} (\${m[2]})',
    );
    final runs = <String>[];
    final re   = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`([^`]+)`');
    int last   = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        runs.add(_run(text.substring(last, m.start), size: fontSize, color: color));
      }
      if (m.group(1) != null) {
        runs.add(_run(m.group(1)!, bold: true, size: fontSize, color: color));
      } else if (m.group(2) != null) {
        runs.add(_run(m.group(2)!, italic: true, size: fontSize, color: color));
      } else {
        runs.add(_run(m.group(3)!, mono: true, size: fontSize - 2, color: '2E74B5'));
      }
      last = m.end;
    }
    if (last < text.length) {
      runs.add(_run(text.substring(last), size: fontSize, color: color));
    }
    return runs;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Block parser
  // ══════════════════════════════════════════════════════════════════════════

  static List<_Block> _parseBlocks(String raw) {
    raw = raw
        .replaceAll(RegExp(r'#{0,2}QSEP##', caseSensitive: false), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    final blocks = <_Block>[];
    final lines  = raw.split('\n');
    int li       = 0;

    while (li < lines.length) {
      final trimmed = lines[li].trim();

      // ── code fence ───────────────────────────────────────────────────
      if (trimmed.startsWith('```')) {
        li++;
        final code = <String>[];
        while (li < lines.length && !lines[li].trim().startsWith('```')) {
          code.add(lines[li]); li++;
        }
        li++;
        blocks.add(_Block(_BType.code, code.join('\n')));
        continue;
      }

      // ── block math $$ ... $$ ─────────────────────────────────────────
      if (trimmed.startsWith(r'$$')) {
        final rest = trimmed.substring(2).trim();
        if (rest.endsWith(r'$$') && rest.length > 2) {
          blocks.add(_Block(_BType.blockMath, rest.substring(0, rest.length - 2).trim()));
          li++; continue;
        }
        li++;
        final ml = <String>[if (rest.isNotEmpty) rest];
        while (li < lines.length && !lines[li].trim().contains(r'$$')) {
          ml.add(lines[li]); li++;
        }
        if (li < lines.length) {
          final c = lines[li].trim().replaceAll(r'$$', '').trim();
          if (c.isNotEmpty) ml.add(c);
          li++;
        }
        blocks.add(_Block(_BType.blockMath, ml.join('\n').trim()));
        continue;
      }

      // ── block math \[ ... \] ─────────────────────────────────────────
      if (trimmed.startsWith(r'\[')) {
        li++;
        final ml = <String>[trimmed.substring(2).trim()];
        while (li < lines.length && !lines[li].trim().contains(r'\]')) {
          ml.add(lines[li]); li++;
        }
        if (li < lines.length) {
          ml.add(lines[li].trim().replaceAll(r'\]', '').trim());
          li++;
        }
        blocks.add(_Block(_BType.blockMath, ml.join('\n').trim()));
        continue;
      }

      // ── heading **...** ──────────────────────────────────────────────
      if (RegExp(r'^\*\*[^*]+\*\*$').hasMatch(trimmed)) {
        blocks.add(_Block(_BType.heading,
            trimmed.replaceAll('**', '').trim()));
        li++; continue;
      }

      // ── heading # ────────────────────────────────────────────────────
      final hm = RegExp(r'^#{1,6}\s+(.+)$').firstMatch(trimmed);
      if (hm != null) {
        blocks.add(_Block(_BType.heading, hm.group(1)!.trim()));
        li++; continue;
      }

      // ── text block ───────────────────────────────────────────────────
      final tl = <String>[];
      while (li < lines.length) {
        final t = lines[li].trim();
        if (t.startsWith('```')  || t.startsWith(r'$$') ||
            t.startsWith(r'\[') || RegExp(r'^#{1,6}\s').hasMatch(t) ||
            RegExp(r'^\*\*[^*]+\*\*$').hasMatch(t)) break;
        tl.add(lines[li]); li++;
      }
      if (tl.isNotEmpty) blocks.add(_Block(_BType.text, tl.join('\n')));
    }
    return blocks;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Inline math parser
  // ══════════════════════════════════════════════════════════════════════════

  static List<_InlineSeg> _parseInline(String text) {
    final segs = <_InlineSeg>[];
    final re   = RegExp(
      r'\$\$([\s\S]+?)\$\$'
      r'|\\\[([\s\S]+?)\\\]'
      r'|\\\((.+?)\\\)'
      r'|(?<!\$)\$(?!\$)([^\$\n]+?)\$(?!\$)',
    );
    int last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) segs.add(_InlineSeg(text.substring(last, m.start), false));
      final latex = (m.group(1) ?? m.group(2) ?? m.group(3) ?? m.group(4) ?? '').trim();
      if (latex.isNotEmpty) segs.add(_InlineSeg(latex, true));
      last = m.end;
    }
    if (last < text.length) segs.add(_InlineSeg(text.substring(last), false));
    return segs;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  XML escape
  // ══════════════════════════════════════════════════════════════════════════

  static String _xe(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  // ══════════════════════════════════════════════════════════════════════════
  //  DOCX / ZIP builder
  // ══════════════════════════════════════════════════════════════════════════

  static List<int> _buildDocxBytes(String documentXml) {
    const ct =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml"'
        ' ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/settings.xml"'
        ' ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>'
        '</Types>';
    const rm =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1"'
        ' Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"'
        ' Target="word/document.xml"/>'
        '</Relationships>';
    const rd =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1"'
        ' Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings"'
        ' Target="settings.xml"/>'
        '</Relationships>';
    const st =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:defaultTabStop w:val="708"/>'
        '</w:settings>';

    return (_ZipBuilder()
      ..addFile('[Content_Types].xml',          ct)
      ..addFile('_rels/.rels',                  rm)
      ..addFile('word/document.xml',            documentXml)
      ..addFile('word/_rels/document.xml.rels', rd)
      ..addFile('word/settings.xml',            st))
        .build();
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Data classes
// ════════════════════════════════════════════════════════════════════════════

enum _BType { heading, code, blockMath, bullet, text }

class _Block {
  final _BType type;
  final String content;
  const _Block(this.type, this.content);
}

class _InlineSeg {
  final String content;
  final bool   isMath;
  const _InlineSeg(this.content, this.isMath);
}

// ════════════════════════════════════════════════════════════════════════════
//  ZIP builder — pure Dart, no dependencies
// ════════════════════════════════════════════════════════════════════════════

class _ZipBuilder {
  final _entries = <_ZipEntry>[];

  _ZipBuilder addFile(String name, String content) {
    _entries.add(_ZipEntry(name, content));
    return this;
  }

  List<int> build() {
    final local = <int>[];
    final cdir  = <int>[];
    final offs  = <int>[];

    for (final e in _entries) {
      final nb  = _utf8(e.name);
      final db  = _utf8(e.content);
      final crc = _crc32(db);
      offs.add(local.length);
      local
        ..addAll([0x50,0x4B,0x03,0x04, 0x14,0x00, 0x00,0x00,
          0x00,0x00, 0x00,0x00,0x00,0x00])
        ..addAll(_i32(crc))
        ..addAll(_i32(db.length))
        ..addAll(_i32(db.length))
        ..addAll(_i16(nb.length))
        ..addAll([0x00,0x00])
        ..addAll(nb)
        ..addAll(db);
    }

    for (int i = 0; i < _entries.length; i++) {
      final nb  = _utf8(_entries[i].name);
      final db  = _utf8(_entries[i].content);
      final crc = _crc32(db);
      cdir
        ..addAll([0x50,0x4B,0x01,0x02, 0x14,0x00,0x14,0x00,
          0x00,0x00, 0x00,0x00,0x00,0x00,0x00,0x00])
        ..addAll(_i32(crc))
        ..addAll(_i32(db.length))
        ..addAll(_i32(db.length))
        ..addAll(_i16(nb.length))
        ..addAll([0x00,0x00, 0x00,0x00, 0x00,0x00,
          0x00,0x00,0x00,0x00])
        ..addAll(_i32(offs[i]))
        ..addAll(nb);
    }

    return [
      ...local, ...cdir,
      0x50,0x4B,0x05,0x06, 0x00,0x00,0x00,0x00,
      ..._i16(_entries.length), ..._i16(_entries.length),
      ..._i32(cdir.length), ..._i32(local.length),
      0x00,0x00,
    ];
  }

  List<int> _utf8(String s) {
    final b = <int>[];
    for (final r in s.runes) {
      if      (r < 0x80)    { b.add(r); }
      else if (r < 0x800)   { b.add(0xC0|(r>>6)); b.add(0x80|(r&0x3F)); }
      else if (r < 0x10000) { b.add(0xE0|(r>>12)); b.add(0x80|((r>>6)&0x3F));
      b.add(0x80|(r&0x3F)); }
      else                  { b.add(0xF0|(r>>18)); b.add(0x80|((r>>12)&0x3F));
      b.add(0x80|((r>>6)&0x3F)); b.add(0x80|(r&0x3F)); }
    }
    return b;
  }

  int _crc32(List<int> data) {
    const p = 0xEDB88320;
    var c = 0xFFFFFFFF;
    for (final b in data) {
      c ^= b;
      for (var j = 0; j < 8; j++) c = (c & 1) != 0 ? ((c >> 1) ^ p) : (c >> 1);
    }
    return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  List<int> _i32(int v) =>
      [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
  List<int> _i16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
}

class _ZipEntry {
  final String name, content;
  const _ZipEntry(this.name, this.content);
}