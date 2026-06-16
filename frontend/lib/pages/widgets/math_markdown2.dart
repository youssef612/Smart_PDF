// lib/widgets/math_markdown2.dart
// v19 — fixed: raw LaTeX in matching/listing, inline overflow, orphan sentence fragments

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────
//  FIX 1: Raw LaTeX detector & converter
//  بيحول الـ raw LaTeX زي \phi(x) = ... اللي مش متلفوف في $
//  لـ $...$  عشان يتعرض كـ math مش كنص أحمر
// ─────────────────────────────────────────────────────────────

String _convertRawLatexLines(String text) {
  final lines = text.split('\n');
  final result = <String>[];
  bool inFence = false;

  for (final line in lines) {
    final trimmed = line.trim();

    if (trimmed.startsWith('```')) {
      inFence = !inFence;
      result.add(line);
      continue;
    }
    if (inFence) {
      result.add(line);
      continue;
    }

    // بيشوف لو السطر بيبدأ بـ B1. أو B2. أو رقم. أو حرف. ويحتوي على \command
    // ده بيكون raw LaTeX في listing زي الـ matching questions
    final listingMatch = RegExp(
      r'^([A-Z]\d+\.\s+|[Bb]\d+\.\s+|\d+\.\s+)(.+)$',
    ).firstMatch(trimmed);

    if (listingMatch != null) {
      final prefix = listingMatch.group(1)!;
      final content = listingMatch.group(2)!;
      final hasRawLatex = RegExp(
        r'\\(?:phi|psi|lambda|mu|sigma|theta|alpha|beta|gamma|delta|'
        r'omega|pi|int|frac|sqrt|sum|prod|partial|nabla|cdot|times|'
        r'mathbf|text|left|right|leq|geq|neq|in|infty)\b',
      ).hasMatch(content);
      final alreadyWrapped = content.contains(r'$');

      if (hasRawLatex && !alreadyWrapped) {
        result.add('$prefix\$$content\$');
        continue;
      }
    }

    // سطور زي "B1. \phi(x) = ..." بدون prefix
    final rawLatexLine = RegExp(
      r'^([A-Z]\d+\.?|[Bb]\d+\.?)\s+(.+)$',
    ).firstMatch(trimmed);

    if (rawLatexLine != null) {
      final prefix = rawLatexLine.group(1)!;
      final content = rawLatexLine.group(2)!;
      final hasRawLatex = RegExp(
        r'\\(?:phi|psi|lambda|int|frac|sqrt|sum|partial|alpha|beta|'
        r'gamma|delta|omega|pi|cdot|times|leq|geq|neq|infty)\b',
      ).hasMatch(content);
      final alreadyWrapped = content.contains(r'$');

      if (hasRawLatex && !alreadyWrapped) {
        result.add('$prefix \$$content\$');
        continue;
      }
    }

    result.add(line);
  }

  return result.join('\n');
}

// ─────────────────────────────────────────────────────────────
//  Pre-processing
// ─────────────────────────────────────────────────────────────

String _protectBlockMathNewlines(String text) {
  return text.replaceAllMapped(
    RegExp(r'\$\$([\s\S]+?)\$\$', dotAll: true),
    (m) => '\$\$${(m[1] ?? '').replaceAll('\n', ' ').trim()}\$\$',
  );
}

String _normalizeDelimiters(String text) {
  text = text.replaceAllMapped(
    RegExp(r'\\\[([\s\S]+?)\\\]', multiLine: true),
    (m) => '\n\$\$${(m[1] ?? '').trim()}\$\$\n',
  );
  text = text.replaceAllMapped(
    RegExp(
        r'\\begin\{(?:cases|align|aligned|matrix|pmatrix|bmatrix|vmatrix|array|gather|multline)[*]?\}[\s\S]+?\\end\{(?:cases|align|aligned|matrix|pmatrix|bmatrix|vmatrix|array|gather|multline)[*]?\}',
        multiLine: true),
    (m) => '\n\$\$${(m[0] ?? '').trim()}\$\$\n',
  );
  text = text.replaceAllMapped(
    RegExp(r'\\\((.+?)\\\)', dotAll: false),
    (m) => '\$${(m[1] ?? '').trim()}\$',
  );
  return text;
}

