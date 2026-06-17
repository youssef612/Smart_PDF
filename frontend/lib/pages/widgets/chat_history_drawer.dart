import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ChatHistoryDrawer extends StatefulWidget {
  final String? currentConversationId;
  final Function(Map<String, dynamic>) onConversationSelected;
  final VoidCallback onNewChatPressed;

  const ChatHistoryDrawer({
    Key? key,
    required this.currentConversationId,
    required this.onConversationSelected,
    required this.onNewChatPressed,
  }) : super(key: key);

  @override
  State<ChatHistoryDrawer> createState() => _ChatHistoryDrawerState();
}

class _ChatHistoryDrawerState extends State<ChatHistoryDrawer>
    with SingleTickerProviderStateMixin {
  List<dynamic> _conversations = [];
  List<dynamic> _filteredConversations = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  AnimationController? _listAnimationController;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _searchController.addListener(_onSearchChanged);
    _loadConversations();
  }

  @override
  void dispose() {
    _listAnimationController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredConversations = List.from(_conversations);
      } else {
        _filteredConversations = _conversations.where((chat) {
          final title = (chat['title'] ?? '').toString().toLowerCase();
          return title.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadConversations() async {
    try {
      final response = await ApiService().getConversations();
      if (response['success'] == true) {
        if (mounted) {
          setState(() {
            _conversations = response['data'] ?? [];
            _filteredConversations = List.from(_conversations);
            _isLoading = false;
          });
          _listAnimationController?.forward();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
      }
    }
  }

  Future<void> _deleteConversation(String id, int index) async {
    try {
      final response = await ApiService().deleteConversation(id);
      if (response['success'] == true) {
        setState(() {
          _conversations.removeWhere((c) => c['id'].toString() == id);
          _filteredConversations.removeAt(index);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  Future<void> _pinConversation(String id) async {
    try {
      final response = await ApiService().pinConversation(id);
      if (response['success'] == true) {
        final isPinned = response['is_pinned'] ?? false;

        setState(() {
          for (final list in [_conversations, _filteredConversations]) {
            final idx = list.indexWhere((c) => c['id'].toString() == id);
            if (idx != -1) list[idx]['is_pinned'] = isPinned;
          }

          int sortFn(a, b) {
            final aPin = (a['is_pinned'] == true) ? 1 : 0;
            final bPin = (b['is_pinned'] == true) ? 1 : 0;
            if (aPin != bPin) return bPin.compareTo(aPin);
            final aTime = a['updated_at'] ?? a['created_at'] ?? '';
            final bTime = b['updated_at'] ?? b['created_at'] ?? '';
            return bTime.compareTo(aTime);
          }

          _conversations.sort(sortFn);
          _filteredConversations.sort(sortFn);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isPinned
                    ? (isArabic ? '📌 تم تثبيت المحادثة' : '📌 Conversation pinned')
                    : (isArabic ? '🔓 تم إلغاء التثبيت' : '🔓 Unpinned'),
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ pin error: $e');
      _loadConversations();
    }
  }

  void _showOptionsMenu(
      BuildContext context,
      TapDownDetails details,
      dynamic chat,
      int index,
      Color accentColor,
      bool isDark,
      ) {
    final id = chat['id'].toString();
    // ✅ هنا بنعرف الحالة الحالية للمحادثة عشان نغير خيارات القائمة
    final bool currentlyPinned = chat['is_pinned'] == true;

    final double globalX = details.globalPosition.dx;
    final double globalY = details.globalPosition.dy;

    final menuAlignment = isArabic ? Alignment.topRight : Alignment.topLeft;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Menu',
      barrierColor: Colors.black.withOpacity(0.01),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return Stack(
          children: [
            Positioned(
              left: isArabic ? null : (globalX - 160).clamp(10.0, MediaQuery.of(context).size.width - 190),
              right: isArabic ? (MediaQuery.of(context).size.width - globalX - 20).clamp(10.0, MediaQuery.of(context).size.width - 190) : null,
              top: globalY.clamp(10.0, MediaQuery.of(context).size.height - 200),
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                ),
                alignment: menuAlignment,
                child: FadeTransition(
                  opacity: animation,
                  child: Material(
                    type: MaterialType.canvas,
                    color: isDark ? const Color(0xFF262626) : Colors.white,
                    elevation: 12,
                    shadowColor: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      ),
                    ),
                    child: Container(
                      width: 170,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 🔥 تعديل ديناميكي: لو معمولة Pin تظهر Unpin والعكس صحيح
                          MenuHoverItem(
                            icon: currentlyPinned ? Icons.pin_end_rounded : Icons.push_pin_rounded,
                            label: currentlyPinned
                                ? (isArabic ? 'إلغاء التثبيت' : 'Unpin')
                                : (isArabic ? 'تثبيت' : 'Pin'),
                            color: accentColor,
                            isDark: isDark,
                            isArabic: isArabic,
                            onTap: () {
                              Navigator.pop(context);
                              _pinConversation(id);
                            },
                          ),
                          MenuHoverItem(
                            icon: Icons.drive_file_rename_outline_rounded,
                            label: isArabic ? 'إعادة تسمية' : 'Rename',
                            color: isDark ? Colors.white70 : Colors.black54,
                            isDark: isDark,
                            isArabic: isArabic,
                            onTap: () {
                              Navigator.pop(context);
                              _showRenameDialog(context, chat, index, accentColor, isDark);
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                          ),
                          MenuHoverItem(
                            icon: Icons.delete_outline_rounded,
                            label: isArabic ? 'حذف' : 'Delete',
                            color: Colors.redAccent,
                            isDark: isDark,
                            isArabic: isArabic,
                            onTap: () {
                              Navigator.pop(context);
                              _deleteConversation(id, index);
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

  void _showRenameDialog(
      BuildContext context,
      dynamic chat,
      int index,
      Color accentColor,
      bool isDark,
      ) {
    final renameController = TextEditingController(text: chat['title'] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isArabic ? 'إعادة تسمية' : 'Rename',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: TextField(
          controller: renameController,
          autofocus: true,
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: isArabic ? 'اسم المحادثة...' : 'Conversation name...',
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.04),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accentColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              isArabic ? 'إلغاء' : 'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final newTitle = renameController.text.trim();
              if (newTitle.isEmpty) return;
              Navigator.pop(dialogContext);
              _renameConversation(chat['id'].toString(), newTitle, index);
            },
            child: Text(
              isArabic ? 'حفظ' : 'Save',
              style: TextStyle(color: accentColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _renameConversation(String id, String newTitle, int index) async {
    try {
      final response = await ApiService().renameConversation(id, newTitle);
      if (response['success'] == true) {
        setState(() {
          final origIdx = _conversations.indexWhere((c) => c['id'].toString() == id);
          if (origIdx != -1) _conversations[origIdx]['title'] = newTitle;

          if (index < _filteredConversations.length) {
            _filteredConversations[index]['title'] = newTitle;
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Failed to rename')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to rename: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final drawerBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC);
    final selectedColor = theme.primaryColor;
    final selectedTileBg = theme.primaryColor.withOpacity(isDark ? 0.15 : 0.08);
    final textAndIconColor = isDark ? Colors.white70 : Colors.black87;

    return Drawer(
      backgroundColor: drawerBg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: selectedColor,
                  side: BorderSide(color: selectedColor.withOpacity(0.32)),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text(isArabic ? 'محادثة جديدة' : 'New Chat'),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onNewChatPressed();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08)),
                ),
                child: TextField(
                  controller: _searchController,
                  textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: isArabic ? 'ابحث في المحادثات...' : 'Search chats...',
                    hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        FocusScope.of(context).unfocus();
                      },
                      child: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: selectedColor))
                  : _filteredConversations.isEmpty
                  ? Center(
                child: Text(
                  _searchController.text.isNotEmpty
                      ? (isArabic ? 'مفيش نتايج للبحث' : 'No results found')
                      : (isArabic ? 'لا توجد محادثات سابقة' : 'No history yet'),
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 13),
                ),
              )
                  : ListView.builder(
                itemCount: _filteredConversations.length,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemBuilder: (context, index) {
                  final chat = _filteredConversations[index];
                  final id = chat['id'].toString();
                  final isSelected = id == widget.currentConversationId;

                  final itemDelay = (index * 0.05).clamp(0.0, 0.99);
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
                    child: HoverableChatTile(
                      key: ValueKey('tile_$id'),
                      chat: chat,
                      id: id,
                      index: index,
                      isSelected: isSelected,
                      selectedColor: selectedColor,
                      selectedTileBg: selectedTileBg,
                      textAndIconColor: textAndIconColor,
                      isDark: isDark,
                      isArabic: isArabic,
                      onDelete: () => _deleteConversation(id, index),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onConversationSelected(chat);
                      },
                      onMoreOptions: (details) => _showOptionsMenu(
                        context,
                        details,
                        chat,
                        index,
                        selectedColor,
                        isDark,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get isArabic => Localizations.localeOf(context).languageCode == 'ar';
}

// ── [خارج الكلاس الرئيسي] ويدجت مستقلة لخيارات الـ Menu مع تأثير Hover احترافي ──
class MenuHoverItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final bool isArabic;
  final VoidCallback onTap;

  const MenuHoverItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.isArabic,
    required this.onTap,
  }) : super(key: key);

  @override
  State<MenuHoverItem> createState() => _MenuHoverItemState();
}

class _MenuHoverItemState extends State<MenuHoverItem> {
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

// ── [خارج الكلاس الرئيسي] ويدجت الـ Tile الخاص بالمحادثة مع الـ Hover والتوهج الناعم ──
class HoverableChatTile extends StatefulWidget {
  final dynamic chat;
  final String id;
  final int index;
  final bool isSelected;
  final Color selectedColor;
  final Color selectedTileBg;
  final Color textAndIconColor;
  final bool isDark;
  final bool isArabic;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final Function(TapDownDetails) onMoreOptions;

  const HoverableChatTile({
    Key? key,
    required this.chat,
    required this.id,
    required this.index,
    required this.isSelected,
    required this.selectedColor,
    required this.selectedTileBg,
    required this.textAndIconColor,
    required this.isDark,
    required this.isArabic,
    required this.onDelete,
    required this.onTap,
    required this.onMoreOptions,
  }) : super(key: key);

  @override
  State<HoverableChatTile> createState() => _HoverableChatTileState();
}

class _HoverableChatTileState extends State<HoverableChatTile> {
  bool _isHovered = false;
  TapDownDetails? _tapDownDetails;

  @override
  Widget build(BuildContext context) {
    // تشيك سريع إذا كانت المحادثة معمولة ليها Pin
    final bool isChatPinned = widget.chat['is_pinned'] == true;

    final effectiveBgColor = widget.isSelected
        ? widget.selectedTileBg
        : (_isHovered ? widget.selectedColor.withOpacity(widget.isDark ? 0.14 : 0.07) : Colors.transparent);

    final currentElementColor = widget.isSelected
        ? widget.selectedColor
        : (_isHovered ? widget.selectedColor : widget.textAndIconColor);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        transform: Matrix4.identity()
          ..translate(_isHovered && !widget.isSelected ? (widget.isArabic ? -4.0 : 4.0) : 0.0)
          ..scale(_isHovered && !widget.isSelected ? 1.025 : 1.0),
        decoration: BoxDecoration(
          color: effectiveBgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _isHovered && !widget.isSelected
                  ? widget.selectedColor.withOpacity(widget.isDark ? 0.12 : 0.06)
                  : Colors.transparent,
              blurRadius: 8.0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            splashColor: widget.selectedColor.withOpacity(0.08),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _isHovered && !widget.isSelected ? 0.02 : 0.0,
                    child: Icon(
                      widget.chat['type'] == 'document' ? Icons.description_outlined : Icons.chat_bubble_outline,
                      color: currentElementColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        // النص الأساسي للـ Title
                        Expanded(
                          child: Text(
                            widget.chat['title'] ?? (widget.isArabic ? 'محادثة جديدة' : 'New Chat'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: currentElementColor,
                              fontSize: 13.5,
                              fontWeight: widget.isSelected || _isHovered ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        // ✅ إضافة علامة الدبوس لو المحادثة معمولة ليها Pin
                        if (isChatPinned) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.push_pin_rounded,
                            size: 13,
                            color: widget.isSelected ? widget.selectedColor : currentElementColor.withOpacity(0.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: (_isHovered || widget.isSelected) ? 1.0 : 0.0,
                    child: GestureDetector(
                      onTapDown: (details) => _tapDownDetails = details,
                      onTap: () {
                        if ((_isHovered || widget.isSelected) && _tapDownDetails != null) {
                          widget.onMoreOptions(_tapDownDetails!);
                        }
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: widget.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.more_horiz_rounded,
                          size: 16,
                          color: widget.isSelected ? widget.selectedColor : widget.textAndIconColor.withOpacity(0.7),
                        ),
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