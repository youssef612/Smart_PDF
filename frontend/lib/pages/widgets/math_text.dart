// lib/widgets/math_markdown.dart
//
// FIXED VERSION — handles:
//   • Inline LaTeX surrounded by punctuation (no orphaned commas/colons)
//   • Multiple-choice options A) B) C) D) each on its own line
//   • Plain text / Markdown paragraphs rendered correctly
//   • Block LaTeX ($$...$$) centered with horizontal scroll
//
// Drop-in replacement for the MathMarkdown widget in questions_page.dart
// and exam_page.dart. Just update the import path.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

// ─────────────────────────────────────────────────────────────
//  Pre-processing helpers
// ─────────────────────────────────────────────────────────────

/// Normalise all LaTeX delimiters to $...$ / $$...$$
String _normalizeDelimiters(String text) {
  // \[...\] → $$...$$
  text = text.replaceAllMapped(
    RegExp(r'\\\[([\s\S]+?)\\\]', multiLine: true),
        (m) => '\n\$\$${(m[1] ?? '').trim()}\$\$\n',
  );
  // \(...\) → $...$
  text = text.replaceAllMapped(
    RegExp(r'\\\((.+?)\\\)'),
        (m) => '\$${(m[1] ?? '').trim()}\$',
  );
  return text;
}

/// Fix multiple-choice options so each appears on its own line.
/// e.g.  "A) foo B) bar" → "A) foo\nB) bar"
String _fixOptionsLineBreaks(String text) {
  // Insert a newline before A) / B) / C) / D) that aren't already at line start
  return text.replaceAllMapped(
    RegExp(r'(?<!\n)([A-D])\)\s+'),
        (m) => '\n${m[1]}) ',
  );
}