String _fixOptionsLineBreaks(String text) {
  return text.replaceAllMapped(
    RegExp(r'(?<!\n)([A-D])\)\s+'),
    (m) => '\n${m[1]}) ',
  );
}

// ─────────────────────────────────────────────────────────────
//  FIX 3: Enhanced orphan line merger
//  بيمسك السطور اللي بتبدأ بـ . أو , أو ; ويضمها للسطر السابق
// ─────────────────────────────────────────────────────────────

String _mergeOrphanLines(String text) {
  final lines = text.split('\n');
  final result = <String>[];
  for (final raw in lines) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      result.add('');
      continue;
    }
    // حماية سطور الجداول من الـ merge
    if (trimmed.startsWith('|')) {
      result.add(raw);
      continue;
    }

    // FIX 3: سطر بيبدأ بـ . أو , أو ; → ضمّه للسطر السابق
    final startsWithPunct = RegExp(r'^[.,;،]\s*').hasMatch(trimmed);
    if (startsWithPunct && result.isNotEmpty) {
      for (int i = result.length - 1; i >= 0; i--) {
        if (result[i].trim().isNotEmpty) {
          result[i] = result[i].trimRight() + ' ' + trimmed;
          break;
        }
      }
      continue;
    }

    final isPunct = RegExp(r'^[.,;:\-]+$').hasMatch(trimmed);
    final isGreekOrMath =
        RegExp(r'^[\u0370-\u03FF\u2200-\u22FF\u03C6\u03BB]+$').hasMatch(trimmed);
    final isShortVar = !isGreekOrMath &&
        ((trimmed.length <= 2 &&
                !trimmed.contains(r'$') &&
                RegExp(r'^[\w\u0600-\u06FF]+$').hasMatch(trimmed)) ||
            (RegExp(r'^[\w\u0600-\u06FF\(\)\,\.]+$').hasMatch(trimmed) &&
                trimmed.length <= 5));
    final isShortMath =
        RegExp(r'^\$[^\$\n]{1,25}\$[.,;:]?\$').hasMatch(trimmed);
    if ((isPunct || isShortVar || isShortMath) && result.isNotEmpty) {
      for (int i = result.length - 1; i >= 0; i--) {
        if (result[i].trim().isNotEmpty) {
          result[i] = '${result[i]} $trimmed';
          break;
        }
      }
    } else {
      result.add(raw);
    }
  }
  return result.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String _convertUnicodeMathInSegment(String text) {
  const map = {
    'φ': r'\phi',
    'λ': r'\lambda',
    'μ': r'\mu',
    'σ': r'\sigma',
    'θ': r'\theta',
    'α': r'\alpha',
    'β': r'\beta',
    'γ': r'\gamma',
    'δ': r'\delta',
    'ω': r'\omega',
    'π': r'\pi',
    '∫': r'\int',
    '∑': r'\sum',
    '√': r'\sqrt',
    '∞': r'\infty',
    '∂': r'\partial',
    '∇': r'\nabla',
    '→': r'\to',
    '≤': r'\leq',
    '≥': r'\geq',
    '≠': r'\neq',
    '≈': r'\approx',
    '±': r'\pm',
    '×': r'\times',
    '·': r'\cdot',
  };
  map.forEach((k, v) => text = text.replaceAll(k, v));
  const subs = {
    '₀': '0', '₁': '1', '₂': '2', '₃': '3', '₄': '4',
    '₅': '5', '₆': '6', '₇': '7', '₈': '8', '₉': '9',
    'ₙ': 'n', 'ₘ': 'm', 'ₓ': 'x',
  };
  const sups = {
    '⁰': '0', '¹': '1', '²': '2', '³': '3', '⁴': '4',
    '⁵': '5', '⁶': '6', '⁷': '7', '⁸': '8', '⁹': '9',
    'ⁿ': 'n', 'ˣ': 'x',
  };
  subs.forEach((k, v) => text = text.replaceAll(k, '_$v'));
  sups.forEach((k, v) => text = text.replaceAll(k, '^$v'));
  return text;
}

