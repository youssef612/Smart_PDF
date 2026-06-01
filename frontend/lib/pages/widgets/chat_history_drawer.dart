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

class _ChatHistoryDrawerState extends State<ChatHistoryDrawer> {
  List<dynamic> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final response = await ApiService().getConversations();
      if (response['success'] == true) {
        setState(() {
          _conversations = response['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
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

    // 🎨 هنا الـ Drawer بيلبس ألوان مشروعك الأساسية تلقائياً
    final drawerBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC);

    // لو مختار المحادثة، بتاخد لون مشروعك الصريح (primaryColor) سواء أزرق أو بنفسجي
    final selectedColor = theme.primaryColor;

    // خلفية العنصر المحدد بتاخد تشبيعة خفيفة جداً من لون مشروعك عشان تريح العين
    final selectedTileBg = theme.primaryColor.withOpacity(isDark ? 0.15 : 0.08);

    // الألوان العادية للمحادثات غير المحددة
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
                  // الزرار بياخد لون المشروع عشان ينطق في الواجهة
                  foregroundColor: selectedColor,
                  side: BorderSide(color: selectedColor.withOpacity(0.32)),
                  minimumSize: const Size.fromHeight(50),
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

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: ListTile(
                            selected: isSelected,
                            selectedTileColor:
                                selectedTileBg, // التشبيعة الهادية من لون مشروعك
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: Icon(
                              chat['type'] == 'document'
                                  ? Icons.description_outlined
                                  : Icons.chat_bubble_outline,
                              color: isSelected
                                  ? selectedColor
                                  : textAndIconColor,
                              size: 18,
                            ),
                            title: Text(
                              chat['title'] ??
                                  (isArabic ? 'محادثة جديدة' : 'New Chat'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected
                                    ? selectedColor
                                    : textAndIconColor,
                                fontSize: 13.5,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            trailing: isSelected
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () =>
                                        _deleteConversation(id, index),
                                  )
                                : null,
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

  // الـ helper ده عشان نتاكد من لغة الجهاز أوتوماتيك للـ alignment
  bool get isArabic => Localizations.localeOf(context).languageCode == 'ar';
}