/// Remove stray lone punctuation lines (just a comma, period, semicolon etc.)
String _removeOrphanedPunctuation(String text) {
  return text
      .replaceAll(RegExp(r'^\s*[.,;:]\s*$', multiLine: true), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String _preprocess(String raw) {
  raw = _normalizeDelimiters(raw);
  raw = _fixOptionsLineBreaks(raw);
  raw = _removeOrphanedPunctuation(raw);
  return raw;
}

// ─────────────────────────────────────────────────────────────
//  Segment model
// ─────────────────────────────────────────────────────────────

enum _SegType { text, inlineMath, blockMath }

class _Seg {
  final _SegType type;
  final String content;
  const _Seg(this.type, this.content);
}

/// Parse a (already-normalised) string into alternating text / math segments.
List<_Seg> _parseSegments(String input) {
  final segs = <_Seg>[];
  final pattern = RegExp(
    r'\$\$([\s\S]+?)\$\$'   // block  $$...$$
    r'|\$([^\$\n]+?)\$',    // inline $...$
    dotAll: true,
  );

  int cursor = 0;
  for (final m in pattern.allMatches(input)) {
    if (m.start > cursor) {
      segs.add(_Seg(_SegType.text, input.substring(cursor, m.start)));
    }
    final block  = m.group(1);
    final inline = m.group(2);
    if (block != null && block.trim().isNotEmpty) {
      segs.add(_Seg(_SegType.blockMath, block.trim()));
    } else if (inline != null && inline.trim().isNotEmpty) {
      segs.add(_Seg(_SegType.inlineMath, inline.trim()));
    }
    cursor = m.end;
  }
  if (cursor < input.length) {
    segs.add(_Seg(_SegType.text, input.substring(cursor)));
  }
  return segs;
}

// ─────────────────────────────────────────────────────────────
//  Line builder
//
//  Strategy:
//    • Split the segment list on newline boundaries.
//    • A line that is ONLY a block-math segment → centred scroll row.
//    • A line that mixes text + inline-math → Wrap row so math flows
//      naturally next to the surrounding words.
//    • A line that is ONLY plain text → MarkdownBody (handles bold,
//      bullets, etc.)
// ─────────────────────────────────────────────────────────────

/// Split segments into "lines" respecting newlines inside text segments.
List<List<_Seg>> _toLines(List<_Seg> segs) {
  final lines   = <List<_Seg>>[];
  var   current = <_Seg>[];

  void flush() {
    if (current.isNotEmpty) lines.add(List.of(current));
    current = [];
  }

  for (final seg in segs) {
    if (seg.type == _SegType.text) {
      final parts = seg.content.split('\n');
      for (int i = 0; i < parts.length; i++) {
        final p = parts[i];
        if (p.isNotEmpty) current.add(_Seg(_SegType.text, p));
        if (i < parts.length - 1) flush();
      }
    } else {
      current.add(seg);
      if (seg.type == _SegType.blockMath) flush();
    }
  }
  flush();
  return lines;
}

// ─────────────────────────────────────────────────────────────
//  Public widget
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
    final theme     = Theme.of(context);
    final baseStyle = style ??
        theme.textTheme.bodyMedium ??
        const TextStyle(fontSize: 14);
    final fontSize  = baseStyle.fontSize ?? 14.0;
    final mdStyle   = styleSheet ?? MarkdownStyleSheet.fromTheme(theme);

    final processed = _preprocess(data);
    final segs      = _parseSegments(processed);

    // Fast path — no LaTeX at all
    final hasLatex = segs.any((s) => s.type != _SegType.text);
    if (!hasLatex) {
      return MarkdownBody(
        data: processed,
        styleSheet: mdStyle,
        selectable: true,
        softLineBreak: true,
      );
    }

    final lines   = _toLines(segs);
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // ── Block math line ──────────────────────────────────
      if (line.length == 1 && line[0].type == _SegType.blockMath) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Center(
                child: _buildMath(
                  line[0].content,
                  MathStyle.display,
                  fontSize + 2,
                  baseStyle,
                ),
              ),
            ),
          ),
        );
        continue;
      }

      // ── Pure text line (no math) → MarkdownBody ──────────
      if (line.every((s) => s.type == _SegType.text)) {
        final combined = line.map((s) => s.content).join(' ');
        if (combined.trim().isEmpty) continue;
        widgets.add(
          MarkdownBody(
            data: combined,
            styleSheet: mdStyle.copyWith(p: baseStyle),
            selectable: true,
            softLineBreak: true,
          ),
        );
        continue;
      }

      // ── Mixed line: inline math + text ───────────────────
      // Build a Wrap so math sits inline with the text tokens.
      final children = <Widget>[];
      for (final seg in line) {
        switch (seg.type) {
          case _SegType.text:
          // Split by spaces and emit each word/phrase so Wrap can reflow.
          // But we keep the whole chunk as one Text so markdown bold etc.
          // still works for simple cases. For complex markdown in inline
          // chunks use MarkdownBody with selectable=false.
            final t = seg.content.trim();
            if (t.isEmpty) break;
            children.add(
              MarkdownBody(
                data: t,
                styleSheet: mdStyle.copyWith(p: baseStyle),
                shrinkWrap: true,
                softLineBreak: true,
              ),
            );
            break;

          case _SegType.inlineMath:
            children.add(
              _buildMath(seg.content, MathStyle.text, fontSize, baseStyle),
            );
            break;

          case _SegType.blockMath:
          // Shouldn't appear in a mixed line, but handle gracefully
            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildMath(
                      seg.content, MathStyle.display, fontSize + 2, baseStyle),
                ),
              ),
            );
            break;
        }
      }

      if (children.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 3,
              runSpacing: 4,
              children: children,
            ),
          ),
        );
      }
    }

    if (widgets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  Widget _buildMath(
      String latex,
      MathStyle mathStyle,
      double fontSize,
      TextStyle base,
      ) {
    final sanitized = latex
        .replaceAll('\n', ' ')
        .replaceAll(r'\left(', r'(')
        .replaceAll(r'\right)', r')')
        .trim();

    if (sanitized.isEmpty) return const SizedBox.shrink();

    return Math.tex(
      sanitized,
      mathStyle: mathStyle,
      textStyle: base.copyWith(fontSize: fontSize),
      onErrorFallback: (_) => SelectableText(
        sanitized,
        style: base.copyWith(
          fontFamily: 'monospace',
          fontSize: fontSize,
          color: Colors.red.shade400,
        ),
      ),
    );
  }
}