String _convertUnicodeMath(String text) {
  final pattern = RegExp(r'\$\$([\s\S]+?)\$\$|\$([^\$\n]+?)\$', dotAll: true);
  final buffer = StringBuffer();
  int cursor = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > cursor) buffer.write(text.substring(cursor, m.start));
    final block = m.group(1);
    final inline = m.group(2);
    if (block != null)
      buffer.write('\$\$${_convertUnicodeMathInSegment(block)}\$\$');
    else if (inline != null)
      buffer.write('\$${_convertUnicodeMathInSegment(inline)}\$');
    else
      buffer.write(m.group(0));
    cursor = m.end;
  }
  if (cursor < text.length) buffer.write(text.substring(cursor));
  return buffer.toString();
}

// ─────────────────────────────────────────────────────────────
//  Table protection
// ─────────────────────────────────────────────────────────────

final _tableBlockPattern = RegExp(
  r'(?:^|\n)((?:[ \t]*\|[^\n]*\n)+[ \t]*\|[ \t]*[-:| \t]+[-| \t]*\|?[^\n]*(?:\n[ \t]*\|[^\n]*)*)',
  multiLine: true,
);

// ─────────────────────────────────────────────────────────────
//  Main preprocess
// ─────────────────────────────────────────────────────────────

String _preprocess(String raw) {
  raw = _convertUnicodeMath(raw);
  raw = _normalizeDelimiters(raw);
  raw = _convertRawLatexLines(raw); // FIX 1: convert raw LaTeX in listings
  raw = _protectBlockMathNewlines(raw);
  raw = _fixOptionsLineBreaks(raw);
  raw = _mergeOrphanLines(raw);     // FIX 3: merge orphan punctuation lines
  raw = raw.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return raw.trim();
}

// ─────────────────────────────────────────────────────────────
//  Code block extractor
// ─────────────────────────────────────────────────────────────

class _Segment {
  final String content;
  final bool isCode;
  final String lang;
  const _Segment(this.content, {this.isCode = false, this.lang = ''});
}

List<_Segment> _splitCodeBlocks(String text) {
  final segments = <_Segment>[];
  final pattern = RegExp(r'```(\w*)\n([\s\S]*?)```', multiLine: true);
  int cursor = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > cursor) {
      final before = text.substring(cursor, m.start).trim();
      if (before.isNotEmpty) segments.add(_Segment(before));
    }
    segments
        .add(_Segment(m.group(2) ?? '', isCode: true, lang: m.group(1) ?? ''));
    cursor = m.end;
  }
  if (cursor < text.length) {
    final rest = text.substring(cursor).trim();
    if (rest.isNotEmpty) segments.add(_Segment(rest));
  }
  return segments.isEmpty ? [_Segment(text)] : segments;
}

// ─────────────────────────────────────────────────────────────
//  Token model
// ─────────────────────────────────────────────────────────────

enum _TokType { text, inlineMath, blockMath }

class _Tok {
  final _TokType type;
  final String content;
  const _Tok(this.type, this.content);
}

