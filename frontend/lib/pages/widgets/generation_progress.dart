// lib/widgets/generation_progress.dart
//
// استخدام:
//   GenerationProgress(
//     fileId: widget.fileId!,
//     task: 'summarize',          // أو 'questions' أو 'explain'
//     isArabic: isArabic,
//     onDone: () { /* refresh UI */ },
//   )
//
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

// ─── data model ──────────────────────────────────────────────

class ProgressState {
  final int current;
  final int total;
  final String status; // 'idle' | 'running' | 'done' | 'failed'
  final String message;

  const ProgressState({
    this.current = 0,
    this.total = 0,
    this.status = 'idle',
    this.message = '',
  });

  double get fraction =>
      (total > 0) ? (current / total).clamp(0.0, 1.0) : 0.0;

  int get percent => (fraction * 100).round();

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
  bool get isRunning => status == 'running';
}

// ─── controller (shared between widgets) ─────────────────────

class ProgressController extends ChangeNotifier {
  ProgressState _state = const ProgressState();
  Timer? _timer;
  final ApiService _api = ApiService();
  String? _fileId;
  bool _disposed = false;

  ProgressState get state => _state;

  /// ابدأ الـ polling — بتتكلمها بعد ما تبعت الـ request للـ API
  void start(String fileId) {
    _fileId = fileId;
    _state = const ProgressState(status: 'running', message: 'Starting...');
    notifyListeners();
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), _poll);
  }

  Future<void> _poll() async {
    if (_fileId == null || _disposed) return;

    try {
      final response = await _api.dio.get('/files/$_fileId/progress');
      final data = response.data;

      if (data['success'] == true) {
        final p = data['data'];
        _state = ProgressState(
          current:  (p['current']  ?? 0)  as int,
          total:    (p['total']    ?? 0)  as int,
          status:   (p['status']   ?? 'running') as String,
          message:  (p['message']  ?? '')  as String,
        );
        if (!_disposed) notifyListeners();

        // لو خلص أو فشل — وقف الـ polling
        if (_state.isDone || _state.isFailed) {
          _timer?.cancel();
          return;
        }
      }
    } catch (_) {
      // network error — كمل polling بدون crash
    }

    if (!_disposed) _scheduleNext();
  }

  void reset() {
    _timer?.cancel();
    _state = const ProgressState();
    _fileId = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

// ─── GenerationProgress widget ────────────────────────────────

class GenerationProgress extends StatelessWidget {
  final ProgressController controller;
  final bool isArabic;

  const GenerationProgress({
    Key? key,
    required this.controller,
    required this.isArabic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;

        // مش شغال بعد → مش بتعرضي حاجة
        if (state.status == 'idle') return const SizedBox.shrink();

        return _ProgressCard(state: state, isArabic: isArabic);
      },
    );
  }
}

// ─── _ProgressCard ────────────────────────────────────────────

class _ProgressCard extends StatefulWidget {
  final ProgressState state;
  final bool isArabic;

  const _ProgressCard({required this.state, required this.isArabic});

  @override
  State<_ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<_ProgressCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state  = widget.state;
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ألوان حسب الحالة
    final Color accent = state.isFailed
        ? const Color(0xFFEF4444)
        : state.isDone
            ? const Color(0xFF10B981)
            : const Color(0xFF6366F1);

    final String label = _label(state, widget.isArabic);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── top row ──────────────────────────────────────
          Row(
            children: [
              // أيقونة متحركة
              _StatusIcon(state: state, accent: accent, pulse: _pulse),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    if (state.message.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        state.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // النسبة المئوية
              if (state.isRunning)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    '${state.percent}%',
                    key: ValueKey(state.percent),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: accent,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // ── progress bar ──────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: state.fraction),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => LinearProgressIndicator(
                value: state.isDone ? 1.0 : value,
                minHeight: 8,
                backgroundColor: accent.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),

          // ── chunk counter ─────────────────────────────────
          if (state.total > 0 && state.isRunning) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isArabic
                      ? 'الجزء ${state.current} من ${state.total}'
                      : 'Chunk ${state.current} of ${state.total}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                // خطوط التقدم المصغرة
                _ChunkDots(
                  current: state.current,
                  total: state.total,
                  accent: accent,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _label(ProgressState s, bool ar) {
    if (s.isFailed) return ar ? 'فشلت العملية' : 'Operation failed';
    if (s.isDone)   return ar ? 'اكتملت العملية ✓' : 'Done ✓';
    if (s.total > 0)
      return ar
          ? 'جاري المعالجة...'
          : 'Processing...';
    return ar ? 'جاري التحضير...' : 'Preparing...';
  }
}

// ─── Status icon ──────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  final ProgressState state;
  final Color accent;
  final Animation<double> pulse;

  const _StatusIcon({
    required this.state,
    required this.accent,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isDone) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check_rounded, color: accent, size: 20),
      );
    }

    if (state.isFailed) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.error_outline_rounded, color: accent, size: 20),
      );
    }

    // running — نبضة
    return FadeTransition(
      opacity: pulse,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
      ),
    );
  }
}

// ─── chunk dots ───────────────────────────────────────────────

class _ChunkDots extends StatelessWidget {
  final int current;
  final int total;
  final Color accent;

  const _ChunkDots({
    required this.current,
    required this.total,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    // عرض max 10 نقاط عشان مش يتكسر الـ layout
    final displayTotal = total.clamp(1, 10);
    final ratio = current / total;
    final filledCount = (ratio * displayTotal).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(displayTotal, (i) {
        final filled = i < filledCount;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(right: 3),
          width: filled ? 12 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: filled ? accent : accent.withOpacity(0.18),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}
