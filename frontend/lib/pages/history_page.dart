// lib/pages/history_page.dart
import 'package:flutter/material.dart';
import 'widgets/interactive_scale.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart';
import '../utils/responsive.dart';
import '../services/history_store.dart';
import 'questions_page.dart';
import 'summary_page.dart';
import 'explanation_page.dart';

class HistoryPage extends StatefulWidget {
  final String? fileId;
  final String? fileName;

  const HistoryPage({Key? key, this.fileId, this.fileName}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _filtered = [];
  String _search = '';
  String _selectedType = 'all';
  bool _isLoading = true;
  bool _isSearchFocused = false;
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _searchAnimController;
  late Animation<double> _searchAnim;

  static const _primary = Color(0xFF6366F1);
  static const _amber = Color(0xFFF59E0B);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);

  bool get isArabic => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _searchAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnim = CurvedAnimation(
      parent: _searchAnimController,
      curve: Curves.easeOut,
    );
    _searchFocusNode.addListener(() {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
      if (_searchFocusNode.hasFocus) {
        _searchAnimController.forward();
      } else {
        _searchAnimController.reverse();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _searchAnimController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await HistoryStore.getHistory();
    final fileHistory = widget.fileId != null
        ? data.where((e) => e['file_id'] == widget.fileId).toList()
        : data;
    setState(() {
      _history = fileHistory.reversed
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    final q = _search.toLowerCase();
    setState(() {
      _filtered = _history.where((item) {
        final type = item['type']?.toString().toLowerCase() ?? '';
        final fileName = item['file_name']?.toString().toLowerCase() ?? '';
        final matchSearch = q.isEmpty || type.contains(q) || fileName.contains(q);
        final matchType = _selectedType == 'all' || item['type'] == _selectedType;
        return matchSearch && matchType;
      }).toList();
    });
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id != null) {
      await HistoryStore.deleteById(id);
    } else {
      final globalIndex = _history.indexWhere(
          (e) => e['date'] == item['date'] && e['type'] == item['type']);
      if (globalIndex != -1) await HistoryStore.delete(globalIndex);
    }
    _load();
  }

  void _openItem(Map<String, dynamic> item) {
    final itemFileId = widget.fileId ?? item['file_id']?.toString() ?? '';
    final itemFileName = widget.fileName ?? item['file_name']?.toString() ?? 'ملف';

    if (item['type'] == 'questions') {
      final rawData = item['data'];
      List<Map<String, String>> questions = [];
      if (rawData is List) {
        questions = rawData
            .map((q) => Map<String, String>.from(
                (q as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
            .toList();
      }
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => QuestionsPage(
          fileName:     itemFileName,
          fileId:       itemFileId,
          questions:    questions,
          pageCount:    int.tryParse(                      // ✅ بدل 0
              item['page_count']?.toString() ?? '0'
          ) ?? 0,
          questionType: item['question_type']?.toString(),
          difficulty:   item['difficulty']?.toString(),
          fromPage:     item['from_page'] != null         // ✅ أضف
              ? int.tryParse(item['from_page'].toString())
              : null,
          toPage:       item['to_page'] != null           // ✅ أضف
              ? int.tryParse(item['to_page'].toString())
              : null,
        ),
      ));
    } else if (item['type'] == 'summary') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => SummaryPage(fileName: itemFileName, fileId: itemFileId, summary: item['data']?.toString() ?? '',
          pageCount:    int.tryParse(                      // ✅ بدل 0
              item['page_count']?.toString() ?? '0'
          ) ?? 0,
          fromPage:     item['from_page'] != null         // ✅ أضف
            ? int.tryParse(item['from_page'].toString())
            : null,
          toPage:       item['to_page'] != null           // ✅ أضف
              ? int.tryParse(item['to_page'].toString())
              : null,
        ),
      ));
    } else if (item['type'] == 'explanation') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ExplanationPage(fileName: itemFileName, fileId: itemFileId, explanation: item['data'],
          pageCount:    int.tryParse(                      // ✅ بدل 0
              item['page_count']?.toString() ?? '0'
          ) ?? 0,
          fromPage:     item['from_page'] != null         // ✅ أضف
              ? int.tryParse(item['from_page'].toString())
              : null,
          toPage:       item['to_page'] != null           // ✅ أضف
              ? int.tryParse(item['to_page'].toString())
              : null,
        ),
      ));
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'questions': return _amber;
      case 'summary': return _primary;
      case 'explanation': return _green;
      default: return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'questions': return Icons.quiz_rounded;
      case 'summary': return Icons.auto_awesome_rounded;
      case 'explanation': return Icons.school_rounded;
      default: return Icons.history_rounded;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'questions': return isArabic ? 'أسئلة' : 'Questions';
      case 'summary': return isArabic ? 'ملخص' : 'Summary';
      case 'explanation': return isArabic ? 'شرح' : 'Explanation';
      default: return type;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (isArabic) {
        if (diff.inMinutes < 1) return 'الآن';
        if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
        if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
        if (diff.inDays == 1) return 'أمس';
      } else {
        if (diff.inMinutes < 1) return 'Just now';
        if (diff.inHours < 1) return '${diff.inMinutes}m ago';
        if (diff.inDays < 1) return '${diff.inHours}h ago';
        if (diff.inDays == 1) return 'Yesterday';
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return iso; }
  }

  Widget _buildFilterChip(String type, String label, Color color) {
    final isSelected = _selectedType == type;
    return InteractiveScale(
      onTap: () {
        setState(() => _selectedType = type);
        _applyFilter();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.08)])
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ✅ Staggered animated card
  Widget _buildHistoryCard(Map<String, dynamic> item, int index) {
    final theme = Theme.of(context);
    final type = item['type']?.toString() ?? '';
    final color = _typeColor(type);
    final icon = _typeIcon(type);
    final label = _typeLabel(type);
    final date = _formatDate(item['date']?.toString());
    final questionType = item['question_type']?.toString();
    final difficulty = item['difficulty']?.toString();
    final count = item['count'];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 30),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Dismissible(
        key: Key(item['id']?.toString() ?? item['date']?.toString() ?? ''),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_red.withOpacity(0.08), _red.withOpacity(0.15)]),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.delete_rounded, color: _red, size: 24),
              const SizedBox(height: 4),
              Text(isArabic ? 'حذف' : 'Delete',
                  style: const TextStyle(color: _red, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        onDismissed: (_) => _deleteItem(item),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
            child: GestureDetector(
              onTap: () => _openItem(item),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  // ✅ Gradient border
                  border: Border.all(color: color.withOpacity(0.2), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: theme.brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.2)
                          : Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // ✅ Icon with gradient background
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [color.withOpacity(0.2), color.withOpacity(0.08)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Icon(icon, color: color, size: 24),
                      ),
                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color),
                            ),
                            const SizedBox(height: 4),
                            if (widget.fileId == null && item['file_name'] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  item['file_name'].toString(),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (type == 'questions' && (questionType != null || difficulty != null || count != null))
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (count != null) _miniTag(isArabic ? '$count سؤال' : '$count Q', _amber),
                                  if (difficulty != null) _miniTag(_difficultyLabel(difficulty), _difficultyColor(difficulty)),
                                  if (questionType != null) _miniTag(_questionTypeLabel(questionType), _primary),
                                ],
                              ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 13, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _questionTypeLabel(String type) {
    switch (type) {
      case 'multiple_choice': return isArabic ? 'اختيار متعدد' : 'multiple';
      case 'true_false': return isArabic ? 'صح أو خطأ' : 'True / False';
      case 'short_answer': return isArabic ? 'إجابة قصيرة' : 'Short Answer';
      default: return type;
    }
  }

  String _difficultyLabel(String d) {
    switch (d) {
      case 'easy': return isArabic ? 'سهل' : 'Easy';
      case 'medium': return isArabic ? 'متوسط' : 'Medium';
      case 'hard': return isArabic ? 'صعب' : 'Hard';
      default: return d;
    }
  }

  Color _difficultyColor(String d) {
    switch (d) {
      case 'easy': return _green;
      case 'medium': return _amber;
      case 'hard': return _red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: theme.cardColor,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? 'السجل' : 'History',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                widget.fileName ?? (isArabic ? 'كل المستندات' : 'All Documents'),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            if (_history.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: _red),
                tooltip: isArabic ? 'حذف الكل' : 'Clear All',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      constraints: const BoxConstraints(maxWidth: 480),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text(isArabic ? 'حذف الكل؟' : 'Clear All?'),
                      content: Text(isArabic
                          ? 'هيتم حذف كل السجل الخاص بالملف ده.'
                          : 'All history for this file will be deleted.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isArabic ? 'إلغاء' : 'Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true),
                            child: Text(isArabic ? 'حذف' : 'Delete', style: const TextStyle(color: _red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await HistoryStore.clear();
                    _load();
                  }
                },
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
            child: Column(
              children: [
                // ✅ Animated Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: AnimatedBuilder(
                    animation: _searchAnim,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withOpacity(0.15 * _searchAnim.value),
                              blurRadius: 16 * _searchAnim.value,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          focusNode: _searchFocusNode,
                          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                          decoration: InputDecoration(
                            hintText: isArabic ? 'بحث...' : 'Search...',
                            hintTextDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                            prefixIcon: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: _isSearchFocused ? _primary : Colors.grey,
                              ),
                            ),
                            filled: true,
                            fillColor: theme.cardColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: _primary, width: 2),
                            ),
                          ),
                          onChanged: (val) {
                            _search = val;
                            _applyFilter();
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Filters
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', isArabic ? 'الكل' : 'All', Colors.grey),
                        _buildFilterChip('questions', isArabic ? 'أسئلة' : 'Questions', _amber),
                        _buildFilterChip('summary', isArabic ? 'ملخص' : 'Summary', _primary),
                        _buildFilterChip('explanation', isArabic ? 'شرح' : 'Explanation', _green),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                if (!_isLoading && _filtered.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        isArabic ? '${_filtered.length} نتيجة' : '${_filtered.length} results',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ),
                  ),

                // List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filtered.isEmpty
                          ? Center(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 500),
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(0, (1 - value) * 20),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.history_rounded, size: 64, color: Colors.grey[300]),
                                          const SizedBox(height: 16),
                                          Text(
                                            isArabic ? 'لا يوجد سجل بعد' : 'No history yet',
                                            style: TextStyle(color: Colors.grey[400], fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(bottom: 24, top: 4),
                                physics: const BouncingScrollPhysics(),
                                itemCount: _filtered.length,
                                // ✅ pass index for staggered animation
                                itemBuilder: (ctx, i) => _buildHistoryCard(_filtered[i], i),
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }
}