List<_Tok> _tokenize(String input) {
  final toks = <_Tok>[];
  final pattern = RegExp(r'\$\$([\s\S]+?)\$\$|\$([^\$\n]+?)\$', dotAll: true);
  int cursor = 0;
  for (final m in pattern.allMatches(input)) {
    if (m.start > cursor) {
      final txt = input.substring(cursor, m.start);
      if (txt.isNotEmpty) toks.add(_Tok(_TokType.text, txt));
    }
    final block = m.group(1);
    final inline = m.group(2);
    if (block != null && block.trim().isNotEmpty)
      toks.add(_Tok(_TokType.blockMath, block.trim()));
    else if (inline != null && inline.trim().isNotEmpty)
      toks.add(_Tok(_TokType.inlineMath, inline.trim()));
    cursor = m.end;
  }
  if (cursor < input.length) {
    final rem = input.substring(cursor);
    if (rem.isNotEmpty) toks.add(_Tok(_TokType.text, rem));
  }
  return toks;
}

typedef _Line = List<_Tok>;

List<_Line> _buildLines(List<_Tok> toks) {
  final lines = <_Line>[];
  var current = <_Tok>[];
  void flush() {
    final m = current
        .where((t) => t.type != _TokType.text || t.content.trim().isNotEmpty)
        .toList();
    if (m.isNotEmpty) lines.add(m);
    current = [];
  }

  for (final tok in toks) {
    if (tok.type == _TokType.blockMath) {
      flush();
      lines.add([tok]);
      continue;
    }
    if (tok.type == _TokType.text) {
      final parts = tok.content.split('\n');
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) current.add(_Tok(_TokType.text, parts[i]));
        if (i < parts.length - 1) flush();
      }
      continue;
    }
    current.add(tok);
  }
  flush();
  return lines;
}

bool _isBlockMathLine(_Line l) =>
    l.length == 1 && l[0].type == _TokType.blockMath;

bool _isOrphanedMath(_Line l) {
  final ne = l
      .where((t) => t.type != _TokType.text || t.content.trim().isNotEmpty)
      .toList();
  return ne.isNotEmpty && ne.every((t) => t.type == _TokType.inlineMath);
}

bool _isPunctuationOnly(_Line l) {
  final txt = l
      .where((t) => t.type == _TokType.text)
      .map((t) => t.content.trim())
      .join('');
  return !l.any((t) => t.type != _TokType.text) &&
      RegExp(r'^[.,;:\s]+$').hasMatch(txt);
}

// FIX 3: بيشوف لو السطر بيبدأ بـ punctuation + نص (orphan sentence fragment)
bool _isOrphanFragment(_Line l) {
  if (l.isEmpty) return false;
  final first = l.first;
  if (first.type != _TokType.text) return false;
  final txt = first.content.trim();
  return RegExp(r'^[.,;،]\s*\S').hasMatch(txt);
}

List<_Line> _mergeOrphanedLines(List<_Line> lines) {
  bool changed = true;
  var result = List<_Line>.from(lines);
  while (changed) {
    changed = false;
    final next = <_Line>[];
    int i = 0;
    while (i < result.length) {
      final line = result[i];
      if (_isBlockMathLine(line)) {
        next.add(line);
        i++;
        continue;
      }
      // FIX: orphan math/punct/fragment → ضمّه للسابق
      if ((_isOrphanedMath(line) || _isPunctuationOnly(line) || _isOrphanFragment(line)) &&
          next.isNotEmpty &&
          !_isBlockMathLine(next.last)) {
        next.last.addAll(line);
        changed = true;
        i++;
        continue;
      }
      // السطر الجاي orphan → ضمّه للحالي
      if (i + 1 < result.length &&
          !_isBlockMathLine(result[i + 1]) &&
          (_isOrphanedMath(result[i + 1]) ||
              _isPunctuationOnly(result[i + 1]) ||
              _isOrphanFragment(result[i + 1]))) {
        next.add(List<_Tok>.from(line)..addAll(result[i + 1]));
        changed = true;
        i += 2;
        continue;
      }
      next.add(line);
      i++;
    }
    result = next;
  }
  return result;
}

// ─────────────────────────────────────────────────────────────
//  RTL detector
// ─────────────────────────────────────────────────────────────

