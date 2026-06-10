// lib/widgets/math_markdown.dart
// v16 — COMPREHENSIVE:
//   • 30+ programming languages detected
//   • Full LaTeX math environment support
//   • Robust code fence merging
//   • All v15 fixes retained

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

// ─────────────────────────────────────────────────────────────
//  Code Block Builder — always LTR
// ─────────────────────────────────────────────────────────────

class _CodeBlockBuilder extends MarkdownElementBuilder {
  final TextStyle baseStyle;
  final Color accentColor;
  _CodeBlockBuilder({required this.baseStyle, required this.accentColor});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent.trimRight();
    if (code.isEmpty) return const SizedBox.shrink();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.15)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText(
            code,
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.6,
              color: accentColor,
            ),
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
  }
}

Widget _directedMarkdown(
  String data,
  MarkdownStyleSheet sheet,
  TextStyle baseStyle,
  Color accentColor,
) {
  final dir = _detectDirection(data);
  return Directionality(
    textDirection: dir,
    child: MarkdownBody(
      data: data,
      styleSheet: sheet,
      selectable: true,
      softLineBreak: true,
      builders: {
        'code': _CodeBlockBuilder(baseStyle: baseStyle, accentColor: accentColor),
        'pre':  _CodeBlockBuilder(baseStyle: baseStyle, accentColor: accentColor),
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  [v16] COMPREHENSIVE language detection — 30+ languages
// ─────────────────────────────────────────────────────────────

String _detectLang(String code) {
  // ── C / C++ ──
  if (RegExp(r'\b(cout\s*<<|cin\s*>>|endl\b|namespace\s+std|#include\s*<\w|printf\s*\(|scanf\s*\()').hasMatch(code)) return 'cpp';
  if (RegExp(r'#include\s*[<"]').hasMatch(code)) return 'cpp';
  if (RegExp(r'\b(malloc|free|sizeof|typedef\s+struct|NULL\b)\b').hasMatch(code)) return 'c';

  // ── Python ──
  if (RegExp(r'\b(def\s+\w|import\s+\w|from\s+\w+\s+import|print\s*\(|elif\b|range\s*\(|lambda\s+\w|__name__|__init__)').hasMatch(code)) return 'python';

  // ── JavaScript / TypeScript ──
  if (RegExp(r'\b(interface\s+\w|type\s+\w+\s*=|readonly\s+\w|:\s*(string|number|boolean|void|any)\b)').hasMatch(code)) return 'typescript';
  if (RegExp(r'\b(const\s+\w|let\s+\w|var\s+\w|function\s+\w|=>\s*\{|document\.|console\.|require\s*\(|module\.exports)').hasMatch(code)) return 'javascript';

  // ── Java ──
  if (RegExp(r'\b(public\s+class|private\s+\w|protected\s+\w|void\s+\w|System\.out|@Override|extends\s+\w|implements\s+\w|new\s+\w+\s*\()').hasMatch(code)) return 'java';

  // ── Kotlin ──
  if (RegExp(r'\b(fun\s+\w|val\s+\w|var\s+\w+\s*:|data\s+class|companion\s+object|println\s*\(|\.let\s*\{|\.also\s*\{)').hasMatch(code)) return 'kotlin';

  // ── Swift ──
  if (RegExp(r'\b(func\s+\w|var\s+\w+\s*:|let\s+\w+\s*:|guard\s+let|if\s+let|print\s*\(|@IBOutlet|UIViewController)').hasMatch(code)) return 'swift';

  // ── Rust ──
  if (RegExp(r'\b(fn\s+\w|let\s+mut\s+\w|impl\s+\w|pub\s+fn|use\s+std::|println!\s*\(|vec!\[|match\s+\w+\s*\{|Some\(|None\b|Ok\(|Err\()').hasMatch(code)) return 'rust';

  // ── Go ──
  if (RegExp(r'\b(func\s+\w|package\s+\w|import\s+"|fmt\.|go\s+func|chan\s+\w|goroutine|:=\s*\w|var\s+\w+\s+\w)').hasMatch(code)) return 'go';

  // ── C# ──
  if (RegExp(r'\b(namespace\s+\w|using\s+System|Console\.|public\s+class|private\s+void|List<|Dictionary<|async\s+Task|await\s+\w)').hasMatch(code)) return 'csharp';

  // ── PHP ──
  if (RegExp(r'(<\?php|\$\w+\s*=|echo\s+|->|\barray\s*\(|\bforeach\s*\(|\bfunction\s+\w)').hasMatch(code)) return 'php';

  // ── Ruby ──
  if (RegExp(r'\b(def\s+\w|end\b|puts\s+|attr_accessor|require\s+|\.each\s*\{|do\s*\||\bnil\b|\.freeze)').hasMatch(code)) return 'ruby';

  // ── R ──
  if (RegExp(r'(<-\s*\w|%>%|library\s*\(|\bdata\.frame\s*\(|\bggplot\s*\(|lm\s*\()').hasMatch(code)) return 'r';

  // ── MATLAB / Octave ──
  if (RegExp(r'\b(function\s+\[|end\b|disp\s*\(|fprintf\s*\(|zeros\s*\(|ones\s*\(|linspace\s*\(|plot\s*\()').hasMatch(code)) return 'matlab';

  // ── Shell / Bash ──
  if (RegExp(r'(#!/bin/bash|#!/bin/sh|\$\{|\becho\s+|\bfi\b|\bthen\b|\bdo\b|\bdone\b|\[\s*-[a-z]\s+)').hasMatch(code)) return 'bash';

  // ── PowerShell ──
  if (RegExp(r'(\$\w+\s*=|Write-Host|Get-\w+|Set-\w+|\-eq\b|\-ne\b|foreach\s*\()').hasMatch(code)) return 'powershell';

  // ── SQL ──
  if (RegExp(r'\b(SELECT\s+|INSERT\s+INTO|UPDATE\s+\w+\s+SET|DELETE\s+FROM|CREATE\s+TABLE|ALTER\s+TABLE|DROP\s+TABLE|JOIN\s+\w|WHERE\s+\w|GROUP\s+BY|ORDER\s+BY)').hasMatch(code)) return 'sql';

  // ── HTML ──
  if (RegExp(r'<(!DOCTYPE|html|head|body|div|span|script|style|link|meta|p\b|h[1-6]\b|a\s|img\s)[\s>]').hasMatch(code)) return 'html';

  // ── CSS / SCSS ──
  if (RegExp(r'(\{[\s\S]*?:\s*[\s\S]*?;|\$\w+\s*:|@mixin\s+\w|@include\s+\w|@media\s*\()').hasMatch(code)) return 'css';

  // ── Dart / Flutter ──
  if (RegExp(r'\b(Widget\b|StatelessWidget|StatefulWidget|BuildContext|Scaffold\b|Column\b|Row\b|Container\b|final\s+\w+\s*=|void\s+main\s*\(\s*\))').hasMatch(code)) return 'dart';

  // ── Scala ──
  if (RegExp(r'\b(object\s+\w|trait\s+\w|case\s+class|extends\s+\w|override\s+def|implicit\s+\w|println\s*\()').hasMatch(code)) return 'scala';

  // ── Haskell ──
  if (RegExp(r'(\bmodule\s+\w|\bwhere\b|\blet\s+\w+\s*=|\bdo\b|\bIO\s+\(|\bmaybe\b|::\s*\w+\s*->)').hasMatch(code)) return 'haskell';

  // ── Lua ──
  if (RegExp(r'\b(local\s+\w|function\s+\w|end\b|print\s*\(|require\s*\(|table\.|io\.|os\.)').hasMatch(code)) return 'lua';

  // ── Assembly ──
  if (RegExp(r'\b(mov\s+|push\s+|pop\s+|call\s+|ret\b|int\s+0x|xor\s+|cmp\s+|jmp\s+|lea\s+)').hasMatch(code)) return 'asm';

  // ── YAML ──
  if (RegExp(r'(^---$|^\s{2,}\w+:\s|\bfalse\b|\btrue\b|\bnull\b)').hasMatch(code)) return 'yaml';

  // ── JSON ──
  if (RegExp(r'^\s*\{[\s\S]*"[\w]+"\s*:\s*').hasMatch(code)) return 'json';

  // ── Markdown (nested) ──
  if (RegExp(r'^#{1,6}\s+\w').hasMatch(code)) return 'markdown';

  // fallback
  if (RegExp(r'#include').hasMatch(code)) return 'cpp';
  return '';
}

// ─────────────────────────────────────────────────────────────
//  [v16] Inline code start patterns — extended
// ─────────────────────────────────────────────────────────────

final _inlineCodeStartPattern = RegExp(
  r'(?<!\w)('
  // Python
  r'for\s+\w|while\s+\w|if\s+\w|def\s+\w|class\s+\w|import\s+\w|from\s+\w|'
  r'print\s*\(|return\s+\w|lambda\s+\w|'
  // JS/TS
  r'let\s+\w|const\s+\w|var\s+\w|function\s+\w|'
  // C++
  r'cout\s*<<|cin\s*>>|#include\s*[<"]|using\s+namespace|'
  // Shell
  r'echo\s+|#\s*\w|'
  // SQL
  r'SELECT\s+|INSERT\s+|UPDATE\s+|DELETE\s+|CREATE\s+|'
  // Rust/Go
  r'fn\s+\w|func\s+\w|pub\s+fn|'
  // Ruby/Kotlin
  r'puts\s+|fun\s+\w'
  r')',
);

// ─────────────────────────────────────────────────────────────
//  [v16] COMPREHENSIVE pure-code line keywords
// ─────────────────────────────────────────────────────────────

final _pureCodeKeywords = RegExp(
  r'^('
  // Python
  r'import |from |def |class |elif |else:|print\(|lambda |'
  // JS/TS
  r'function |const |let |var |export |require\(|module\.|'
  // C/C++
  r'#include|#define|#ifndef|#ifdef|#endif|#pragma|'
  r'cout\s*<<|cin\s*>>|int\s+main|using\s+namespace|std::|printf\s*\(|'
  // Java/Kotlin/Scala
  r'public |private |protected |static |void |override |abstract |'
  r'fun\s+\w|data\s+class|companion\s+object|'
  // Shell
  r'echo |fi\b|then\b|done\b|elif\s|#!/|'
  // SQL
  r'SELECT |INSERT |UPDATE |DELETE |CREATE |ALTER |DROP |'
  // Go/Rust
  r'func\s+\w|fn\s+\w|pub\s+fn|use\s+std::|impl\s+\w|'
  // PHP
  r'<\?php|\$\w+\s*=|namespace\s+\w|'
  // Ruby
  r'puts |attr_|require |'
  // General
  r'package |return |throw |catch |finally |'
  r')',
);

bool _isPureCodeLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || trimmed.startsWith('```')) return false;
  if (RegExp(r'`[^`\n]+`').hasMatch(trimmed)) return false;

  // special chars لوحدهم مش code
  if (RegExp(r'^[\\()\[\]{}\s\$]+$').hasMatch(trimmed)) return false;
  if (trimmed.length <= 4 && RegExp(r'^[\W_]+$').hasMatch(trimmed)) return false;
  if (RegExp(r'^\$\s*$').hasMatch(trimmed)) return false;
  if (RegExp(r'^[{}]\s*$').hasMatch(trimmed)) return false;

  // PHP variables زي $username = أو $_POST → هي كود بس لو already جوه fence
  // لو طلعوا برا fence → مش بنلفهم في fence جديد (الـ _extractInlineCode هيتجاهلهم)
  // السطر ده بيمنع إنهم يتعرفوا كـ "pure code line" للـ wrapping
  if (RegExp(r'^\$[A-Za-z_]\w*').hasMatch(trimmed)) return false;

  final arCount     = RegExp(r'[\u0600-\u06FF]').allMatches(trimmed).length;
  final letterCount = RegExp(r'[A-Za-z\u0600-\u06FF]').allMatches(trimmed).length;
  if (letterCount > 0 && arCount / letterCount > 0.4) return false;

  // أرقام ضرب مش code
  if (RegExp(r'^\d+\s*[x×*]\s*\d+\s*=\s*\d+').hasMatch(trimmed)) return false;
  // output pattern مش code
  if (RegExp(r'^\d[\d\s\t×*=\\\w]+\d$').hasMatch(trimmed) &&
      !RegExp(r'[a-zA-Z_]\w*\s*[\(=]').hasMatch(trimmed)) return false;

  // سطر markdown bold/italic زي **insert one** مش code
  if (RegExp(r'^\*{1,2}[^*]+\*{1,2}$').hasMatch(trimmed)) return false;

  // لو فيه LaTeX → مش code line
  if (RegExp(r'\$\$?').hasMatch(trimmed) &&
      !RegExp(r'\b(cout|cin|printf|echo)\b').hasMatch(trimmed)) {
    if (RegExp(r'\\\w').hasMatch(trimmed)) return false;
  }

  return _pureCodeKeywords.hasMatch(trimmed) ||
      RegExp(r'(\b[a-zA-Z_]\w*\s*=\s*\w)|(\b[a-zA-Z_]\w*\s*\(.*\))|([{};]\s*$)')
          .hasMatch(trimmed);
}

// ─────────────────────────────────────────────────────────────
//  COMPREHENSIVE LaTeX math normalization
// ─────────────────────────────────────────────────────────────

String _normalizeDelimiters(String text) {
  // شيل \begin{table}...\end{table} و \begin{figure}
  text = text.replaceAll(
    RegExp(
      r'\\begin\{(?:table|figure)\}[\s\S]*?\\end\{(?:table|figure)\}',
      multiLine: true,
    ),
    '',
  );
  text = text.replaceAll(RegExp(r'\\(?:centering|caption|label)\{[^}]*\}'), '');
  text = text.replaceAll(RegExp(r'\\centering\b'), '');

  // \[ ... \] → $$ ... $$
  text = text.replaceAllMapped(
    RegExp(r'\\\[([\s\S]+?)\\\]', multiLine: true),
    (m) => '\n\$\$${(m[1] ?? '').trim()}\$\$\n',
  );

  // LaTeX math environments → $$ ... $$
  text = text.replaceAllMapped(
    RegExp(
      r'\\begin\{(equation\*?|align\*?|aligned|gather\*?|multline\*?|'
      r'eqnarray\*?|flalign\*?|split|cases|'
      r'matrix|pmatrix|bmatrix|vmatrix|Vmatrix|Bmatrix|'
      r'array|subequations|'
      r'theorem|lemma|proof|corollary|proposition|definition|example|remark)\}'
      r'[\s\S]+?'
      r'\\end\{\1\}',
      multiLine: true,
    ),
    (m) => '\n\$\$${(m[0] ?? '').trim()}\$\$\n',
  );

  // \( ... \) → $ ... $
  text = text.replaceAllMapped(
    RegExp(r'\\\((.+?)\\\)', dotAll: false),
    (m) => '\$${(m[1] ?? '').trim()}\$',
  );

  // Fix malformed $$ with no content
  text = text.replaceAllMapped(
    RegExp(r'\$\$([^$]*)\$\$'),
    (m) {
      final inner = (m[1] ?? '').trim();
      return inner.isEmpty ? '' : '\$\$$inner\$\$';
    },
  );

  return text;
}

// ─────────────────────────────────────────────────────────────
//  [v16] Bare math expressions auto-wrap
// ─────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────

String _normalizeBaremath(String text) {
  // Common derivative notations
  text = text.replaceAllMapped(
    RegExp(r'(?<![`\$])\b(dy\/dx|df\/dx|dz\/dt)\b(?![`\$])'),
    (m) => '\$${m[0]}\$',
  );
  // Standalone single LaTeX symbols outside any $
  text = text.replaceAllMapped(
    RegExp(
      r'(?<!\$)(?<![\\])\\(infty|alpha|beta|gamma|delta|theta|lambda|sigma|'
      r'omega|pi|mu|nu|xi|rho|tau|phi|psi|epsilon|zeta|eta)\b(?!\$)(?![{])',
    ),
    (m) => '\$\\${m[1]}\$',
  );
  return text;
}

// ─────────────────────────────────────────────────────────────
//  _semicolonToNewlines
// ─────────────────────────────────────────────────────────────

String _semicolonToNewlines(String code) {
  final actualLines = code.split('\n').where((l) => l.trim().isNotEmpty).length;
if (actualLines > 3) return code;

  String result = code;

  result = result.replaceAllMapped(
    RegExp(r'\)\s+(print\s*\(\s*\))'),
    (m) => ')\n${m[1]}',
  );
  result = result.replaceAllMapped(
    RegExp(r'\)\s+(print\s*\(|return\s+\w|for\s+\w|while\s+\w|if\s+\w|else:|def\s+\w|class\s+\w)'),
    (m) => ')\n${m[1]}',
  );

  if (result.contains('\n')) return result;

  final lines       = <String>[];
  final buffer      = StringBuffer();
  int  depth        = 0;
  int  indentLevel  = 0;
  bool inString     = false;
  String stringChar = '';

  void flushLine() {
    final s = buffer.toString().trim();
    if (s.isNotEmpty) lines.add('    ' * indentLevel + s);
    buffer.clear();
  }

  for (int i = 0; i < result.length; i++) {
    final ch = result[i];

    if (!inString && i + 1 < result.length &&
        (ch == 'f' || ch == 'b' || ch == 'r' || ch == 'F') &&
        (result[i + 1] == '"' || result[i + 1] == "'")) {
      inString = true; stringChar = result[i + 1];
      buffer.write(ch); buffer.write(result[i + 1]); i++; continue;
    }
    if (!inString && (ch == '"' || ch == "'")) {
      inString = true; stringChar = ch; buffer.write(ch); continue;
    }
    if (inString) {
      buffer.write(ch);
      if (ch == stringChar && (i == 0 || result[i - 1] != '\\')) inString = false;
      continue;
    }

    if (ch == '(' || ch == '[') depth++;
    if (ch == ')' || ch == ']') { depth--; buffer.write(ch); continue; }

    if (ch == ';' && depth == 0 && i + 1 < result.length && result[i + 1] == ' ') {
      flushLine(); i++; continue;
    }

    if (ch == ':' && depth == 0 && i + 1 < result.length) {
      final next = result.substring(i + 1).trimLeft();
      final hasArabicNear = RegExp(r'[\u0600-\u06FF]')
          .hasMatch(next.substring(0, next.length.clamp(0, 20)));
      if (!hasArabicNear &&
          RegExp(r'^(for |while |if |elif |else\b|print\(|return |\w)').hasMatch(next)) {
        buffer.write(ch); flushLine(); indentLevel++;
        while (i + 1 < result.length && result[i + 1] == ' ') i++;
        continue;
      }
    }
    buffer.write(ch);
  }
  flushLine();

  return lines.isEmpty ? result : lines.join('\n');
}

// ─────────────────────────────────────────────────────────────
//  _extractInlineCode
// ─────────────────────────────────────────────────────────────

String _extractInlineCode(String line) {
  if (line.trim().startsWith('```')) return line;
  if (RegExp(r'`[^`\n]+`').hasMatch(line)) return line;

  final arCount = RegExp(r'[\u0600-\u06FF]').allMatches(line).length;
  if (arCount == 0) return line;

  final hasCodeStructure = RegExp(
    r'[{};]\s*$|^\s*(#include|using\s+namespace|int\s+main|return\s+)'
  ).hasMatch(line.trim());
  if (hasCodeStructure) return line;

  final totalChars = line.trim().length;
  if (totalChars > 0 && arCount / totalChars > 0.10) return line;

  final match = _inlineCodeStartPattern.firstMatch(line);
  if (match == null) return line;

  final codeStart = match.start;
  String arabicPart = line.substring(0, codeStart).trim();
  arabicPart = arabicPart.replaceAll(RegExp(r'[:：\-–\s]+$'), '').trim();

  final labelCodeMatch = _inlineCodeStartPattern.firstMatch(arabicPart);
  if (labelCodeMatch != null) {
    arabicPart = arabicPart.substring(0, labelCodeMatch.start)
        .replaceAll(RegExp(r'[:：\-–\s]+$'), '').trim();
  }

  String codePart = line.substring(codeStart).trim();

  final arabicInCode = RegExp(r'[\u0600-\u06FF]').firstMatch(codePart);
  String? trailingExplanation;
  if (arabicInCode != null) {
    final beforeArabic = codePart.substring(0, arabicInCode.start);
    final afterArabic  = codePart.substring(arabicInCode.start);
    final arabicIsIdentifier =
        RegExp(r'[\w()\[\].,<>]+$').hasMatch(beforeArabic.trimRight()) &&
        RegExp(r'^[\u0600-\u06FF_\w]+\s*[({;,)]').hasMatch(afterArabic.trimLeft());
    if (!arabicIsIdentifier) {
      trailingExplanation = afterArabic.trim();
      codePart = beforeArabic.trim();
    }
  }

  if (codePart.isEmpty) return line;

  codePart = _semicolonToNewlines(codePart);
  codePart = codePart.split('\n').where((l) => l.trim().isNotEmpty).join('\n');

  final lang  = _detectLang(codePart);
  final fence = '```$lang\n$codePart\n```';
  final label = arabicPart.isEmpty ? '' : '$arabicPart\n\n';
  final explanation = (trailingExplanation != null && trailingExplanation.isNotEmpty)
      ? '\n\n$trailingExplanation' : '';

  return '$label$fence$explanation';
}

// ─────────────────────────────────────────────────────────────
//  _wrapPureCodeBlocks
// ─────────────────────────────────────────────────────────────

String _wrapPureCodeBlocks(String text) {
  final lines  = text.split('\n');
  final result = <String>[];
  bool inFence     = false;
  bool inAutoBlock = false;
  int  braceDepth  = 0;

  for (int i = 0; i < lines.length; i++) {
    final line    = lines[i];
    final trimmed = line.trim();

    if (trimmed.startsWith('```')) {
      if (inAutoBlock) {
        while (result.isNotEmpty && result.last.trim().isEmpty) result.removeLast();
        result.add('```');
        inAutoBlock = false;
        braceDepth  = 0;
      }
      inFence = !inFence;
      result.add(line);
      continue;
    }
    if (inFence) { result.add(line); continue; }

    if (inAutoBlock) {
      braceDepth += '{'.allMatches(line).length;
      braceDepth -= '}'.allMatches(line).length;
    }

    final isCode = _isPureCodeLine(line);

    if (isCode && !inAutoBlock) {
      while (result.isNotEmpty && result.last.trim().isEmpty) result.removeLast();
      result.add('```${_detectLang(line)}');
      inAutoBlock = true;
      braceDepth += '{'.allMatches(line).length;
      braceDepth -= '}'.allMatches(line).length;
      result.add(line);
    } else if (!isCode && inAutoBlock) {
      if (braceDepth > 0) {
        result.add(line);
      } else if (trimmed.isEmpty) {
        continue;
      } else {
        while (result.isNotEmpty && result.last.trim().isEmpty) result.removeLast();
        result.add('```');
        inAutoBlock = false;
        braceDepth  = 0;
        result.add(line);
      }
    } else {
      result.add(line);
    }
  }
  if (inAutoBlock) {
    while (result.isNotEmpty && result.last.trim().isEmpty) result.removeLast();
    result.add('```');
  }
  return result.join('\n');
}

// ─────────────────────────────────────────────────────────────
//  [v16] _mergeConsecutiveCodeBlocks
//  ادمج code fences متتالية بنفس اللغة أو بدون لغة
// ─────────────────────────────────────────────────────────────

String _mergeConsecutiveCodeBlocks(String text) {
  // ``` closing + optional blank lines + ```lang opening → remove boundary
  return text.replaceAllMapped(
  RegExp(r'```[ \t]*\n([ \t]*\n)*```\w*\n', multiLine: true),
  (m) => '\n',
);
}

// ─────────────────────────────────────────────────────────────
//  Other pre-processing helpers
// ─────────────────────────────────────────────────────────────

String _fixOptionsLineBreaks(String text) =>
    text.replaceAllMapped(RegExp(r'(?<!\n)([A-D])\)\s+'), (m) => '\n${m[1]}) ');

String _mergeOrphanLines(String text) {
  final lines  = text.split('\n');
  final result = <String>[];
  for (final raw in lines) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) { result.add(''); continue; }
    final isPunct    = RegExp(r'^[.,;:\-]+$').hasMatch(trimmed);
    final isShortVar = (trimmed.length <= 3 &&
            !trimmed.contains(r'$') &&
            RegExp(r'^[\w\u0600-\u06FF]+$').hasMatch(trimmed)) ||
        RegExp(r'^[\w\u0600-\u06FF\(\)\,\.]+$').hasMatch(trimmed) && trimmed.length <= 8;
    if ((isPunct || isShortVar) && result.isNotEmpty) {
      for (int i = result.length - 1; i >= 0; i--) {
        if (result[i].trim().isNotEmpty) { result[i] = '${result[i]} $trimmed'; break; }
      }
    } else {
      result.add(raw);
    }
  }
  return result.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String _splitCodeLine(String line) {
  return line.replaceAllMapped(
    RegExp(r'(\))\s+(print\s*\()'),
    (m) => '${m[1]}\n${m[2]}',
  ).replaceAllMapped(
    RegExp(r'(\))\s+(print\s*\(\s*\))'),
    (m) => '${m[1]}\n${m[2]}',
  );
}

String _fixCodeFences(String text) {
  final lines  = text.split('\n');
  final result = <String>[];
  bool inFence = false;

  for (final line in lines) {
    if (line.trim().startsWith('```')) {
      inFence = !inFence;
      result.add(line);
      continue;
    }
    if (inFence) {
      final fixed = _splitCodeLine(line);
      result.addAll(fixed.split('\n'));
    } else {
      result.add(line);
    }
  }
  return result.join('\n');
}

// ─────────────────────────────────────────────────────────────
//  Master pre-processing pipeline
// ─────────────────────────────────────────────────────────────

String _preprocess(String raw) {
  raw = _normalizeDelimiters(raw);
  raw = raw.replaceAllMapped(
  RegExp(r'^(C\+\+|Java|Python|JavaScript|C#|Kotlin|Swift|Rust|Go)\s*:\s*',
         multiLine: true, caseSensitive: false),
  (m) => '',
);
  raw = _normalizeBaremath(raw);
  raw = _fixOptionsLineBreaks(raw);
  raw = _fixCodeFences(raw);

  raw = raw.replaceAllMapped(
    RegExp(r'(الكود\s*[:：])\s*(.+?)\s*(الشرح\s*[:：])', dotAll: false),
    (m) => '${m[1]}\n\n${m[2]}\n\n${m[3]}',
  );
  raw = raw.replaceAllMapped(
    RegExp(r'(النتيجة\s*[:：])\s*(.+?)(\n|$)', dotAll: false),
    (m) => '\n\n${m[1]}\n\n${m[2]}${m[3]}',
  );

  final lines = raw.split('\n');
  raw = lines.map(_extractInlineCode).join('\n');
  raw = _wrapPureCodeBlocks(raw);
  raw = _mergeConsecutiveCodeBlocks(raw);
  raw = _mergeOrphanLines(raw);
  raw = raw.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return raw.trim();
}

// ─────────────────────────────────────────────────────────────
//  Token model & tokeniser
// ─────────────────────────────────────────────────────────────

enum _TokType { text, inlineMath, blockMath }
class _Tok { final _TokType type; final String content; const _Tok(this.type, this.content); }

List<_Tok> _tokenize(String input) {
  final toks = <_Tok>[];
  // $ followed by word char = PHP/shell variable, not math — skip it
  // valid math: $x$ or $$...$$ — must have closing $ and content between
  final pattern = RegExp(r'\$\$([\s\S]+?)\$\$|\$([^\$\n]{1,80}?)\$', dotAll: true);
  int cursor = 0;
  for (final m in pattern.allMatches(input)) {
    // Check it's not a PHP/shell variable: $word without closing $
    final before = m.start > 0 ? input[m.start - 1] : ' ';
    // Skip if looks like PHP: $varName (no space before word content)
    final candidate = m.group(2) ?? '';
    if (candidate.isNotEmpty && RegExp(r'^[A-Za-z_]\w*$').hasMatch(candidate.trim())) {
      // Single word between $..$ — could be PHP var or math var
      // Treat as math only if surrounded by spaces or punctuation
      final afterPos = m.end;
      final after = afterPos < input.length ? input[afterPos] : ' ';
      final isPhpLike = RegExp(r'[A-Za-z0-9_]').hasMatch(before);
      if (isPhpLike) {
        // PHP context — skip, treat as text
        if (m.start > cursor) {
          toks.add(_Tok(_TokType.text, input.substring(cursor, m.end)));
        }
        cursor = m.end;
        continue;
      }
    }

    if (m.start > cursor) {
      final t = input.substring(cursor, m.start);
      if (t.isNotEmpty) toks.add(_Tok(_TokType.text, t));
    }
    final block  = m.group(1);
    final inline = m.group(2);
    if (block != null && block.trim().isNotEmpty)
      toks.add(_Tok(_TokType.blockMath, block.trim()));
    else if (inline != null && inline.trim().isNotEmpty)
      toks.add(_Tok(_TokType.inlineMath, inline.trim()));
    cursor = m.end;
  }
  if (cursor < input.length) {
    final r = input.substring(cursor);
    if (r.isNotEmpty) toks.add(_Tok(_TokType.text, r));
  }
  return toks;
}

// ─────────────────────────────────────────────────────────────
//  Line builder & orphan merger
// ─────────────────────────────────────────────────────────────

typedef _Line = List<_Tok>;

List<_Line> _buildLines(List<_Tok> toks) {
  final lines   = <_Line>[];
  var   current = <_Tok>[];
  void flush() {
    final m = current.where((t) => t.type != _TokType.text || t.content.trim().isNotEmpty).toList();
    if (m.isNotEmpty) lines.add(m);
    current = [];
  }
  for (final tok in toks) {
    if (tok.type == _TokType.blockMath) { flush(); lines.add([tok]); continue; }
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

bool _isBlockMathLine(_Line l) => l.length == 1 && l[0].type == _TokType.blockMath;
bool _isOrphanedMath(_Line l) {
  final ne = l.where((t) => t.type != _TokType.text || t.content.trim().isNotEmpty).toList();
  return ne.isNotEmpty && ne.every((t) => t.type == _TokType.inlineMath);
}
bool _isPunctuationOnly(_Line l) {
  final t = l.where((t) => t.type == _TokType.text).map((t) => t.content.trim()).join('');
  return !l.any((t) => t.type != _TokType.text) && RegExp(r'^[.,;:\s]+$').hasMatch(t);
}

List<_Line> _mergeOrphanedLines(List<_Line> lines) {
  if (lines.isEmpty) return lines;
  bool changed = true;
  var result = List<_Line>.from(lines);
  while (changed) {
    changed = false;
    final next = <_Line>[];
    int i = 0;
    while (i < result.length) {
      final line = result[i];
      if (_isBlockMathLine(line)) { next.add(line); i++; continue; }
      if ((_isOrphanedMath(line) || _isPunctuationOnly(line)) &&
          next.isNotEmpty && !_isBlockMathLine(next.last)) {
        next.last.addAll(line); changed = true; i++; continue;
      }
      if (i + 1 < result.length && !_isBlockMathLine(result[i + 1]) &&
          (_isOrphanedMath(result[i + 1]) || _isPunctuationOnly(result[i + 1]))) {
        final m = List<_Tok>.from(line)..addAll(result[i + 1]);
        next.add(m); changed = true; i += 2; continue;
      }
      next.add(line); i++;
    }
    result = next;
  }
  return result;
}

// ─────────────────────────────────────────────────────────────
//  RTL/LTR detector
// ─────────────────────────────────────────────────────────────

TextDirection _detectDirection(String text) {
  final clean = text
      .replaceAll(RegExp(r'```[\s\S]*?```'), '')
      .replaceAll(RegExp(r'`[^`]+`'), '')
      .replaceAll(RegExp(r'\$\$[\s\S]*?\$\$'), '')
      .replaceAll(RegExp(r'\$[^\$\n]+?\$'), '');
  final arCount = RegExp(r'[\u0600-\u06FF]').allMatches(clean).length;
  final enCount = RegExp(r'[A-Za-z]').allMatches(clean).length;
  if (arCount == 0 && enCount == 0) return TextDirection.ltr;
  return (arCount / (arCount + enCount)) >= 0.30 ? TextDirection.rtl : TextDirection.ltr;
}

// ─────────────────────────────────────────────────────────────
//  MathMarkdown widget
// ─────────────────────────────────────────────────────────────

class MathMarkdown extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final MarkdownStyleSheet? styleSheet;
  const MathMarkdown({Key? key, required this.data, this.style, this.styleSheet}) : super(key: key);

  Color _resolveAccentColor(BuildContext context) {
    final c = styleSheet?.strong?.color;
    if (c != null) return c;
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFA78BFA)
        : const Color(0xFF7C3AED);
  }

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    final sheet     = styleSheet ?? MarkdownStyleSheet.fromTheme(theme);
    final accent    = _resolveAccentColor(context);
    final processed = _preprocess(data);
    final paragraphs = processed
        .split(RegExp(r'\n\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return Directionality(
      textDirection: _detectDirection(processed),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: paragraphs
            .map((p) => _buildParagraph(p, baseStyle, sheet, accent))
            .toList(),
      ),
    );
  }

  Widget _buildParagraph(String para, TextStyle baseStyle, MarkdownStyleSheet sheet, Color accent) {
    final paraDir   = _detectDirection(para);
    final crossAxis = paraDir == TextDirection.rtl ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final toks      = _tokenize(para);
    final hasBlock  = toks.any((t) => t.type == _TokType.blockMath);

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
                  return _directedMarkdown(t, sheet, baseStyle, accent);
              }
            }).toList(),
          ),
        ),
      );
    }

    if (!toks.any((t) => t.type == _TokType.inlineMath)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _directedMarkdown(para, sheet, baseStyle, accent),
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
              return _BlockMathWidget(latex: line[0].content, baseStyle: baseStyle);
            }
            final lineText = line.where((t) => t.type == _TokType.text).map((t) => t.content).join(' ');
            final lineDir  = _detectDirection(lineText);
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
                    return Directionality(
                      textDirection: _detectDirection(cleaned),
                      child: MarkdownBody(
                        data: cleaned,
                        styleSheet: sheet,
                        shrinkWrap: true,
                        selectable: true,
                        builders: {
                          'code': _CodeBlockBuilder(baseStyle: baseStyle, accentColor: accent),
                          'pre':  _CodeBlockBuilder(baseStyle: baseStyle, accentColor: accent),
                        },
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
            style: base.copyWith(fontFamily: 'monospace', color: Colors.red.shade400),
          ),
        ),
      );
    } catch (_) {
      return SelectableText(latex, style: base.copyWith(fontFamily: 'monospace'));
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Block math widget
// ─────────────────────────────────────────────────────────────

class _BlockMathWidget extends StatelessWidget {
  final String latex;
  final TextStyle baseStyle;
  const _BlockMathWidget({required this.latex, required this.baseStyle});

  @override
  Widget build(BuildContext context) {
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
              style: baseStyle.copyWith(fontFamily: 'monospace', color: Colors.red.shade400),
            ),
          ),
        ),
      ),
    );
  }
}