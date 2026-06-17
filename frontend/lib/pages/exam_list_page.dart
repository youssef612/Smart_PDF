import 'package:flutter/material.dart';
import 'exam_models.dart';
import 'exam_page.dart';
import '../services/files_service.dart';
import '../services/exam_service.dart';

class ExamListPage extends StatefulWidget {
  final bool isArabic;
  final FilesService filesService;
  final String? currentFileId;
  final String? currentFileName;
  final int? currentPageCount;

  const ExamListPage({
    Key? key,
    required this.isArabic,
    required this.filesService,
    this.currentFileId,
    this.currentFileName,
    this.currentPageCount,
  }) : super(key: key);

  @override
  State<ExamListPage> createState() => _ExamListPageState();
}

class _ExamListPageState extends State<ExamListPage> with SingleTickerProviderStateMixin {
  bool get isArabic => widget.isArabic;

  final ExamService _examService = ExamService();
  bool _loading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  AnimationController? _listAnimationController;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    _loadExams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listAnimationController?.dispose();
    super.dispose();
  }

  Future<void> _loadExams() async {
    try {
      final data = await _examService.fetchAll();
      ExamStore.loadFromApi(data);
    } catch (e) {
      debugPrint('Load exams error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _listAnimationController?.forward();
      }
    }
  }

  void _openSheet(ExamSheet sheet) async {
    ExamStore.setActive(sheet);

    int pageCount = sheet.pageCount ?? 0;

    if (pageCount == 0) {
      final fileId = sheet.fileId ?? widget.currentFileId;
      if (fileId != null) {
        try {
          final fileData = await widget.filesService.getFile(fileId);
          print('📄 fileData: $fileData'); // للـ debug
          pageCount = (fileData?['page_count'] as num?)?.toInt() ?? 0;
          print('📄 pageCount from API: $pageCount'); // للـ debug
          sheet.pageCount = pageCount;
        } catch (e) {
          debugPrint('Error fetching page count: $e');
        }
      }
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamPage(
          isArabic    : isArabic,
          filesService: widget.filesService,
          fileId      : sheet.fileId ?? widget.currentFileId,
          fileName    : sheet.fileName ?? widget.currentFileName,
          pageCount   : pageCount, // ✅ دلوقتي بيوصل صح
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _newExam() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        constraints: const BoxConstraints(maxWidth: 480),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isArabic ? 'اسم الامتحان' : 'Exam Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isArabic ? 'مثال: امتحان الفصل الأول' : 'e.g. Midterm Exam',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (v) =>
              Navigator.pop(ctx, v.trim().isEmpty ? null : v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              ctx,
              controller.text.trim().isEmpty ? null : controller.text.trim(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isArabic ? 'إنشاء' : 'Create'),
          ),
        ],
      ),
    );

    if (name == null) return;

    try {
      final created = await _examService.create(
        title   : name,
        fileId  : widget.currentFileId,
        fileName: widget.currentFileName,
        pageCount: widget.currentPageCount,
      );

      final sheet = ExamStore.newSheet(title: name)
        ..dbId = (created?['id'] ?? created?['_id'])?.toString()
        ..fileId   = widget.currentFileId
        ..fileName = widget.currentFileName
        ..pageCount = widget.currentPageCount ?? 0;

      if (mounted) {
        setState(() {});
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExamPage(
              isArabic    : isArabic,
              filesService: widget.filesService,
              fileId      : sheet.fileId,
              fileName    : sheet.fileName,
              pageCount   : 0,
            ),
          ),
        ).then((_) => setState(() {}));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'فشل الإنشاء' : 'Failed to create exam'),
          ),
        );
      }
    }
  }

  void _confirmDelete(ExamSheet sheet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        constraints: const BoxConstraints(maxWidth: 480),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isArabic ? 'حذف الامتحان؟' : 'Delete Exam?'),
        content: Text(
          isArabic
              ? 'هيتم حذف "${sheet.title}" نهائياً'
              : '"${sheet.title}" will be permanently deleted',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (sheet.dbId != null) {
                  await _examService.delete(sheet.dbId!);
                }
                if (mounted) setState(() => ExamStore.removeSheet(sheet));
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isArabic ? 'فشل الحذف' : 'Delete failed')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isArabic ? 'حذف' : 'Delete',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(ExamSheet sheet) {
    final renameController = TextEditingController(text: sheet.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isArabic ? 'إعادة تسمية الامتحان' : 'Rename Exam'),
        content: TextField(
          controller: renameController,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = renameController.text.trim();
              if (newTitle.isEmpty) return;
              Navigator.pop(ctx);

              final oldTitle = sheet.title;
              setState(() => sheet.title = newTitle);

              if (sheet.dbId != null) {
                final ok = await _examService.rename(sheet.dbId!, newTitle);
                if (!ok && mounted) {
                  setState(() => sheet.title = oldTitle);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isArabic ? 'فشل حفظ التعديل في السيرفر' : 'Failed to save changes')),
                  );
                  return;
                }
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isArabic ? 'تم حفظ الاسم الجديد بنجاح' : 'Name updated successfully'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            child: Text(isArabic ? 'حفظ' : 'Save', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _togglePinExam(ExamSheet sheet) async {
    final newPinned = sheet.duration != 'PINNED';
    final oldDurationStatus = sheet.duration;

    setState(() => sheet.duration = newPinned ? 'PINNED' : '');

    if (sheet.dbId != null) {
      final ok = await _examService.togglePin(sheet.dbId!, pinned: newPinned);
      if (!ok && mounted) {
        setState(() => sheet.duration = oldDurationStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isArabic ? 'فشل تحديث التثبيت في قاعدة البيانات' : 'Failed to update pin on server')),
        );
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newPinned
              ? (isArabic ? '📌 تم تثبيت الامتحان' : '📌 Exam pinned')
              : (isArabic ? '🔓 تم إلغاء التثبيت' : '🔓 Exam unpinned')),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showOptionsMenu(BuildContext context, TapDownDetails details, ExamSheet sheet) {
    final double globalX = details.globalPosition.dx;
    final double globalY = details.globalPosition.dy;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isPinned = sheet.duration == 'PINNED';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Menu',
      barrierColor: Colors.black.withOpacity(0.01),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        return Stack(
          children: [
            Positioned(
              left: isArabic ? null : (globalX - 160).clamp(10.0, MediaQuery.of(context).size.width - 190),
              right: isArabic ? (MediaQuery.of(context).size.width - globalX - 20).clamp(10.0, MediaQuery.of(context).size.width - 190) : null,
              top: globalY.clamp(10.0, MediaQuery.of(context).size.height - 200),
              child: ScaleTransition(
                scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                alignment: isArabic ? Alignment.topRight : Alignment.topLeft,
                child: FadeTransition(
                  opacity: animation,
                  child: Material(
                    type: MaterialType.canvas,
                    color: isDark ? const Color(0xFF262626) : Colors.white,
                    elevation: 12,
                    shadowColor: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                    ),
                    child: Container(
                      width: 170,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MenuHoverItem(
                            icon: isPinned ? Icons.pin_end_rounded : Icons.push_pin_rounded,
                            label: isPinned ? (isArabic ? 'إلغاء التثبيت' : 'Unpin') : (isArabic ? 'تثبيت' : 'Pin'),
                            color: const Color(0xFF6366F1),
                            isDark: isDark,
                            isArabic: isArabic,
                            onTap: () {
                              Navigator.pop(ctx);
                              _togglePinExam(sheet);
                            },
                          ),
                          _MenuHoverItem(
                            icon: Icons.drive_file_rename_outline_rounded,
                            label: isArabic ? 'إعادة تسمية' : 'Rename',
                            color: isDark ? Colors.white70 : Colors.black54,
                            isDark: isDark,
                            isArabic: isArabic,
                            onTap: () {
                              Navigator.pop(ctx);
                              _showRenameDialog(sheet);
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                          ),
                          _MenuHoverItem(
                            icon: Icons.delete_outline_rounded,
                            label: isArabic ? 'حذف' : 'Delete',
                            color: Colors.redAccent,
                            isDark: isDark,
                            isArabic: isArabic,
                            onTap: () {
                              Navigator.pop(ctx);
                              _confirmDelete(sheet);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return isArabic ? 'الآن' : 'Just now';
    if (diff.inHours < 1) return isArabic ? 'منذ ${diff.inMinutes} دقيقة' : '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return isArabic ? 'منذ ${diff.inHours} ساعة' : '${diff.inHours}h ago';
    if (diff.inDays < 7) return isArabic ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final allSheets = List<ExamSheet>.from(ExamStore.sheets);
    final filteredSheets = allSheets.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.title.toLowerCase().contains(_searchQuery) || s.subject.toLowerCase().contains(_searchQuery);
    }).toList();

    filteredSheets.sort((a, b) {
      final aPinned = a.duration == 'PINNED' ? 1 : 0;
      final bPinned = b.duration == 'PINNED' ? 1 : 0;
      if (aPinned != bPinned) return bPinned.compareTo(aPinned);
      return b.createdAt.compareTo(a.createdAt);
    });

    if (_loading) {
      return Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
        ),
      );
    }

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: theme.cardColor,
          title: Text(
            isArabic ? 'امتحاناتي' : 'My Exams',
            style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: isArabic ? 'ابحث عن امتحان أو مادة...' : 'Search exams or subjects...',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                      onTap: () => _searchController.clear(),
                      child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _newExam,
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            isArabic ? 'امتحان جديد' : 'New Exam',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: filteredSheets.isEmpty
            ? _buildEmpty(theme)
            : _buildList(theme, filteredSheets),
      ),
    );
  }

  Widget _buildList(ThemeData theme, List<ExamSheet> sheets) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: sheets.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (ctx, i) {
        final sheet = sheets[i];

        final itemDelay = (i * 0.05).clamp(0.0, 0.99);
        final itemAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _listAnimationController!,
            curve: Interval(itemDelay, 1.0, curve: Curves.easeOutCubic),
          ),
        );

        return AnimatedBuilder(
          animation: _listAnimationController!,
          builder: (context, child) => Opacity(
            opacity: itemAnimation.value,
            child: Transform.translate(
              offset: Offset(0, 24 * (1.0 - itemAnimation.value)),
              child: child,
            ),
          ),
          child: HoverableExamCard(
            sheet: sheet,
            isArabic: isArabic,
            date: _formatDate(sheet.createdAt),
            onTap: () => _openSheet(sheet),
            onMoreOptions: (details) => _showOptionsMenu(context, details, sheet),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_outlined, size: 52, color: Color(0xFF6366F1)),
          ),
          const SizedBox(height: 24),
          Text(
            isArabic ? 'مفيش امتحانات تطابق بحثك' : 'No exams match your search',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            isArabic ? 'جرّب كتابة اسم آخر أو أنشئ امتحاناً جديداً' : 'Try searching for something else or create a new exam',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  HoverableExamCard - كارت تفاعلي معدل يظهر زر الخيارات عند الـ Hover فقط
// ─────────────────────────────────────────────────────────────
class HoverableExamCard extends StatefulWidget {
  final ExamSheet sheet;
  final bool isArabic;
  final String date;
  final VoidCallback onTap;
  final Function(TapDownDetails) onMoreOptions;

  const HoverableExamCard({
    Key? key,
    required this.sheet,
    required this.isArabic,
    required this.date,
    required this.onTap,
    required this.onMoreOptions,
  }) : super(key: key);

  @override
  State<HoverableExamCard> createState() => _HoverableExamCardState();
}

class _HoverableExamCardState extends State<HoverableExamCard> {
  bool _isHovered = false;
  TapDownDetails? _tapDownDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = widget.sheet.typeCounts;
    final isDark = theme.brightness == Brightness.dark;
    final bool isPinned = widget.sheet.duration == 'PINNED';

    final Color accentColor = const Color(0xFF6366F1);

    final effectiveBgColor = isPinned
        ? accentColor.withOpacity(isDark ? 0.15 : 0.08)
        : (_isHovered ? accentColor.withOpacity(isDark ? 0.14 : 0.07) : Colors.transparent);

    final currentElementColor = (isPinned || _isHovered) ? accentColor : theme.textTheme.bodyLarge?.color;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        transform: Matrix4.identity()
          ..translate(_isHovered && !isPinned ? (widget.isArabic ? -4.0 : 4.0) : 0.0)
          ..scale(_isHovered && !isPinned ? 1.025 : 1.0),
        decoration: BoxDecoration(
          color: effectiveBgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _isHovered && !isPinned
                  ? accentColor.withOpacity(isDark ? 0.12 : 0.06)
                  : Colors.transparent,
              blurRadius: 8.0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: accentColor.withOpacity(0.08),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: _isHovered && !isPinned ? 0.02 : 0.0,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assignment_rounded, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.sheet.title.isNotEmpty ? widget.sheet.title : (widget.isArabic ? 'امتحان' : 'Exam'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: currentElementColor,
                                fontSize: 14,
                                fontWeight: isPinned || _isHovered ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (isPinned) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.push_pin_rounded, size: 13, color: accentColor),
                          ]
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.quiz_rounded, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            widget.isArabic ? '${widget.sheet.questions.length} سؤال' : '${widget.sheet.questions.length} questions',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                          if (widget.sheet.subject.isNotEmpty) ...[
                            Text('  •  ', style: TextStyle(color: Colors.grey[400])),
                            Flexible(
                              child: Text(
                                widget.sheet.subject,
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (counts.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: counts.entries.take(3).map((e) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${e.value} ${e.key}',
                                style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(widget.date, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: _isHovered ? 1.0 : 0.0, // تم التعديل هنا ليعتمد فقط على الـ Hover المباشر للماوس
                          child: GestureDetector(
                            onTapDown: (details) => _tapDownDetails = details,
                            onTap: () {
                              if (_isHovered && _tapDownDetails != null) { // تم جعل التحقق يعتمد على الـ Hover فقط
                                widget.onMoreOptions(_tapDownDetails!);
                              }
                            },
                            child: Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.more_horiz_rounded,
                                size: 16,
                                color: isPinned ? accentColor : theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey[400]),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────
//  _MenuHoverItem - تأثير التمرير الحركي الاحترافي لعناصر القائمة المنبثقة
// ─────────────────────────────────────────────────────────────
class _MenuHoverItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final bool isArabic;
  final VoidCallback onTap;

  const _MenuHoverItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.isArabic,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_MenuHoverItem> createState() => _MenuHoverItemState();
}

class _MenuHoverItemState extends State<_MenuHoverItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverBgColor = widget.color.withOpacity(widget.isDark ? 0.08 : 0.04);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..translate(_isHovered ? (widget.isArabic ? -2.0 : 2.0) : 0.0)
          ..scale(_isHovered ? 1.03 : 1.0),
        decoration: BoxDecoration(
          color: _isHovered ? hoverBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            splashColor: widget.color.withOpacity(0.12),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _isHovered ? 0.02 : 0.0,
                    child: Icon(widget.icon, size: 17, color: widget.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
                        color: widget.color == Colors.redAccent
                            ? Colors.redAccent
                            : (widget.isDark ? Colors.white.withOpacity(0.87) : Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}