TextDirection _detectDirection(String text) {
  final clean = text
      .replaceAll(RegExp(r'\$\$[\s\S]*?\$\$'), '')
      .replaceAll(RegExp(r'\$[^\$\n]+?\$'), '');
  final ar = RegExp(r'[\u0600-\u06FF]').allMatches(clean).length;
  final en = RegExp(r'[A-Za-z]').allMatches(clean).length;
  if (ar == 0 && en == 0) return TextDirection.ltr;
  return (ar / (ar + en)) >= 0.30 ? TextDirection.rtl : TextDirection.ltr;
}

Widget _directedMarkdown(String data, MarkdownStyleSheet sheet) {
  final hasTable = RegExp(r'^\|', multiLine: true).hasMatch(data);
  final dir = hasTable ? TextDirection.ltr : _detectDirection(data);

  return Directionality(
    textDirection: dir,
    child: MarkdownBody(
      data: data,
      styleSheet: sheet,
      selectable: true,
      softLineBreak: true,
      onTapLink: (text, href, title) async {
        if (href == null) return;
        final uri = Uri.tryParse(href);
        if (uri != null && await canLaunchUrl(uri)) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  MathMarkdown widget
// ─────────────────────────────────────────────────────────────

class MathMarkdown extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final MarkdownStyleSheet? styleSheet;

  const MathMarkdown({
    Key? key,
    required this.data,
    this.style,
    this.styleSheet,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle =
        style ?? theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    final sheet = styleSheet ?? MarkdownStyleSheet.fromTheme(theme);

    final processed = _preprocess(data);

    final tablePlaceholders = <String, String>{};
    int tableIdx = 0;
    final textForSplit = processed.replaceAllMapped(
      _tableBlockPattern,
      (m) {
        final tableText = (m.group(1) ?? m.group(0) ?? '').trim();
        if (tableText.isEmpty) return m.group(0) ?? '';
        final key = '\x00TBL$tableIdx\x00';
        tablePlaceholders[key] = tableText;
        tableIdx++;
        return '\n\n$key\n\n';
      },
    );

    final textDir = _detectDirection(processed);
    final segments = _splitCodeBlocks(textForSplit);

    return Directionality(
      textDirection: textDir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: segments.map((seg) {
          if (seg.isCode) {
            return _CodeBlock(
                code: seg.content, lang: seg.lang, baseStyle: baseStyle);
          }

          final paragraphs = seg.content
              .split(RegExp(r'\n\n+'))
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: paragraphs.map((para) {
              if (tablePlaceholders.containsKey(para)) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _directedMarkdown(tablePlaceholders[para]!, sheet),
                );
              }
              if (para.split('\n').any((l) => l.trim().startsWith('|'))) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _directedMarkdown(para, sheet),
                );
              }
              return _buildParagraph(para, baseStyle, sheet, context);
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildParagraph(String para, TextStyle baseStyle,
      MarkdownStyleSheet sheet, BuildContext context) {
    final paraDir = _detectDirection(para);
    final isRTL = paraDir == TextDirection.rtl;
    final crossAxis =
        isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final toks = _tokenize(para);

    final hasBlock = toks.any((t) => t.type == _TokType.blockMath);
    if (hasBlock) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Directionality(
          textDirection: paraDir,
          child: Column(
            crossAxisAlignment: crossAxis,
            mainAxisSize: MainAxisSize.min,
            children: toks.map((tok) {
              switch (tok.type) {
                case _TokType.blockMath:
                  return _BlockMathWidget(
                      latex: tok.content,
                      baseStyle: baseStyle,
                      context: context);
                case _TokType.inlineMath:
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _mathWidget(tok.content, MathStyle.text, baseStyle),
                  );
                case _TokType.text:
                  final t = tok.content.trim();
                  if (t.isEmpty) return const SizedBox.shrink();
                  return _directedMarkdown(t, sheet);
              }
            }).toList(),
          ),
        ),
      );
    }

    final hasInline = toks.any((t) => t.type == _TokType.inlineMath);
    if (!hasInline) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _directedMarkdown(para, sheet),
      );
    }

    final mergedLines = _mergeOrphanedLines(_buildLines(toks));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Directionality(
        textDirection: paraDir,
        child: Column(
          crossAxisAlignment: crossAxis,
          mainAxisSize: MainAxisSize.min,
          children: mergedLines.map((line) {
            if (_isBlockMathLine(line)) {
              return _BlockMathWidget(
                  latex: line[0].content,
                  baseStyle: baseStyle,
                  context: context);
            }
            final lineText = line
                .where((t) => t.type == _TokType.text)
                .map((t) => t.content)
                .join(' ');
            final lineDir = _detectDirection(lineText);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Directionality(
                textDirection: lineDir,
                // FIX 2: استخدم SingleChildScrollView للـ Wrap عشان نمنع overflow
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    textDirection: lineDir,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 6,
                    spacing: 4,
                    children: line.map((tok) {
                      if (tok.type == _TokType.inlineMath) {
                        return _mathWidget(
                            tok.content, MathStyle.text, baseStyle);
                      }
                      final cleaned =
                          tok.content.replaceAll('\n', ' ').trim();
                      if (cleaned.isEmpty) return const SizedBox.shrink();
                      return Directionality(
                        textDirection: _detectDirection(cleaned),
                        child: MarkdownBody(
                          data: cleaned,
                          styleSheet: sheet,
                          shrinkWrap: true,
                          selectable: true,
                          onTapLink: (text, href, title) async {
                            if (href == null) return;
                            final uri = Uri.tryParse(href);
                            if (uri != null && await canLaunchUrl(uri)) {
                              launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _mathWidget(String latex, MathStyle mathStyle, TextStyle base) {
    try {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Math.tex(
          latex,
          mathStyle: mathStyle,
          textStyle: base,
          onErrorFallback: (e) => SelectableText(
            latex,
            style: base.copyWith(
                fontFamily: 'monospace', color: Colors.red.shade400),
          ),
        ),
      );
    } catch (_) {
      return SelectableText(latex,
          style: base.copyWith(fontFamily: 'monospace'));
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Code block widget
// ─────────────────────────────────────────────────────────────

class _CodeBlock extends StatefulWidget {
  final String code;
  final String lang;
  final TextStyle baseStyle;
  const _CodeBlock(
      {required this.code, required this.lang, required this.baseStyle});

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang.isEmpty ? 'plaintext' : widget.lang;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.15),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text(lang,
                    style: const TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
                const Spacer(),
                GestureDetector(
                  onTap: _copy,
                  child: Icon(
                    _copied ? Icons.check : Icons.copy_rounded,
                    size: 16,
                    color: _copied ? Colors.green : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: HighlightView(
              widget.code,
              language: lang,
              theme: atomOneDarkTheme,
              textStyle: const TextStyle(
                  fontFamily: 'monospace', fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Block math widget with overflow protection
// ─────────────────────────────────────────────────────────────

class _BlockMathWidget extends StatelessWidget {
  final String latex;
  final TextStyle baseStyle;
  final BuildContext context;

  const _BlockMathWidget({
    required this.latex,
    required this.baseStyle,
    required this.context,
  });

  @override
  Widget build(BuildContext buildContext) {
    final screenWidth = MediaQuery.of(buildContext).size.width;
    final maxMathWidth = screenWidth - 80.0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.20)),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxMathWidth),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              latex,
              mathStyle: MathStyle.display,
              textStyle:
                  baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14) + 2),
              onErrorFallback: (e) => SelectableText(
                latex,
                style: baseStyle.copyWith(
                    fontFamily: 'monospace', color: Colors.red.shade400),
              ),
            ),
          ),
        ),
      ),
    );
  }
}