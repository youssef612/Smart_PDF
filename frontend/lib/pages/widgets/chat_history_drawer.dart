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
  bool _isLoading = true;

  AnimationController? _listAnimationController;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadConversations();
  }

  @override
  void dispose() {
    _listAnimationController?.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      final response = await ApiService().getConversations();
      if (response['success'] == true) {
        if (mounted) {
          setState(() {
            _conversations = response['data'] ?? [];
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading history: $e')));
      }
    }
  }

  Future<void> _deleteConversation(String id, int index) async {
    try {
      final response = await ApiService().deleteConversation(id);
      if (response['success'] == true) {
        setState(() {
          _conversations.removeAt(index);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
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
            // ── زرار محادثة جديدة ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: selectedColor,
                  side: BorderSide(color: selectedColor.withOpacity(0.32)),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: isArabic
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text(isArabic ? 'محادثة جديدة' : 'New Chat'),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onNewChatPressed();
                },
              ),
            ),

            // ── قائمة المحادثات الهيستوري ─────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: selectedColor),
                    )
                  : _conversations.isEmpty
                  ? Center(
                      child: Text(
                        isArabic ? 'لا توجد محادثات سابقة' : 'No history yet',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _conversations.length,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemBuilder: (context, index) {
                        final chat = _conversations[index];
                        final id = chat['id'].toString();
                        final isSelected = id == widget.currentConversationId;

                        final itemDelay = (index * 0.05).clamp(0.0, 0.99);

                        final itemAnimation =
                            Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                parent: _listAnimationController!,
                                curve: Interval(
                                  itemDelay,
                                  1.0,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                            );

                        return AnimatedBuilder(
                          animation: _listAnimationController!,
                          builder: (context, child) {
                            return Opacity(
                              opacity: itemAnimation.value,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  24 * (1.0 - itemAnimation.value),
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: HoverableChatTile(
                            key: ValueKey(
                              'tile_$id',
                            ), // استخدام مفتاح فريد لكل سطر بالكامل لمنع الـ Duplicate Keys
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

// ── 🚀 ويدجت الـ Hover المحدثة والمؤمنة بالكامل بالـ Row ──────────────────
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
  }) : super(key: key);

  @override
  State<HoverableChatTile> createState() => _HoverableChatTileState();
}

class _HoverableChatTileState extends State<HoverableChatTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBgColor = widget.isSelected
        ? widget.selectedTileBg
        : (_isHovered
              ? widget.selectedColor.withOpacity(widget.isDark ? 0.12 : 0.06)
              : Colors.transparent);

    final currentElementColor = widget.isSelected
        ? widget.selectedColor
        : (_isHovered ? widget.selectedColor : widget.textAndIconColor);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 2),
        transform: Matrix4.identity()
          ..translate(_isHovered ? (widget.isArabic ? -5.0 : 5.0) : 0.0)
          ..scale(_isHovered ? 1.02 : 1.0),
        decoration: BoxDecoration(
          color: effectiveBgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _isHovered && !widget.isSelected
                  ? widget.selectedColor.withOpacity(
                      widget.isDark ? 0.08 : 0.04,
                    )
                  : Colors.transparent,
              blurRadius: 6.0,
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
                      widget.chat['type'] == 'document'
                          ? Icons.description_outlined
                          : Icons.chat_bubble_outline,
                      color: currentElementColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.chat['title'] ??
                          (widget.isArabic ? 'محادثة جديدة' : 'New Chat'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: currentElementColor,
                        fontSize: 13.5,
                        fontWeight: widget.isSelected || _isHovered
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  // 🛠️ التعديل الأمني: استبدال الـ AnimatedSwitcher بـ AnimatedOpacity صريح ومعزول تماماً
                  // ده بيمنع إعادة بناء وتدمير الـ Widgets اللي كان بيسبب كراش الـ referenceBox
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: widget.isSelected ? 1.0 : 0.0,
                    child: Visibility(
                      visible: widget.isSelected,
                      maintainSize: false,
                      child: GestureDetector(
                        onTap: widget.onDelete,
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.redAccent,
                          ),
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
