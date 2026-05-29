// lib/widgets/math_markdown.dart
//
// v6 — improved RTL/LTR, better equation layout, Part headers fix
//

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';

// ─────────────────────────────────────────────────────────────
//  Pre-processing
// ─────────────────────────────────────────────────────────────

String _normalizeDelimiters(String text) {
  // \[...\]  →  $$...$$
  text = text.replaceAllMapped(
    RegExp(r'\\\[([\s\S]+?)\\\]', multiLine: true),
        (m) => '\n\$\$${(m[1] ?? '').trim()}\$\$\n',
  );

  // \begin{env}...\end{env}  →  $$...$$
  text = text.replaceAllMapped(
    RegExp(r'\\begin\{(?:cases|align|aligned|matrix|pmatrix|bmatrix|vmatrix|array|gather|multline)[*]?\}[\s\S]+?\\end\{(?:cases|align|aligned|matrix|pmatrix|bmatrix|vmatrix|array|gather|multline)[*]?\}', multiLine: true),
        (m) => '\n\$\$${(m[0] ?? '').trim()}\$\$\n',
  );

  // \(...\)  →  $...$
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

String _mergeOrphanLines(String text) {
  final lines  = text.split('\n');
  final result = <String>[];

  for (final raw in lines) {
    final trimmed = raw.trim();

    if (trimmed.isEmpty) {
      result.add('');
      continue;
    }

    final isPunct    = RegExp(r'^[.,;:\-]+$').hasMatch(trimmed);
    final isShortVar = (trimmed.length <= 3 &&
        !trimmed.contains(r'$') &&
        RegExp(r'^[\w\u0600-\u06FF]+$').hasMatch(trimmed)) ||
        // math expressions like u(x), f(x), K(x,t), λ
        RegExp(r'^[\w\u0600-\u06FF\(\)\,\.]+$').hasMatch(trimmed) && trimmed.length <= 8;

    if ((isPunct || isShortVar) && result.isNotEmpty) {
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

  final joined = result.join('\n');
  return joined.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String _preprocess(String raw) {
  raw = _normalizeDelimiters(raw);
  raw = _fixOptionsLineBreaks(raw);
  raw = _mergeOrphanLines(raw);
  raw = raw.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return raw.trim();
}

// ─────────────────────────────────────────────────────────────
//  Token model
// ─────────────────────────────────────────────────────────────

enum _TokType { text, inlineMath, blockMath }

class _Tok {
  final _TokType type;
  final String   content;
  const _Tok(this.type, this.content);
}

// ─────────────────────────────────────────────────────────────
//  Tokeniser
// ─────────────────────────────────────────────────────────────

List<_Tok> _tokenize(String input) {
  final toks    = <_Tok>[];
  final pattern = RegExp(
    r'\$\$([\s\S]+?)\$\$'
    r'|\$([^\$\n]+?)\$',
    dotAll: true,
  );

  int cursor = 0;
  for (final m in pattern.allMatches(input)) {
    if (m.start > cursor) {
      final txt = input.substring(cursor, m.start);
      if (txt.isNotEmpty) toks.add(_Tok(_TokType.text, txt));
    }
    final block  = m.group(1);
    final inline = m.group(2);
    if (block != null && block.trim().isNotEmpty) {
      toks.add(_Tok(_TokType.blockMath, block.trim()));
    } else if (inline != null && inline.trim().isNotEmpty) {
      toks.add(_Tok(_TokType.inlineMath, inline.trim()));
    }
    cursor = m.end;
  }
  if (cursor < input.length) {
    final rem = input.substring(cursor);
    if (rem.isNotEmpty) toks.add(_Tok(_TokType.text, rem));
  }
  return toks;
}

// ─────────────────────────────────────────────────────────────
//  Line builder
// ─────────────────────────────────────────────────────────────

typedef _Line = List<_Tok>;

List<_Line> _buildLines(List<_Tok> toks) {
  final lines   = <_Line>[];
  var   current = <_Tok>[];

  void flush() {
    final meaningful = current
        .where((t) => t.type != _TokType.text || t.content.trim().isNotEmpty)
        .toList();
    if (meaningful.isNotEmpty) lines.add(meaningful);
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
        final p = parts[i];
        if (p.isNotEmpty) current.add(_Tok(_TokType.text, p));
        if (i < parts.length - 1) flush();
      }
      continue;
    }

    current.add(tok);
  }
  flush();
  return lines;
}

bool _isBlockMathLine(_Line line) =>
    line.length == 1 && line[0].type == _TokType.blockMath;

bool _isOrphanedMath(_Line line) {
  final nonEmpty = line
      .where((t) => t.type != _TokType.text || t.content.trim().isNotEmpty)
      .toList();
  return nonEmpty.isNotEmpty &&
      nonEmpty.every((t) => t.type == _TokType.inlineMath);
}

bool _isPunctuationOnly(_Line line) {
  final text    = line
      .where((t) => t.type == _TokType.text)
      .map((t) => t.content.trim())
      .join('');
  final hasMath = line.any((t) => t.type != _TokType.text);
  return !hasMath && RegExp(r'^[.,;:\s]+$').hasMatch(text);
}

List<_Line> _mergeOrphanedLines(List<_Line> lines) {
  if (lines.isEmpty) return lines;

  bool changed = true;
  var  result  = List<_Line>.from(lines);

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

      if ((_isOrphanedMath(line) || _isPunctuationOnly(line)) &&
          next.isNotEmpty &&
          !_isBlockMathLine(next.last)) {
        next.last.addAll(line);
        changed = true;
        i++;
        continue;
      }

      if (i + 1 < result.length &&
          !_isBlockMathLine(result[i + 1]) &&
          (_isOrphanedMath(result[i + 1]) ||
              _isPunctuationOnly(result[i + 1]))) {
        final merged = List<_Tok>.from(line)..addAll(result[i + 1]);
        next.add(merged);
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
//  RTL/LTR detector — smarter: checks FIRST strong char
// ─────────────────────────────────────────────────────────────

TextDirection _detectDirection(String text) {
  // Strip math before checking
  final clean = text
      .replaceAll(RegExp(r'\$\$[\s\S]*?\$\$'), '')
      .replaceAll(RegExp(r'\$[^\$\n]+?\$'), '');

  final arCount = RegExp(r'[\u0600-\u06FF]').allMatches(clean).length;
  final enCount = RegExp(r'[A-Za-z]').allMatches(clean).length;

  if (arCount == 0 && enCount == 0) return TextDirection.ltr;
  // Use RTL if Arabic chars are >= 30% of total letters
  return (arCount / (arCount + enCount)) >= 0.30
      ? TextDirection.rtl
      : TextDirection.ltr;
}

Widget _directedMarkdown(String data, MarkdownStyleSheet sheet) {
  final dir = _detectDirection(data);
  return Directionality(
    textDirection: dir,
    child: MarkdownBody(
      data: data,
      styleSheet: sheet,
      selectable: true,
      softLineBreak: true,
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  MathMarkdown widget
// ─────────────────────────────────────────────────────────────

class MathMarkdown extends StatelessWidget {
  final String              data;
  final TextStyle?          style;
  final MarkdownStyleSheet? styleSheet;

  const MathMarkdown({
    Key? key,
    required this.data,
    this.style,
    this.styleSheet,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final baseStyle = style ??
        theme.textTheme.bodyMedium ??
        const TextStyle(fontSize: 14);
    final sheet = styleSheet ?? MarkdownStyleSheet.fromTheme(theme);

    final processed = _preprocess(data);

    final paragraphs = processed
        .split(RegExp(r'\n\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final textDir = _detectDirection(processed);

    return Directionality(
      textDirection: textDir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: paragraphs
            .map((para) => _buildParagraph(para, baseStyle, sheet))
            .toList(),
      ),
    );
  }

  Widget _buildParagraph(
      String para,
      TextStyle baseStyle,
      MarkdownStyleSheet sheet,
      ) {
    final paraDir  = _detectDirection(para);
    final isRTL    = paraDir == TextDirection.rtl;
    final crossAxis = isRTL
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    final toks = _tokenize(para);

    // ── Block math present ───────────────────────────────────
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
                  return _BlockMathWidget(latex: tok.content, baseStyle: baseStyle);
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

    // ── Pure text (no math) ──────────────────────────────────
    final hasInline = toks.any((t) => t.type == _TokType.inlineMath);
    if (!hasInline) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _directedMarkdown(para, sheet),
      );
    }

    // ── Mixed text + inline math ─────────────────────────────
    final rawLines    = _buildLines(toks);
    final mergedLines = _mergeOrphanedLines(rawLines);

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
                  latex: line[0].content, baseStyle: baseStyle);
            }

            // Determine wrap direction from text tokens
            final lineText = line
                .where((t) => t.type == _TokType.text)
                .map((t) => t.content)
                .join(' ');
            final lineDir = _detectDirection(lineText);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Directionality(
                textDirection: lineDir,
                child: Wrap(
                  textDirection: lineDir,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 6,
                  spacing: 4,
                  children: line.map((tok) {
                    if (tok.type == _TokType.inlineMath) {
                      return _mathWidget(tok.content, MathStyle.text, baseStyle);
                    }
                    final cleaned = tok.content.replaceAll('\n', ' ').trim();
                    if (cleaned.isEmpty) return const SizedBox.shrink();
                    final tokDir = _detectDirection(cleaned);
                    return Directionality(
                      textDirection: tokDir,
                      child: MarkdownBody(
                        data: cleaned,
                        styleSheet: sheet,
                        shrinkWrap: true,
                        selectable: true,
                      ),
                    );
                  }).toList(),
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
              fontFamily: 'monospace',
              color: Colors.red.shade400,
            ),
          ),
        ),
      );
    } catch (_) {
      return SelectableText(
        latex,
        style: base.copyWith(fontFamily: 'monospace'),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Block math widget — styled card
// ─────────────────────────────────────────────────────────────

class _BlockMathWidget extends StatelessWidget {
  final String    latex;
  final TextStyle baseStyle;

  const _BlockMathWidget({required this.latex, required this.baseStyle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          latex,
          mathStyle: MathStyle.display,
          textStyle: baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14) + 2),
          onErrorFallback: (e) => SelectableText(
            latex,
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              color: Colors.red.shade400,
            ),
          ),
        ),
      ),
      ),
    );
  }
}